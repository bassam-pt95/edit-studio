# -*- coding: utf-8 -*-
"""مسارات المهارة وبيانات المستخدم — مكان واحد يعرّفها للكل.

SKILL : مجلد المهارة نفسه (للقراءة فقط — ما نكتب فيه شي).
HOME  : مجلد بيانات المستخدم. كل شي يخصّه ينحفظ هنا ويبقى بين المقاطع:
        profile.json (هويته) · voice.md (لغته) · mechanisms.json + LEDGER.md (سجل آلياته)
        dialect.json (لهجته) · sounds/ (مكتبة أصواته) · refs/ (مراجعه) · tools/ (أدوات منزّلة)
        الافتراضي: ~/Documents/video-edit — ويتغيّر بمتغيّر البيئة VEB_HOME.
"""
import os, sys, json, re, subprocess, unicodedata
SKILL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def default_home(platform=None, env=None, home=None, exists=None, drive_root="C:\\"):
    """مجلد البيانات الافتراضي. ماك/لينكس: ~/Documents/video-edit كما كان. ويندوز: نفس المجلد لو مساره ASCII عادي وخارج OneDrive،
    وإلا C:\\EditStudio (OpenCV وmediapipe والوصلات تتعثر بالعربي وOneDrive) — نفس قاعدة الاستوديو (platform.mjs dataHomeDefault)
    وسكربتات sh (_common.sh تسأل HOME من هنا). VEB_HOME يغلب دايماً. الوسائط محقونة للاختبار."""
    import ntpath
    env = os.environ if env is None else env
    if env.get("VEB_HOME"): return env["VEB_HOME"]
    home = os.path.expanduser("~") if home is None else home
    if (sys.platform if platform is None else platform) != "win32":
        return os.path.join(home, "Documents", "video-edit")
    plain = ntpath.join(home, "Documents", "video-edit")
    od = env.get("OneDrive") or env.get("OneDriveConsumer") or env.get("OneDriveCommercial")   # Documents منقول لـOneDrive
    synced = bool(od) and (exists or os.path.isdir)(ntpath.join(od, "Documents"))
    risky = bool(re.search(r"[^\x20-\x7e]", plain) or re.search(r"onedrive", plain, re.I) or re.search(r"[\\/]AppData[\\/]", plain, re.I))
    return ntpath.join(drive_root, "EditStudio") if (risky or synced) else plain

HOME = default_home()

def ensure():
    for d in ("", "sounds", "refs", "tools"):
        os.makedirs(os.path.join(HOME, d), exist_ok=True)
    return HOME

def data(*p):
    return os.path.join(HOME, *p)

def load(name, default):
    p = data(name)
    if not os.path.exists(p):
        return default
    return read_json(p)

def read_json(p):
    """JSON بترميز utf-8 وبتحمّل BOM — PowerShell 5.1 (Set-Content -Encoding utf8) يكتب BOM فيطيح json.load العادي."""
    with open(p, encoding="utf-8-sig") as f:
        return json.load(f)

def write_json(p, d, indent=1):
    """يكتب JSON بـutf-8 وعربي مقروء وسطر LF — نفس الناتج على كل نظام (ويندوز يكتب CRLF والترميز المحلي بدون هذا)."""
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=indent)

def utf8_guard(argv=None, is_nt=None, utf8_mode=None, runner=None, env=None):
    """ويندوز بدون PYTHONUTF8: stdout/open بترميز محلي (cp1252/cp1256) فأي print عربي أو ✅ يطيح بـUnicodeEncodeError.
    الحارس يعيد تشغيل السكربت نفسه بـpython -X utf8 مرة وحدة ويخرج برمزه. على الماك/لينكس لا يسوي شي.
    (الوسائط محقونة عشان الاختبار يزوّر ويندوز.)"""
    nt = (os.name == "nt") if is_nt is None else is_nt
    mode = sys.flags.utf8_mode if utf8_mode is None else utf8_mode
    if not nt or mode:
        return
    e = dict(os.environ if env is None else env)
    e["PYTHONUTF8"] = "1"; e["PYTHONIOENCODING"] = "utf-8"
    cmd = [sys.executable, "-X", "utf8"] + list(sys.argv if argv is None else argv)
    sys.exit((runner or subprocess.call)(cmd, env=e))

