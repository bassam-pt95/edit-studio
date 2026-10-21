#!/usr/bin/env python3

import os, sys, json, time, argparse, subprocess

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


def utf8_stdio():

    for stream, errors in ((sys.stdin, 'strict'), (sys.stdout, 'strict'), (sys.stderr, 'replace')):
        try:
            stream.reconfigure(encoding='utf-8', errors=errors)
        except Exception:
            pass


def main():
    utf8_stdio()
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

    def stt(audio):
        if mlx_whisper is None:
            if fw[0] is None:
                fw[0] = WhisperModel(fw_name(a.model), device='auto', compute_type='auto')
            segs, _ = fw[0].transcribe(audio, language=a.language, condition_on_previous_text=False, no_speech_threshold=0.6,
                                       initial_prompt=prompt)
            return ''.join(s.text for s in segs).strip()
        res = mlx_whisper.transcribe(audio, path_or_hf_repo=a.model, language=a.language, condition_on_previous_text=False,
                                     no_speech_threshold=0.6, initial_prompt=prompt, verbose=None)
        return (res.get('text') or '').strip()

    t0 = time.time()
    try:
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
        r = subprocess.run([a.ffmpeg, '-nostdin', '-v', 'error', '-i', req.get('file', ''), '-ac', '1', '-ar', str(SR), '-f', 'f32le', 'pipe:1'],
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
            text = stt(audio)
        except Exception as e:
            out({'id': rid, 'error': 'whisper failed: %s' % str(e)[:300]})
            continue
        out({'id': rid, 'text': text, 'sec': round(time.time() - t1, 2), 'audio': round(dur, 2)})


if __name__ == '__main__':
    main()
