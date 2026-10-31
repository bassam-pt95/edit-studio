#!/usr/bin/env python3

import os, re, sys, json, time, argparse, subprocess

os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('HF_HUB_DISABLE_SYMLINKS_WARNING', '1')
SR = 16000
PAD = 0.05
LEAD, TAIL = 0.6, 0.15


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + '\n')
    sys.stdout.flush()


def utf8_stdio():

    for stream, errors in ((sys.stdin, 'strict'), (sys.stdout, 'strict'), (sys.stderr, 'replace')):
        try:
            stream.reconfigure(encoding='utf-8', errors=errors)
        except Exception:
            pass


def fw_name(repo):

    n = repo.split('/')[-1]
    if n.startswith('whisper-'):
        n = n[len('whisper-'):]
    for tail in ('-mlx', '-fp16', '-fp32'):
        if n.endswith(tail):
            n = n[:-len(tail)]
    return n or 'large-v3'


def choose_engine(platform, mlx_ok, fw_ok, forced=None):

    if forced in ('mlx', 'faster-whisper'):
        return forced if (mlx_ok if forced == 'mlx' else fw_ok) else None
    if platform == 'darwin' and mlx_ok:
        return 'mlx'
    return 'faster-whisper' if fw_ok else ('mlx' if mlx_ok else None)


class MlxEngine:
    name = 'mlx'

    def __init__(self, mod, model):
        self.mod, self.model = mod, model

    def load(self):
        pass

    def transcribe(self, audio, language, initial_prompt, **kw):
        return self.mod.transcribe(audio, path_or_hf_repo=self.model, language=language, word_timestamps=True,
                                   initial_prompt=initial_prompt, verbose=None, **kw)


class FwEngine:

    name = 'faster-whisper'

    def __init__(self, cls, repo):
        self.cls, self.model, self._m = cls, fw_name(repo), None

    def load(self):
        if self._m is None:
            self._m = self.cls(self.model, device='auto', compute_type='auto')

    def transcribe(self, audio, language, initial_prompt, **kw):
        self.load()
        segs, _ = self._m.transcribe(audio, language=language, word_timestamps=True, initial_prompt=initial_prompt, **kw)
        return fw_result(segs)


def fw_result(segs):
    out_segs, texts = [], []
    for s in segs:
        words = [{'word': w.word, 'start': w.start, 'end': w.end, 'probability': w.probability} for w in (s.words or [])]
        out_segs.append({'text': s.text, 'words': words})
        texts.append(s.text)
    return {'segments': out_segs, 'text': ''.join(texts)}


