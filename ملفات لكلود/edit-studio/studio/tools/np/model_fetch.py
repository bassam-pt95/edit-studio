#!/usr/bin/env python3

import os, sys, json, time, threading, subprocess

FW_FILES = ['config.json', 'preprocessor_config.json', 'model.bin', 'tokenizer.json', 'vocabulary.*']


def fw_name(repo):
    n = repo.split('/')[-1]
    if n.startswith('whisper-'):
        n = n[len('whisper-'):]
    for tail in ('-mlx', '-fp16', '-fp32'):
        if n.endswith(tail):
            n = n[:-len(tail)]
    return n or 'large-v3'


def repo_of(engine, model):
    if engine == 'mlx':
        return model, None
    name = fw_name(model)
    try:
        from faster_whisper.utils import _MODELS
        repo = _MODELS.get(name)
    except Exception:
        repo = None
    return repo or ('Systran/faster-whisper-%s' % name), FW_FILES


def cached(repo, patterns):
    try:
        from huggingface_hub import snapshot_download
        snapshot_download(repo, allow_patterns=patterns, local_files_only=True)
        return True
    except Exception:
        return False


def ensure(engine, model, out):
    if os.environ.get('MOHRER_MODEL_FETCH') == '0':
        return None
    repo, patterns = repo_of(engine, model)
    if cached(repo, patterns):
        return None
    env = dict(os.environ, HF_HUB_OFFLINE='0', PYTHONUTF8='1', PYTHONIOENCODING='utf-8')
    try:
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), '--get', repo] + (patterns or []), env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', errors='replace')
    except Exception as e:
        return 'could not start the download: %s' % e
    why = None
    for line in p.stdout:
        try:
            m = json.loads(line)
        except Exception:
            continue
        if 'error' in m:
            why = m['error']
        elif 'got' in m:
            out({'model': {'repo': repo, 'got': m['got'], 'of': m['of']}})
    err = p.stderr.read()
    p.wait()
    if p.returncode != 0 and not why:
        why = (err.strip().splitlines() or ['exit %s' % p.returncode])[-1][:300]
    if why:
        return 'the transcription model %s could not be downloaded: %s' % (repo, why)
    return None if cached(repo, patterns) else 'the transcription model %s is still not on this machine' % repo


def _size(d):

    n = 0
    for root, _, files in os.walk(d):
        for f in files:
            try:
                st = os.lstat(os.path.join(root, f))
                if not os.path.islink(os.path.join(root, f)):
                    n += st.st_size
            except OSError:
                pass
    return n


def _get(repo, patterns):
    def say(obj):
        sys.stdout.write(json.dumps(obj) + '\n')
        sys.stdout.flush()
    from fnmatch import fnmatch
    from huggingface_hub import HfApi, snapshot_download, constants
    total = 0
    try:
        info = HfApi().model_info(repo, files_metadata=True)
        total = sum((s.size or 0) for s in info.siblings if not patterns or any(fnmatch(s.rfilename, x) for x in patterns))
    except Exception:
        pass

    hub = constants.HF_HUB_CACHE
    base = _size(hub)
    got = lambda: min(total, _size(hub) - base) if total else _size(hub) - base
    state = {'error': None}

    def run():
        try:
            snapshot_download(repo, allow_patterns=patterns)
        except Exception as e:
            state['error'] = str(e)[:300]
    t = threading.Thread(target=run, daemon=True)
    t.start()
    while t.is_alive():
        say({'got': got(), 'of': total})
        t.join(1.0)
    if state['error']:
        say({'error': state['error']})
        sys.exit(1)
    say({'got': got(), 'of': total})
    say({'done': True})


DEFAULT_MODEL = 'mlx-community/whisper-large-v3-mlx'


def engine_here():

    import importlib.util as u
    if sys.platform == 'darwin' and u.find_spec('mlx_whisper'):
        return 'mlx'
    return 'faster-whisper' if u.find_spec('faster_whisper') else None


def _cli(cmd, model):
    engine = engine_here()
    if engine is None:
        print('no transcriber in this Python')
        sys.exit(2)
    if cmd == '--has':
        sys.exit(0 if cached(*repo_of(engine, model)) else 1)
    seen = [-1]

    def show(o):
        m = o.get('model') or {}
        if m.get('of'):
            tenth = int(m['got'] * 10 // m['of'])
            if tenth > seen[0]:
                seen[0] = tenth
                print('  %d%%' % (tenth * 10), flush=True)
    why = ensure(engine, model, show)
    if why:
        print(why)
        sys.exit(1)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == '--get':
    _get(sys.argv[2], sys.argv[3:] or None)
elif __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] in ('--has', '--ensure'):
    _cli(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else DEFAULT_MODEL)
