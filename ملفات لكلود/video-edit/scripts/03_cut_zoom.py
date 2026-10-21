# -*- coding: utf-8 -*-
"""قص السكتات + زوم مختلف لكل مقطع (+ تدرّج لوني لو طلبه فقط).  python3 03_cut_zoom.py <workdir>
يطلّع cutz.mp4 (الفيديو المقصوص للمعاينة والرندر) وvoice.wav (صوته للتسليم، بلا أي معالجة)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths; _paths.utf8_guard()   # ويندوز بدون UTF-8: يعيد تشغيل السكربت بـ-X utf8 (ماك/لينكس: لا شي)
import json, subprocess
W=os.path.abspath(sys.argv[1]); SRC=os.path.join(W,"src.mov")
OW, OH = _paths.frame(W)          # إطار المقطع (طولي 1080×1920 · عرضي 1920×1080 · مربع)
k=_paths.read_json(os.path.join(W,"cut.json"))["keep"]
_tp=os.path.join(W,"theme.json")
GRADE=_paths.read_json(_tp).get("grade",False) if os.path.exists(_tp) else False
Z=[1.00,1.08,1.00,1.06,1.00,1.12,1.04,1.14,1.00,1.08,1.00,1.05,1.10,1.00]; ANCH=0.30; FACEX=0.5
_at=os.path.join(W,"theme.json")
if os.path.exists(_at):
    _t=_paths.read_json(_at)
    if isinstance(_t.get("zoomAnchor"),(int,float)): ANCH=float(_t["zoomAnchor"])
    if _t.get("noZoom"): Z=[1.00]
    # faceX: وين وجهه أفقياً بالتصوير (0 يسار · 1 يمين) — لما الإطار أضيق من التصوير (عرضي ← طولي) القص يلحقه
    if isinstance(_t.get("faceX"),(int,float)): FACEX=float(_t["faceX"])
p=subprocess.run(["ffprobe","-v","error","-select_streams","v:0","-show_entries",
   "stream=width,height","-of","csv=p=0:s=x",SRC],capture_output=True,text=True, encoding="utf-8", errors="replace").stdout.strip()
SW,SH=[int(x) for x in p.split("x")[:2]]

def _face_x():
    """وين وجهه أفقياً (0..1) من ٦ فريمات من التصوير — بكاشف الوجه نفسه (Vision بالماك · mediapipe بغيره)."""
    import tempfile, shutil
    tmp = tempfile.mkdtemp(prefix="facex-")
    try:
        dur = float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",SRC],
                                   capture_output=True,text=True, encoding="utf-8", errors="replace").stdout.strip() or 0)
        os.makedirs(tmp+"/in")
        for i in range(6):
            subprocess.run(["ffmpeg","-v","error","-ss",f"{dur*(i+0.5)/6:.2f}","-i",SRC,"-frames:v","1","-vf","scale=960:-2",
                            "-q:v","3","-y",f"{tmp}/in/{i:02d}.jpg"])
        if sys.platform == "darwin":   # mac-only: كاشف Vision المبني بـswiftc (يمرّ عبر _paths.js)
            cmd = subprocess.run(["node","-e",f"process.stdout.write(require({json.dumps(os.path.join(os.path.dirname(os.path.abspath(__file__)),'_paths.js'))}).personmask({json.dumps(tmp)})||'')"],
                                 capture_output=True,text=True, encoding="utf-8", errors="replace").stdout.strip()
            if not cmd: return None
            subprocess.run(f'{cmd} {json.dumps(tmp+"/in")} {json.dumps(tmp+"/out")} fast 2', shell=True, capture_output=True)
        else:
            # ويندوز/لينكس: نناديه مباشرة بنفس البايثون (بلا shell): المسار عبر json.dumps يتحوّل \uXXXX لو فيه عربي (اسم مستخدم عربي) فيفشل بصمت
            r = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "personmask.py"),
                                tmp+"/in", tmp+"/out", "fast", "2"], capture_output=True, text=True, encoding="utf-8", errors="replace",
                               env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"})
            if r.returncode:
                print("⚠️ كاشف الوجه ما اشتغل — القص بوسط الكادر:", (r.stdout + r.stderr).strip()[-300:], file=sys.stderr)
                return None
        meta = _paths.read_json(tmp+"/out/meta.json")
        xs = [(r["face"]["x"]+r["face"]["w"]/2)/960 for r in meta if r.get("face")]
        return round(sorted(xs)[len(xs)//2], 3) if xs else None
    except Exception as e:
        print("⚠️ ما قدرت أحدد مكان وجهه:", e, file=sys.stderr)
        return None
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

# الإطار أضيق من التصوير (عرضي ← طولي) وما نعرف وين وجهه: نلقاه مرة ونحفظه بـtheme.json (faceX)
if SW/SH > OW/OH*1.05 and not (os.path.exists(_tp) and isinstance(_paths.read_json(_tp).get("faceX"),(int,float))):
    fx = _face_x()
    if fx is not None:
        FACEX = fx
        _th = _paths.read_json(_tp) if os.path.exists(_tp) else {}
        _th["faceX"] = fx
        _paths.write_json(_tp, _th)
        print(f"وجهه أفقياً عند {fx:.2f} من عرض التصوير — القص يلحقه")
fc=[];v=[];a=[]
for i,(s,e) in enumerate(k):
    z=Z[i%len(Z)]
    # ⛔ القص بشكل الإطار نفسه: تصوير عرضي لإطار طولي كان ينضغط (يتمطّط) بدل ما ينقص
    ch=SH/z; cw=ch*OW/OH
    if cw>SW/z: cw=SW/z; ch=cw*OH/OW
    cw=int(cw)//2*2; ch=int(ch)//2*2
    x=int(min(max(0,SW*FACEX-cw/2),SW-cw)); y=int((SH-ch)*ANCH)
    fc.append(f"[0:v]trim=start={s:.4f}:end={e:.4f},setpts=PTS-STARTPTS,crop={cw}:{ch}:{x}:{y},"
              f"scale={OW}:{OH}:flags=lanczos,setsar=1[v{i}]")
    fc.append(f"[0:a]atrim=start={s:.4f}:end={e:.4f},asetpts=PTS-STARTPTS[a{i}]")
    v.append(f"[v{i}]"); a.append(f"[a{i}]")
fc.append("".join(v)+f"concat=n={len(k)}:v=1:a=0[vc]")
fc.append("".join(a)+f"concat=n={len(k)}:v=0:a=1[ac]")
# التدرّج اللوني اختياري تماماً — الافتراضي مطفي (الفيديو يطلع بألوانه الأصلية)
# قيم التدرّج من دليل الهوية إن وُجدت، وإلا الافتراضي الخفيف
_t2 = _paths.read_json(_tp) if os.path.exists(_tp) else {}
_sat = 1.0 + float(_t2.get("gradeSat", -0.04))
_con = float(_t2.get("gradeContrast", 1.05))
_warm = "colorbalance=rs=0.03:gs=0.008:bs=-0.03," if _t2.get("gradeWarmShadows", True) else ""
_g = (f"eq=brightness=0.012:saturation={_sat:.3f}:contrast={_con:.3f}," + _warm) if GRADE else ""
# ⚠️ مصدر آيفون HDR يجي موسوماً bt2020/HLG — أي متصفح يحترم الوسم ويطلّع صورة برتقالية.
# setparams يعيد الوسم لـbt709 فتطلع الألوان طبيعية بكل مكان.
fc.append("[vc]fps=30," + _g +
          "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709,format=yuv420p[vo]")
print("التدرّج اللوني:", f"مفعّل — تشبع {_sat:.2f} · تباين {_con:.2f}" if GRADE else "مطفي (ألوان أصلية)")
# ⛔ القاعدة ١٩: صوته بلا أي معالجة — لا dynaudnorm ولا ضغط (المعاينة بالاستوديو نفس التسليم).
fc.append("[ac]afade=t=in:st=0:d=0.006[ao]")
def _ffmpeg_major():
    try:
        o = subprocess.run(["ffmpeg","-version"], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
        import re as _re
        m = _re.search(r"ffmpeg version n?(\d+)", o)
        return int(m.group(1)) if m else 99     # نسخة git/غير معروفة = حديثة
    except Exception:
        return 0
def _fc_args(graph, name):
    """ويندوز يحدّ سطر الأمر بـ32767 حرف وكل مقطع محفوظ ياخذ ~200 حرف بالـgraph (من ~165 مقطع: WinError 206).
    فنكتب الـgraph بملف ونمرّره. ffmpeg 7+: -/filter_complex · الأقدم: -filter_complex_script. الماك بحجم عادي: مثل قبل (بالسطر)."""
    if os.name != "nt" and len(graph) <= 30000 and not os.environ.get("VEB_FORCE_FC_FILE"):   # VEB_FORCE_FC_FILE=1: للاختبار على الماك
        return ["-filter_complex", graph]
    fp = os.path.join(W, name)
    with open(fp, "w", encoding="utf-8", newline="\n") as f: f.write(graph)
    return ["-/filter_complex" if _ffmpeg_major() >= 7 else "-filter_complex_script", fp]
rc=subprocess.call(["ffmpeg","-v","error","-stats","-i",SRC,*_fc_args(";".join(fc), ".cutz.fc"),
 "-map","[vo]","-map","[ao]","-c:v","libx264","-preset","medium","-crf","16",
 "-c:a","aac","-b:a","192k","-movflags","+faststart","-y",os.path.join(W,"cutz.mp4")])
if rc:
    try: os.remove(os.path.join(W,".cutz.fc"))
    except OSError: pass
    sys.exit(rc)
# صوت التسليم (القاعدة ١٩): من src.mov مباشرة بنفس القصّات — 48 كيلو · 24 بت · ستيريو · بلا أي معالجة.
# الرندر يلصقه كما هو، و20_voice_check يقارنه بالمسلَّم.
af=[f"[0:a]atrim=start={s:.4f}:end={e:.4f},asetpts=PTS-STARTPTS[a{i}]" for i,(s,e) in enumerate(k)]
af.append("".join(f"[a{i}]" for i in range(len(k)))+f"concat=n={len(k)}:v=0:a=1[ac]")
rc=subprocess.call(["ffmpeg","-v","error","-i",SRC,*_fc_args(";".join(af), ".voice.fc"),"-map","[ac]",
 "-c:a","pcm_s24le","-ar","48000","-ac","2","-y",os.path.join(W,"voice.wav")])
for _n in (".cutz.fc", ".voice.fc"):
    try: os.remove(os.path.join(W,_n))
    except OSError: pass
sys.exit(rc)