def load_engine(model, platform=None, forced=None):

    platform = platform or sys.platform
    forced = forced or os.environ.get('MOHRER_STT_ENGINE') or None
    mlx_mod = fw_cls = None
    errs = []
    if platform == 'darwin' or forced == 'mlx':
        try:
            import mlx_whisper as mlx_mod
        except Exception as e:
            errs.append('mlx_whisper is not available: %s' % e)
    if platform != 'darwin' or forced == 'faster-whisper' or mlx_mod is None:
        try:
            from faster_whisper import WhisperModel as fw_cls
        except Exception as e:
            errs.append('faster_whisper is not available: %s' % e)
    pick = choose_engine(platform, mlx_mod is not None, fw_cls is not None, forced)
    if pick == 'mlx':
        return MlxEngine(mlx_mod, model), None
    if pick == 'faster-whisper':
        return FwEngine(fw_cls, model), None
    return None, '; '.join(errs) or 'no transcriber'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pcm')
    ap.add_argument('islands')
    ap.add_argument('--model', default='mlx-community/whisper-large-v3-mlx')
    ap.add_argument('--language', default='ar')
    ap.add_argument('--prompt-file', default=None)
    ap.add_argument('--ffmpeg', default='ffmpeg')
    ap.add_argument('--each', action='store_true', help='every island on its own (the old way)')
    ap.add_argument('--chunk', type=float, default=CHUNK, help='seconds of recording per piece heard at once')
    ap.add_argument('--plan', action='store_true', help='print the pieces only (no whisper)')
    ap.add_argument('--engine', choices=['mlx', 'faster-whisper'], default=None, help='force one (default: mlx on a Mac, faster-whisper elsewhere)')
    a = ap.parse_args()
    utf8_stdio()
    if a.plan:
        with open(a.islands, encoding='utf-8') as f:
            isl = json.load(f)
        table = spans_of(isl, None)
        cisl = compact_islands(isl, table)
        pieces = chunks_of(cisl, a.chunk)
        out({'chunks': [[cisl[k]['i'] for k in c] for c in pieces],
             'pieces': [[round(min(cisl[k]['s'] for k in c), 4), round(max(cisl[k]['e'] for k in c), 4)] for c in pieces],
             'compact': round(compact_len(table), 4), 'spans': len(table)})
        return
    try:
        import numpy as np
    except Exception as e:
        out({'error': 'numpy is not available: %s' % e})
        return
    engine, why = load_engine(a.model, forced=a.engine)
    if engine is None:
        out({'error': why})
        return

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import model_fetch
    why = model_fetch.ensure(engine.name, a.model, out)
    if why:
        out({'error': why})
        return
    if engine.name == 'faster-whisper':
        try:
            engine.load()
        except Exception as e:
            out({'error': 'faster-whisper could not load %s (nothing is downloaded here): %s' % (engine.model, str(e)[:300])})
            return
    cache_limit()
    prompt = None
    if a.prompt_file:
        try:
            with open(a.prompt_file, encoding='utf-8') as f:
                prompt = f.read().strip() or None
        except OSError as e:
            out({'error': 'prompt file: %s' % e})
            return
    with open(a.islands, encoding='utf-8') as f:
        isl = json.load(f)
    r = subprocess.run([a.ffmpeg, '-nostdin', '-v', 'error', '-i', a.pcm, '-ac', '1', '-ar', str(SR), '-f', 'f32le', 'pipe:1'],
                       capture_output=True)
    if r.returncode != 0:
        out({'error': 'ffmpeg could not read the sidecar: %s' % r.stderr.decode('utf-8', 'replace')[-300:]})
        return
    audio = np.frombuffer(r.stdout, np.float32)
    dur = len(audio) / SR
    if not a.each:
        whole(engine, audio, isl, a, prompt)
        return
    for it in isl:
        t0 = time.time()
        a0 = max(0.0, it['s'] - PAD)
        b0 = min(dur, it['e'] + PAD)
        seg = np.ascontiguousarray(audio[int(round(a0 * SR)):int(round(b0 * SR))])
        try:
            res = engine.transcribe(seg, a.language, prompt, condition_on_previous_text=False, no_speech_threshold=0.6)
        except Exception as e:
            out({'error': 'whisper failed on island %s: %s' % (it.get('id', it['i']), str(e)[:300])})
            return
        words = []
        for s in res.get('segments', []):
            for w in s.get('words', []) or []:
                t = (w.get('word') or '').strip()
                if not t:
                    continue
                words.append({'t': t, 's': round(a0 + float(w['start']), 4), 'e': round(a0 + float(w['end']), 4),
                              'p': round(float(w.get('probability', 0)), 3)})
        out({'i': it['i'], 'a': round(a0, 4), 'words': words, 'text': (res.get('text') or '').strip(),
             'sec': round(time.time() - t0, 2)})


def owner(mid, isl):

    best, gap = None, None
    for k, it in enumerate(isl):
        if it['s'] - LEAD <= mid <= it['e'] + TAIL:
            d = 0.0 if it['s'] <= mid <= it['e'] else min(abs(mid - it['s']), abs(mid - it['e']))
            if gap is None or d < gap:
                best, gap = k, d
    return best


CLIP_PAD = 0.3


def clips_of(isl, dur):

    spans = []
    for it in sorted(isl, key=lambda x: x['s']):
        s, e = max(0.0, it['s'] - CLIP_PAD), min(dur, it['e'] + CLIP_PAD)
        if spans and s <= spans[-1][1]:
            spans[-1][1] = max(spans[-1][1], e)
        else:
            spans.append([s, e])
    return ','.join('%.3f' % x for sp in spans for x in sp)


CHUNK = 300.0
TAIL_WORDS = 60


STOCK_CARRY = re.compile(r'ترجمة نانسي قنقر|ترجمة نانسي|نانسي قنقر|اشتركوا في القناة|شكرا (?:لكم )?(?:على المشاهدة|للمشاهدة)|نانسي|قنقر')


def carry(heard, fallback):

    text = STOCK_CARRY.sub(' ', ' '.join(heard))
    words = text.split()
    return ' '.join(words[-TAIL_WORDS:]) or fallback


def chunks_of(isl, size=CHUNK):

    order = sorted(range(len(isl)), key=lambda k: isl[k]['s'])
    out, k = [], 0
    while k < len(order):
        start = isl[order[k]]['s']
        j = k
        while j + 1 < len(order) and isl[order[j + 1]]['e'] - start <= size:
            j += 1
        if j + 1 < len(order) and j > k:

            best, gap = j, -1.0
            for m in range(k, j):
                at = isl[order[m]]['e']
                if at - start < 0.6 * size:
                    continue
                nxt, cur = isl[order[m + 1]], isl[order[m]]
                g = nxt.get('os', nxt['s']) - cur.get('oe', cur['e'])
                if g > gap:
                    best, gap = m, g
            j = best
        out.append(order[k:j + 1])
        k = j + 1
    return out


CACHE_LIMIT = 2 << 30


def cache_limit():

    try:
        import mlx.core as mx
        (getattr(mx, 'set_cache_limit', None) or mx.metal.set_cache_limit)(CACHE_LIMIT)
    except Exception:
        pass


