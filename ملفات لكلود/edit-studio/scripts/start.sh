#!/bin/bash
# start.sh — يشغّل «استوديو المونتاج» بالخلفية (لو مو شغّال) ويفتحه بالمتصفح.
#   bash start.sh              شغّل وافتح المتصفح
#   bash start.sh --no-open    شغّل بس، واطبع العنوان
# يطبع سطراً أخيراً: «الاستوديو يعمل: <العنوان>». المنفذ 8795، ولو مشغول فالي بعده.
# الخروج: 0 يعمل · 1 ما اشتغل (السجل: <البيانات>/studio/server.log) · 12 غير مثبّت · 20 جهاز غير مدعوم
. "$(dirname "$0")/_common.sh"
device_ok || { echo "$MSG_DEVICE"; exit 20; }
installed || { echo "$MSG_NOT_INSTALLED"; exit 12; }
NODE="$(find_node)" || { echo "ما لقيت Node على الجهاز. شغّل تجهيز مهارة المونتاج أولاً."; exit 11; }

URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
if [ -z "$URL" ]; then
  mkdir -p "$DATA"
  # الاستوديو يبقى شغّال بعد هالسكربت، فلازم ما يمسك مخرجه: بدون التحويل الأخير يظل اللي شغّل السكربت (كلود) منتظر
  # مخرج ما يجي لين تنتهي مهلته، مع إن الاستوديو اشتغل
  ( cd "$DATA" && nohup "$NODE" "$APP/studio/start.mjs" ${STUDIO_PORT:+--port "$STUDIO_PORT"} >> "$DATA/server.log" 2>&1 & ) >/dev/null 2>&1 </dev/null
  for _ in $(seq 1 60); do
    URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
    [ -n "$URL" ] && break
    sleep 0.25
  done
fi
if [ -z "$URL" ]; then
  echo "تعذّر تشغيل الاستوديو. آخر سطور السجل:"
  tail -n 5 "$DATA/server.log" 2>/dev/null
  echo "شغّل التشخيص: bash \"$APP/scripts/doctor.sh\""
  exit 1
fi
if [ "${1:-}" != "--no-open" ]; then
  open_url "$URL"
fi
echo "الاستوديو يعمل: $URL"
