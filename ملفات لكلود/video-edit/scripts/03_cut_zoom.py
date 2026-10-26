# -*- coding: utf-8 -*-
"""قص السكتات + زوم مختلف لكل مقطع (+ تدرّج لوني لو طلبه فقط).  python3 03_cut_zoom.py <workdir>
يطلّع cutz.mp4 (الفيديو المقصوص للمعاينة والرندر) وvoice.wav (صوته للتسليم، بلا أي معالجة)."""
import json, subprocess, sys, os
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths
W=os.path.abspath(sys.argv[1]); SRC=os.path.join(W,"src.mov")
OW, OH = _paths.frame(W)          # إطار المقطع (طولي 1080×1920 · عرضي 1920×1080 · مربع)
k=json.load(open(os.path.join(W,"cut.json"),encoding="utf-8-sig"))["keep"]
_tp=os.path.join(W,"theme.json")
GRADE=json.load(open(_tp,encoding="utf-8-sig")).get("grade",False) if os.path.exists(_tp) else False
Z=[1.00,1.08,1.00,1.06,1.00,1.12,1.04,1.14,1.00,1.08,1.00,1.05,1.10,1.00]; ANCH=0.30; FACEX=0.5
_at=os.path.join(W,"theme.json")
if os.path.exists(_at):
    _t=json.load(open(_at,encoding="utf-8-sig"))
    if isinstance(_t.get("zoomAnchor"),(int,float)): ANCH=float(_t["zoomAnchor"])
    if _t.get("noZoom"): Z=[1.00]
    # faceX: وين وجهه أفقياً بالتصوير (0 يسار · 1 يمين) — لما الإطار أضيق من التصوير (عرضي ← طولي) القص يلحقه
    if isinstance(_t.get("faceX"),(int,float)): FACEX=float(_t["faceX"])
_pv=json.loads(subprocess.run(["ffprobe","-v","error","-select_streams","v:0","-show_streams","-of","json",SRC],
   capture_output=True,text=True,encoding="utf-8",errors="replace").stdout)["streams"][0]
SW,SH=int(_pv["width"]),int(_pv["height"])
def _rotation(st):
    """وسم الدوران بالدرجات (0..359): side_data_list (displaymatrix) أو وسم rotate القديم (ffmpeg قبل 5)."""
    r=0.0
    try: r=float((st.get("tags") or {}).get("rotate",0) or 0)
    except (TypeError,ValueError): pass
    for sd in st.get("side_data_list") or []:
        if "rotation" in sd:
            try: r=float(sd["rotation"])
            except (TypeError,ValueError): pass
    return int(round(r))%360
# ⛔ تصوير الجوال ينحفظ عرضي (1920×1080) وعليه وسم دوران 90/270، وffmpeg يدوّره قبل الفلاتر (1080×1920):
#    القص المحسوب على المقاس المخزّن طلع زوم من فوق يقص وجهه، ومكان وجهه انحسب بعرض غلط. نحسب على المقاس بعد الدوران.
if _rotation(_pv) in (90,270): SW,SH=SH,SW
# ⛔ مدى كامل (pc · yuvj420p حق الآيفون) أو مصفوفة 601 (smpte170m): setparams تحت يغيّر الوسم بس، فكان cutz يطلع
#    بمداه الكامل تحت وسم bt709 و21_color_check يرفضه (ΔY −2.1). هذي المصادر تتحوّل فعلاً لـtv/709 قبل الوسم.
#    مصدر tv/709 (والـD-Log وHLG، مداهم tv) ما يمر من هنا: أمر ffmpeg نفسه بالحرف مثل قبل.
_RNG="pc" if str(_pv.get("pix_fmt","")).startswith("yuvj") or _pv.get("color_range")=="pc" else "tv"
_MAT={"smpte170m":"bt601","bt470bg":"bt601","smpte240m":"smpte240m","fcc":"fcc",
      "bt2020nc":"bt2020","bt2020c":"bt2020"}.get(_pv.get("color_space"),"bt709")   # بلا وسم = 709 مثل setparams تحت
_CONV=_RNG=="pc" or _MAT in ("bt601","smpte240m","fcc")

