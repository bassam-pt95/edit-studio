#!/bin/bash
# studio.sh — أوامر الاستوديو لكلود (كلها على النسخة المثبّتة بمجلد البيانات).
#   bash studio.sh status                                  يعمل؟ النسخة؟ مجلد المشاريع
#   bash studio.sh convert <مجلد الشغل> "<الاسم>" [--force] [--blocks skip] [--only-scenes A,B] [--out <مجلد>]
#                                                          نسخة المونتاج ← مشروع استوديو (يطبع آخر سطر: project: <المجلد>)
#   bash studio.sh list                                    مقاطعه القديمة بمهارة المونتاج، الأحدث أول (work = يتحوّل · final only = فيديو نهائي بس)
#   bash studio.sh final <ملف الفيديو> "<الاسم>" [--tall]    فيديو نهائي ← مشروع استوديو بلقطة وحدة، العرضي عرضي (يطبع آخر سطر: project: <المجلد>)
#   bash studio.sh open <مجلد المشروع>                      يشغّل الاستوديو لو لازم ويفتح المشروع بالمتصفح
#   bash studio.sh notes <مجلد المشروع> [--all]             الملاحظات الجديدة (أو كلها)
#   bash studio.sh reply <مجلد المشروع> <id> <ماذا سويت>    يرد على ملاحظة ويعلّمها «تمت»
#   bash studio.sh edit <مجلد المشروع> <change.mjs> [--dry-run] | --check     تعديل المشروع خطوة تراجع وحدة
#   bash studio.sh export <مجلد المشروع> "<اسم الملف>" [--range f0:f1]       تصدير ← <المشروع>/out/<الاسم>.mp4
#   bash studio.sh cuts <مجلد المشروع> <ملف mp4> [--range f0:f1]   فحص كل قصّة بملف مصدَّر (التصدير يسويه لحاله)
#   bash studio.sh sounds <مجلد المشروع> [<ملف mp4> [--range f0:f1]]   هل ضربة كل صوت على مكانها؟ (التصدير يسويه لحاله)
#   bash studio.sh dissect <ملف فيديو مرجع> [--out <مجلد>]   تشريح مقطع مرجع: صور مرقّمة وأرقام · dissect report <المجلد> [--open] ← التقرير
#   bash studio.sh stop                                    يوقف الاستوديو (ملفاته فقط)
. "$(dirname "$0")/_common.sh"
device_ok || { echo "$MSG_DEVICE"; exit 20; }
installed || { echo "$MSG_NOT_INSTALLED"; exit 12; }
NODE="$(find_node)" || { echo "ما لقيت Node على الجهاز."; exit 11; }
T="$APP/studio/tools"
[ -x "$PY" ] && export MOHRER_PYTHON="$PY"
export_chrome     # ويندوز: التصدير ياخذ مسار المتصفح من CHROME (كروم أو Edge، نفس اللي يفحصه doctor). الماك: لا شي
export MOHRER_HOME="${MOHRER_HOME:-$DATA/home}"
cmd="${1:-}"; shift || true

