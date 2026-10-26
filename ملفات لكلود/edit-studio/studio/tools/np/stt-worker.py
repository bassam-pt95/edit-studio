#!/usr/bin/env python3

import os, sys, json, time, argparse, subprocess
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
if os.name == 'nt':
    sys.stdin.reconfigure(encoding='utf-8'); sys.stdout.reconfigure(encoding='utf-8'); sys.stderr.reconfigure(encoding='utf-8', errors='replace')

os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('HF_HUB_DISABLE_SYMLINKS_WARNING', '1')
SR = 16000
QUIET = 0.012
SHORT = 0.35


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + '\n')
    sys.stdout.flush()


def fw_name(repo):

    n = repo.split('/')[-1]
    if n.startswith('whisper-'):
        n = n[len('whisper-'):]
    for tail in ('-mlx', '-fp16', '-fp32'):
        if n.endswith(tail):
            n = n[:-len(tail)]
    return n or 'large-v3'



THREADS = min(8, max(4, (os.cpu_count() or 8) // 2))
CUDA_TYPES = ('float16', 'int8_float16')


def _nvidia_dlls():

    if os.name != 'nt':
        return
    import importlib.util
    spec = importlib.util.find_spec('nvidia')
    for root in (spec.submodule_search_locations if spec else None) or []:
        for n in sorted(os.listdir(root)):
            d = os.path.join(root, n, 'bin')
            if os.path.isdir(d):
                os.add_dll_directory(d)
                os.environ['PATH'] = d + os.pathsep + os.environ.get('PATH', '')


def _cuda(WhisperModel, name, ct):

    import numpy as np
    m = WhisperModel(name, device='cuda', compute_type=ct)
    try:
        segs, _ = m.transcribe(np.zeros(16000, np.float32), language='ar')
        list(segs)
    except Exception:
        m.model.unload_model()
        raise
    return m


def _load(name):

    _nvidia_dlls()
    import ctranslate2
    from faster_whisper import WhisperModel
    if os.environ.get('VEB_STT_DEVICE') != 'cpu' and ctranslate2.get_cuda_device_count() > 0:
        for ct in (os.environ['VEB_STT_COMPUTE'],) if os.environ.get('VEB_STT_COMPUTE') else CUDA_TYPES:
            try:
                return _cuda(WhisperModel, name, ct), 'cuda'
            except Exception as e:
                print('CUDA %s unavailable: %s' % (ct, e), file=sys.stderr, flush=True)
                if 'memory' not in str(e).lower() and 'alloc' not in str(e).lower():
                    break
        print('CUDA unavailable, using CPU', file=sys.stderr, flush=True)
    return WhisperModel(name, device='cpu', compute_type='int8', cpu_threads=THREADS), 'cpu'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--model', default='mlx-community/whisper-large-v3-mlx')
    ap.add_argument('--language', default='ar')
    ap.add_argument('--prompt-file', default=None)
    ap.add_argument('--ffmpeg', default='ffmpeg')
    a = ap.parse_args()
    try:
        import numpy as np
    except Exception as e:
        out({'error': 'numpy is not available: %s' % e})
        return
    mlx_whisper = WhisperModel = None
    try:
        import mlx_whisper
    except Exception as e1:
        try:
            from faster_whisper import WhisperModel
        except Exception as e2:
            out({'error': 'mlx_whisper is not available: %s; faster_whisper is not available: %s' % (e1, e2)})
            return
    prompt = None
    if a.prompt_file:
        try:
            with open(a.prompt_file, encoding='utf-8') as f:
                prompt = f.read().strip() or None
        except OSError:
            prompt = None

    fw = [None]

    def stt(audio, words=False):

        if mlx_whisper is None:
            if fw[0] is None:
                if os.name == 'nt':
                    fw[0] = _load(fw_name(a.model))[0]
                else:
                    fw[0] = WhisperModel(fw_name(a.model), device='auto', compute_type='auto')



            segs, _ = fw[0].transcribe(audio, language=a.language, condition_on_previous_text=False, no_speech_threshold=0.6,
                                       initial_prompt=None if os.name == 'nt' else prompt, word_timestamps=words)
            segs = list(segs)
            ws = [{'t': w.word.strip(), 's': round(w.start, 3), 'e': round(w.end, 3), 'p': round(w.probability, 3)}
                  for sg in segs for w in (sg.words or []) if w.word.strip()] if words else []
            return ''.join(sg.text for sg in segs).strip(), ws
        res = mlx_whisper.transcribe(audio, path_or_hf_repo=a.model, language=a.language, condition_on_previous_text=False,
                                     no_speech_threshold=0.6, initial_prompt=prompt, verbose=None, word_timestamps=words)
        ws = [{'t': w['word'].strip(), 's': round(w['start'], 3), 'e': round(w['end'], 3), 'p': round(w.get('probability', 0), 3)}
              for sg in res.get('segments') or [] for w in sg.get('words') or [] if w['word'].strip()] if words else []
        return (res.get('text') or '').strip(), ws

    t0 = time.time()
    try:
        warm = True
        if os.name == 'nt' and mlx_whisper is None:


            fw[0], dev = _load(fw_name(a.model))
            warm = dev == 'cpu'
        if warm:
            stt(np.zeros(SR, np.float32))
    except Exception as e:
        out({'error': 'whisper could not start: %s' % str(e)[:300]})
        return
    out({'ready': True, 'sec': round(time.time() - t0, 2)})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except ValueError:
            continue
        rid = req.get('id')
        t1 = time.time()
        cut = []
        try:
            ss, to = float(req.get('ss', 0) or 0), req.get('to')
            if ss > 0:
                cut += ['-ss', '%.3f' % ss]
            if to is not None and float(to) > ss:
                cut += ['-t', '%.3f' % (float(to) - ss)]
        except (TypeError, ValueError):
            cut = []
        r = subprocess.run([a.ffmpeg, '-nostdin', '-v', 'error', *cut, '-i', req.get('file', ''), '-ac', '1', '-ar', str(SR), '-f', 'f32le', 'pipe:1'],
                           capture_output=True)
        if r.returncode != 0:
            out({'id': rid, 'error': 'ffmpeg could not read the recording: %s' % r.stderr.decode('utf-8', 'replace')[-200:]})
            continue
        audio = np.frombuffer(r.stdout, np.float32)
        dur = len(audio) / SR
        if dur < SHORT or float(np.max(np.abs(audio))) < QUIET:
            out({'id': rid, 'text': '', 'silent': True, 'audio': round(dur, 2)})
            continue
        try:
            text, words = stt(audio, bool(req.get('words')))
        except Exception as e:
            out({'id': rid, 'error': 'whisper failed: %s' % str(e)[:300]})
            continue
        ans = {'id': rid, 'text': text, 'sec': round(time.time() - t1, 2), 'audio': round(dur, 2)}
        if req.get('words'):
            ans['words'] = words
        out(ans)


if __name__ == '__main__':
    main()