def free_cache():

    try:
        import mlx.core as mx
        (getattr(mx, 'clear_cache', None) or mx.metal.clear_cache)()
    except Exception:
        pass


SPAN_PAD = 0.30
SPAN_JOIN = 0.6


def spans_of(isl, dur, pad=SPAN_PAD, join=SPAN_JOIN, sr=SR):

    raw = []
    for it in sorted(isl, key=lambda x: x['s']):
        a = max(0.0, it['s'] - pad)
        b = it['e'] + pad if dur is None else min(dur, it['e'] + pad)
        if raw and a - raw[-1][1] <= join + 1e-9:
            raw[-1][1] = max(raw[-1][1], b)
        else:
            raw.append([a, b])
    table, c = [], 0
    for a, b in raw:
        ia, ib = int(round(a * sr)), int(round(b * sr))
        if ib <= ia:
            continue
        table.append([ia / sr, ib / sr, c / sr])
        c += ib - ia
    return table


def compact_len(table):

    return table[-1][2] + table[-1][1] - table[-1][0] if table else 0.0


def span_of(t, table):

    lo, hi = 0, len(table)
    while lo < hi:
        m = (lo + hi) // 2
        if table[m][1] < t:
            lo = m + 1
        else:
            hi = m
    return lo if lo < len(table) and table[lo][0] <= t <= table[lo][1] else None


def to_compact(t, table):

    k = span_of(t, table)
    return None if k is None else table[k][2] + (t - table[k][0])


def compact_span(tc, table):

    lo, hi = 0, len(table)
    while lo < hi:
        m = (lo + hi) // 2
        if table[m][2] <= tc:
            lo = m + 1
        else:
            hi = m
    return max(0, lo - 1)


def to_recording(tc, table, k=None):

    if not table:
        return tc
    if k is None:
        k = compact_span(tc, table)
    a, b, c = table[k]
    return a + min(b - a, max(0.0, tc - c))


def compact_islands(isl, table):

    out = []
    for it in isl:
        k = span_of(it['s'], table)
        if k is None:
            k = min(range(len(table)), key=lambda j: abs(table[j][0] - it['s']))
        a, b, c = table[k]
        at = lambda t: c + min(b - a, max(0.0, t - a))
        out.append({'i': it['i'], 's': at(it['s']), 'e': at(it['e']), 'os': it['s'], 'oe': it['e'], 'k': k})
    return out


def compact_audio(audio, table, sr=SR):

    import numpy as np
    if not table:
        return audio[:0]
    return np.ascontiguousarray(np.concatenate([audio[int(round(a * sr)):int(round(b * sr))] for a, b, _ in table]))


def whole(engine, audio, isl, a, prompt):

    dur = len(audio) / SR
    table = spans_of(isl, dur)
    if not table:
        return
    comp = compact_audio(audio, table)
    cdur = len(comp) / SR
    cisl = compact_islands(isl, table)
    pieces = chunks_of(cisl, getattr(a, 'chunk', CHUNK) or CHUNK)
    context = prompt
    for n, piece in enumerate(pieces):
        t0 = time.time()
        sub = [cisl[k] for k in piece]
        a0 = max(0.0, min(it['s'] for it in sub) - CLIP_PAD)
        b0 = min(cdur, max(it['e'] for it in sub) + CLIP_PAD)
        seg = comp[int(round(a0 * SR)):int(round(b0 * SR))]
        rel = [{'s': it['s'] - a0, 'e': it['e'] - a0} for it in sub]
        try:
            res = engine.transcribe(seg, a.language, context, clip_timestamps=clips_of(rel, len(seg) / SR),
                                    hallucination_silence_threshold=1.0)
        except Exception as e:
            out({'error': 'whisper failed: %s' % str(e)[:300]})
            return
        per = [[] for _ in sub]
        heard = []
        for s in res.get('segments', []):
            for w in s.get('words', []) or []:
                t = (w.get('word') or '').strip()
                if not t:
                    continue
                ws, we = a0 + float(w['start']), a0 + float(w['end'])
                heard.append(t)
                k = owner((ws + we) / 2, sub)
                if k is None:
                    continue
                sk = sub[k]['k']
                per[k].append({'t': t, 's': round(to_recording(ws, table, sk), 4), 'e': round(to_recording(we, table, sk), 4),
                               'p': round(float(w.get('probability', 0)), 3)})

        context = carry(heard, context)
        free_cache()
        sec = round(time.time() - t0, 2)
        for j, it in enumerate(sub):
            first = {'chunk': n + 1, 'of': len(pieces), 'upto': round(b0, 2), 'compact': round(cdur, 2)} if j == 0 else {}
            out({'i': it['i'], 'a': round(max(0.0, it['os'] - PAD), 4), 'words': per[j], 'text': ' '.join(x['t'] for x in per[j]),
                 'sec': sec if j == 0 else 0, **first})


if __name__ == '__main__':
    main()