def _face_x():
    """وين وجهه أفقياً (0..1) من ٦ فريمات من التصوير — بكاشف الوجه نفسه (Vision بالماك · mediapipe بغيره)."""
    import tempfile, shutil
    tmp = tempfile.mkdtemp(prefix="facex-")
    try:
        dur = float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",SRC],
                                   capture_output=True,text=True,encoding="utf-8",errors="replace").stdout.strip() or 0)
        os.makedirs(tmp+"/in")
        for i in range(6):
            subprocess.run(["ffmpeg","-v","error","-ss",f"{dur*(i+0.5)/6:.2f}","-i",SRC,"-frames:v","1","-vf","scale=960:-2",
                            "-q:v","3","-y",f"{tmp}/in/{i:02d}.jpg"])
        if os.name == 'nt':
            # ويندوز: personmask.py مباشرة ببايثون الكاشف، كل وسيط لحاله، بلا node ولا shell ولا json.dumps
            # (json.dumps يحول الحروف العربية في مسار %TEMP% الى \uXXXX، فيوصل مسار غلط وتنعمل مجلدات زبالة)
            # --faces-only: نبي مكان الوجه بس، بلا قص الشخص
            r = subprocess.run([_paths.face_python(),"-X","utf8",os.path.join(os.path.dirname(os.path.abspath(__file__)),"personmask.py"),
                                os.path.join(tmp,"in"),os.path.join(tmp,"out"),"fast","2","--faces-only"],
                               capture_output=True,text=True,encoding="utf-8",errors="replace")
            if r.returncode:
                import re   # سجلات mediapipe (W0000 …) تنطبع بعد رسالة الخطا، فناخذ اخر سطر غيرها
                why = [l for l in (r.stderr+"\n"+r.stdout).splitlines() if l.strip() and not re.match(r"[IWEF]\d{4} |WARNING: All log|INFO: Created TensorFlow",l)]
                print("⚠️ كاشف الوجه ما اشتغل — القص بالنص: "+(why[-1][:160] if why else f"exit {r.returncode}"))
                return None
        else:
            cmd = subprocess.run(["node","-e",f"process.stdout.write(require({json.dumps(os.path.join(os.path.dirname(os.path.abspath(__file__)),'_paths.js'))}).personmask({json.dumps(tmp)})||'')"],
                                 capture_output=True,text=True,encoding="utf-8",errors="replace").stdout.strip()
            if not cmd: return None
            subprocess.run(f'{cmd} {json.dumps(tmp+"/in")} {json.dumps(tmp+"/out")} fast 2', shell=True, capture_output=True)
        meta = json.load(open(tmp+"/out/meta.json",encoding="utf-8-sig"))
        xs = [(r["face"]["x"]+r["face"]["w"]/2)/960 for r in meta if r.get("face")]
        return round(sorted(xs)[len(xs)//2], 3) if xs else None
    except Exception as e:
        if os.name == 'nt': print(f"⚠️ ما قدرت القى وجهه — القص بالنص ({e})")
        else: print("⚠️ ما قدرت أحدد مكان وجهه:", e, file=sys.stderr)   # الماك: مثل قبل، على stderr
        return None
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

# الإطار أضيق من التصوير (عرضي ← طولي) وما نعرف وين وجهه: نلقاه مرة ونحفظه بـtheme.json (faceX)
if SW/SH > OW/OH*1.05 and not (os.path.exists(_tp) and isinstance(json.load(open(_tp,encoding="utf-8-sig")).get("faceX"),(int,float))):
    fx = _face_x()
    if fx is not None:
        FACEX = fx
        _th = json.load(open(_tp,encoding="utf-8-sig")) if os.path.exists(_tp) else {}
        _th["faceX"] = fx
        with open(_tp,"w",encoding="utf-8") as fh: json.dump(_th, fh, ensure_ascii=False, indent=1)
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
_t2 = json.load(open(_tp,encoding="utf-8-sig")) if os.path.exists(_tp) else {}
_sat = 1.0 + float(_t2.get("gradeSat", -0.04))
_con = float(_t2.get("gradeContrast", 1.05))
_warm = "colorbalance=rs=0.03:gs=0.008:bs=-0.03," if _t2.get("gradeWarmShadows", True) else ""
_g = (f"eq=brightness=0.012:saturation={_sat:.3f}:contrast={_con:.3f}," + _warm) if GRADE else ""
# ⚠️ مصدر آيفون HDR يجي موسوماً bt2020/HLG — أي متصفح يحترم الوسم ويطلّع صورة برتقالية.
# setparams يعيد الوسم لـbt709 فتطلع الألوان طبيعية بكل مكان.
# مدى كامل أو 601 (_CONV فوق): scale يحوّل القيم نفسها لـtv/709 أول (HLG بمدى كامل: المدى بس، ومصفوفته تنوسم مثل قبل).
# accurate_rnd وfull_chroma: بدونها التحويل يميل (مقيس: R −1.2 · B −1.0 من 255)، ومعها ≤ 0.1
_cv=(f"scale=in_range={_RNG}:in_color_matrix={_MAT}:out_range=tv:out_color_matrix={'bt2020' if _MAT=='bt2020' else 'bt709'}"
     ":flags=bicubic+accurate_rnd+full_chroma_int+full_chroma_inp,format=yuv420p,") if _CONV else ""
if _CONV: print(f"المصدر {_RNG}/{_pv.get('color_space') or 'بلا وسم'} — يتحوّل لـtv/bt709 (مو وسم بس)")
fc.append("[vc]fps=30," + _cv + _g +
          "setparams=" + ("range=tv:" if _CONV else "") + "color_primaries=bt709:color_trc=bt709:colorspace=bt709,format=yuv420p[vo]")
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
    """الماك (وغير ويندوز)، مثل قبل: الـgraph فوق 30,000 حرف (أو VEB_FORCE_FC_FILE=1 للاختبار) ينكتب بملف ونمرّره.
    ffmpeg 7+: -/filter_complex · الأقدم: -filter_complex_script. بحجم عادي: بالسطر."""
    if len(graph) <= 30000 and not os.environ.get("VEB_FORCE_FC_FILE"):
        return ["-filter_complex", graph]
    fp = os.path.join(W, name)
    with open(fp, "w", encoding="utf-8", newline="\n") as f: f.write(graph)
    return ["-/filter_complex" if _ffmpeg_major() >= 7 else "-filter_complex_script", fp]
# ويندوز: سطر الامر حده 32,767 حرف وكل مقطع ياخذ ~195 حرف من الفلاتر، فالطويلة تروح لـffmpeg بملف (-/filter_complex يبي ffmpeg 7 او احدث).
# اللي تحت 30,000 حرف تظل بالسطر مثل قبل، فحتى ffmpeg الاقدم يقص المقاطع القصيرة
def _fc(graph, name):
    if os.name != 'nt': return _fc_args(graph, name)   # الماك: _fc_args فوق
    if os.name != 'nt' or len(graph) < 30000: return ["-filter_complex", graph]
    p = os.path.join(W, name)
    with open(p, "w", encoding="utf-8") as f: f.write(graph)
    return ["-/filter_complex", p]
try:
    rc=subprocess.call(["ffmpeg","-v","error","-stats","-i",SRC,*_fc(";".join(fc),".cutz.fc"),
     "-map","[vo]","-map","[ao]","-c:v","libx264","-preset","medium","-crf","16",
     "-c:a","aac","-b:a","192k","-movflags","+faststart","-y",os.path.join(W,"cutz.mp4")])
    if rc: sys.exit(rc)
    # صوت التسليم (القاعدة ١٩): من src.mov مباشرة بنفس القصّات — 48 كيلو · 24 بت · ستيريو · بلا أي معالجة.
    # الرندر يلصقه كما هو، و20_voice_check يقارنه بالمسلَّم.
    # فلاتره بملف غير ملف الفيديو: af يعيد اسم [ac]
    af=[f"[0:a]atrim=start={s:.4f}:end={e:.4f},asetpts=PTS-STARTPTS[a{i}]" for i,(s,e) in enumerate(k)]
    af.append("".join(f"[a{i}]" for i in range(len(k)))+f"concat=n={len(k)}:v=0:a=1[ac]")
    sys.exit(subprocess.call(["ffmpeg","-v","error","-i",SRC,*_fc(";".join(af),".voice.fc"),"-map","[ac]",
     "-c:a","pcm_s24le","-ar","48000","-ac","2","-y",os.path.join(W,"voice.wav")]))
finally:
    if os.name == 'nt':   # ملفات الفلاتر تنشال حتى لو ffmpeg فشل او انقطع
        for _n in (".cutz.fc", ".voice.fc"):
            try: os.remove(os.path.join(W, _n))
            except OSError: pass
    else:   # الماك: ملفات الفلاتر (لو انكتبت، فوق 30,000 حرف) تنشال بعد ffmpeg، نجح أو فشل — مثل قبل
        for _n in (".cutz.fc", ".voice.fc"):
            try: os.remove(os.path.join(W, _n))
            except OSError: pass