# ويندوز: Git Bash يحوّل أي وسيط يبدأ بـ«/» إلى مسار، فنص مثل «/عدّلت كذا» يتخرب قبل ما يوصل node. فنحوّل المسارات الحقيقية بأنفسنا
# (wargs ← مصفوفة WA) ونمنع التحويل التلقائي (nodex). الماك: نفس الوسائط ونفس الأمر
wargs(){
  WA=(); local a
  for a in "$@"; do
    if [ "$OS" = win ]; then
      case "$a" in /[a-zA-Z]/*) a="$(wp "$a")" ;; /*) [ -e "$a" ] && a="$(wp "$a")" ;; esac
    fi
    WA+=("$a")
  done
}
nodex(){ if [ "$OS" = win ]; then MSYS2_ARG_CONV_EXCL='*' "$NODE" "$@"; else "$NODE" "$@"; fi; }
need(){ [ -n "${1:-}" ] || { sed -n '2,17p' "$0"; exit 2; }; }
run_bg(){ bash "$SCRIPTS_DIR/start.sh" --no-open >/dev/null || { bash "$SCRIPTS_DIR/start.sh" --no-open; exit 1; }; }

case "$cmd" in
  status)
    URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
    echo "version: $("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).version)}catch{}' "$APP/manifest.json")"
    echo "running: ${URL:-no}"
    echo "projects: $(wp "$PROJECTS")"
    echo "data: $(wp "$DATA")" ;;
  convert)
    need "${1:-}"; need "${2:-}"
    work="$1"; name="$2"; shift 2
    "$NODE" "$APP/studio/start.mjs" --init >/dev/null
    # المشاهد المرسومة تحتاج ريموشن مثبّتاً بمجلد الشغل وبايثون الاستوديو؛ بدونها تنتقل كقائمة بس
    case " $* " in *" --blocks "*) ;; *)
      if [ ! -d "$work/remotion/node_modules" ] || ! { [ -x "$PY" ] && "$PY" -c "import cv2, PIL" 2>/dev/null; }; then
        echo "note: scene blocks skipped ($( [ -d "$work/remotion/node_modules" ] && echo 'the studio Python is incomplete: setup.sh --install' || echo 'no Remotion in the work folder' ))"
        set -- "$@" --blocks skip
      fi ;; esac
    # the converter's own «open: node …» hint is dropped: the next step is `studio.sh open`, and «project: …» stays last
    conv(){ wargs "$@"; nodex "$(wp "$T/from-work.mjs")" "${WA[@]}" | while IFS= read -r l; do case "$l" in "open: "*) ;; *) printf '%s\n' "$l" ;; esac; done
      return "${PIPESTATUS[0]}"; }
    case " $* " in *" --out "*) conv "$work" --name "$name" "$@" ;;
      *) conv "$work" --name "$name" --root "$PROJECTS" "$@" ;; esac
    exit $? ;;
  list)
    exec "$NODE" "$T/old-work.mjs" "$VEB/projects" "$PROJECTS" ;;
  final)
    need "${1:-}"; need "${2:-}"
    "$NODE" "$APP/studio/start.mjs" --init >/dev/null
    vid="$1"; name="$2"; shift 2      # بعدها: --tall (فيديو عرضي يبقى بإطار طولي) أو --wide
    wargs "$vid" --name "$name" --root "$PROJECTS" "$@"
    nodex "$(wp "$T/new-project.mjs")" final "${WA[@]}" | while IFS= read -r l; do case "$l" in "open: "*) ;; *) printf '%s\n' "$l" ;; esac; done
    exit "${PIPESTATUS[0]}" ;;
  open)
    need "${1:-}"; run_bg
    exec "$NODE" "$T/open.mjs" "$1" --browser ;;
  notes)
    need "${1:-}"; exec "$NODE" "$T/notes.mjs" "$@" ;;
  reply)
    need "${1:-}"; need "${2:-}"; need "${3:-}"
    wargs "$1" --reply "$2" "${@:3}"
    if [ "$OS" = win ]; then MSYS2_ARG_CONV_EXCL='*' exec "$NODE" "$(wp "$T/notes.mjs")" "${WA[@]}"; fi
    exec "$NODE" "$T/notes.mjs" "$1" --reply "$2" "${@:3}" ;;
  edit)
    need "${1:-}"; need "${2:-}"; exec "$NODE" "$T/edit.mjs" "$@" ;;
  export)
    need "${1:-}"; need "${2:-}"; run_bg
    exec "$NODE" "$T/export.mjs" "$@" ;;
  cuts)
    need "${1:-}"; need "${2:-}"; exec "$NODE" "$T/cutcheck.mjs" "$@" ;;
  sounds)
    need "${1:-}"; exec "$NODE" "$T/soundcheck.mjs" "$@" ;;
  dissect)
    need "${1:-}"; exec "$NODE" "$T/dissect.mjs" "$@" ;;
  stop)
    exec "$NODE" "$APP/studio/start.mjs" --stop ;;
  *) sed -n '2,17p' "$0"; exit 2 ;;
esac
