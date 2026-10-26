# -*- coding: utf-8 -*-
"""صوته خرج كما دخل؟ — يطرح المؤثرات من الناتج ويقارن الباقي بـvoice.wav.
   python3 20_voice_check.py <work> <الناتج.mp4>      → يخرج 3 لو صوته تغيّر · 4 لو ملف ما انقرا (الفحص ما تم)
⛔ الارتباط الخام مع المؤثرات ينزل تحت 0.999 وهو سليم — لازم تُطرح sfx.wav أولاً (القاعدة ١٩)."""
import sys, os, subprocess
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
import numpy as np
W = os.path.abspath(sys.argv[1]) + '/'; OUT = sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths
ReadError = _paths.AudioReadError
def rd(p):
    """عيّنات الملف قناة وحدة (متوسط القنوات). تنقرا عبر ffmpeg لا wave (_paths.read_audio): voice.wav 24 بت
    وwave قبل بايثون 3.12 يرفضه («unknown format: 65534»). نفس الأرقام بالحرف، وبلا تغيير معدل ولا قنوات."""
    return _paths.read_audio(p).astype(np.float64).mean(1)
tmp = W+'.voicecheck.wav'
try:
    try:
        e = subprocess.run(['ffmpeg','-y','-v','error','-i',OUT,'-vn','-c:a','pcm_s24le','-ar','48000','-ac','2',tmp], capture_output=True)
        if e.returncode: raise ReadError(f"{OUT}: {(e.stderr.decode('utf-8','replace').strip().splitlines() or ['ffmpeg exit %d' % e.returncode])[-1]}")
        v, o = rd(W+'voice.wav'), rd(tmp)
        s = rd(W+'sfx.wav') if os.path.exists(W+'sfx.wav') else np.zeros_like(o)
        n = min(len(v), len(o), len(s))
        if n == 0: raise ReadError("ملف صوت فاضي (صفر عيّنات)")
    finally:
        if os.path.exists(tmp): os.remove(tmp)
except ReadError as err:
    # ⛔ خطأ قراءة مو «صوته تغيّر»: رمز ورسالة لحالها، فما ينقال للمستخدم إن صوته انلمس وهو ما انلمس
    print(f"⛔ ما قدرت أقرأ الصوت — الفحص ما تم (مو دليل إن صوته تغيّر): {err}")
    sys.exit(4)
v, o, s = v[:n], o[:n], s[:n]; c = o - s
r  = lambda x: 20*np.log10(np.sqrt((x**2).mean())+1e-12)
cr = lambda x: 20*np.log10(np.abs(x).max()/(np.sqrt((x**2).mean())+1e-12))
corr, gain, crest = np.corrcoef(v, c)[0,1], r(c)-r(v), cr(c)-cr(v)
ok = corr >= 0.999 and abs(gain) < 0.15
print(f"الارتباط {corr:.6f} {'✅' if corr>=0.999 else '❌'} · الكسب {gain:+.3f} dB {'✅' if abs(gain)<0.15 else '❌'} · عامل الذروة {crest:+.3f} dB")
sys.exit(0 if ok else 3)