def keep_awake(on=True, platform=None, setter=None):
    """ويندوز ينام الجهاز في نص تفريغ طويل على المعالج. SetThreadExecutionState(ES_CONTINUOUS|ES_SYSTEM_REQUIRED) يمنعه
    طول ما السكربت شغّال، وعند الإيقاف يرجّع الوضع الطبيعي. بغير ويندوز لا يسوي شي. (setter محقون للاختبار)"""
    if (sys.platform if platform is None else platform) != "win32":
        return False
    flags = 0x80000001 if on else 0x80000000
    try:
        if setter is None:
            import ctypes
            setter = ctypes.windll.kernel32.SetThreadExecutionState
        setter(flags)
        return True
    except Exception:
        return False

_BAD_CHARS = re.compile(r'[\x00-\x1f\x7f<>:"/\\|?*]')
_RESERVED = re.compile(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$", re.I)

def sanitize_name(name, fallback="out"):
    """اسم ملف/مجلد يصلح على ويندوز (وبقية الأنظمة): يبدّل | > < " * ? : \\ / والمحارف التحكمية بشرطة،
    يشيل النقطة والمسافة من آخره، يسبق أسماء الأجهزة المحجوزة (CON · NUL · COM1…) بـ_، ويوحّد الهمزات NFC.
    الاسم العربي والـ؟ العربية يبقون. ما يرجع فاضي أبداً."""
    def clean(x):
        x = unicodedata.normalize("NFC", "" if x is None else str(x))
        return _BAD_CHARS.sub("-", x).strip(" ").rstrip(" .")
    s = clean(name) or clean(fallback) or "out"
    if _RESERVED.match(s.split(".")[0].rstrip(" ")):
        s = "_" + s
    return s

_SAFE_SH = re.compile(r"^[\w@%+=:,./-]+$")

def shq(p):
    """مسار للأمر المطبوع بالخطوة الجاية: شرطات أمامية (Git Bash ياكل الخلفية) ومقتبس لو فيه مسافة/رمز.
    العربي والمسار العادي يطلعون كما هم (نفس الماك)."""
    p = str(p).replace("\\", "/")
    return p if _SAFE_SH.match(p) else "'" + p.replace("'", "'\"'\"'") + "'"

def nfc(s):
    """يوحّد الهمزة والمدّة: أسماء الملفات من ماك تجي NFD وما تطابق المفاتيح اللي نكتبها NFC."""
    return unicodedata.normalize("NFC", s)

EMPTY_LEDGER = {"videos": [], "mechs": {}, "rejected": [], "sounds": {}}

# إطار المقطع: theme.json ← "frame": "tall" (طولي، الافتراضي) · "wide" (عرضي 16:9) · "square" (مربع)
FRAMES = {"tall": (1080, 1920), "wide": (1920, 1080), "square": (1080, 1080)}

def frame(work):
    """(W, H) لإطار المقطع من <work>/theme.json."""
    p = os.path.join(work, "theme.json")
    name = "tall"
    if os.path.exists(p):
        try:
            name = read_json(p).get("frame", "tall")
        except Exception as e:
            # ⛔ كان يرجع «طولي» بصمت فمشروع عريض ينفحص كأنه طولي ويطيح الرندر بعدين
            print(f"⚠️ theme.json موجود وما انقرا ({e}) — اعتبرت الإطار طولي. صلّحه أو اكتبه ببايثون بدل PowerShell.", file=sys.stderr)
    return FRAMES.get(name, FRAMES["tall"])
