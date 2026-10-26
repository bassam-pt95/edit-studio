#!/bin/bash
# start.sh — يشغّل «B Studio» بالخلفية (لو مو شغّال) ويفتحه بالمتصفح.
#   bash start.sh              شغّل وافتح المتصفح
#   bash start.sh --no-open    شغّل بس، واطبع العنوان
# يطبع سطراً أخيراً: «الاستوديو يعمل: <العنوان>». المنفذ 8795، ولو مشغول فالي بعده.
# الخروج: 0 يعمل · 1 ما اشتغل (السجل: <البيانات>/studio/server.log) · 12 غير مثبّت · 20 جهاز غير مدعوم
. "$(dirname "$0")/_common.sh"
device_ok || { echo "$MSG_DEVICE"; exit 20; }
installed || { echo "$MSG_NOT_INSTALLED"; exit 12; }
NODE="$(find_node)" || { echo "ما لقيت Node على الجهاز. شغّل تجهيز مهارة المونتاج أولاً."; exit 11; }
export_chrome     # ويندوز: الاستوديو يصدّر بنفس المتصفح اللي يفتح به (كروم أو Edge). الماك: لا شي

URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
if [ -z "$URL" ]; then
  mkdir -p "$DATA"
  # الاستوديو يبقى شغّال بعد هالسكربت، فلازم ما يمسك مخرجه: بدون التحويل الأخير يظل اللي شغّل السكربت (كلود) منتظر
  # مخرج ما يجي لين تنتهي مهلته، مع إن الاستوديو اشتغل
  if [ "$OS" = win ]; then
    # ويندوز: node يشغل السيرفر منفصل عن اي طرفية (بلا console) ومخفي، ومجلد شغله مجلد المستخدم: تسكير نافذة الطرفية
    # ما يوقفه، ومجلد البيانات ما ينمسك كمجلد شغل (server.log يظل مفتوح، فالنقل بعد studio.sh stop)
    "$NODE" -e "const{spawn}=require('child_process'),fs=require('fs'),os=require('os');const o=fs.openSync(process.argv[2],'a');spawn(process.execPath,[process.argv[1],...process.argv.slice(3)],{detached:true,windowsHide:true,cwd:os.homedir(),stdio:['ignore',o,o]}).unref()" "$APP/studio/start.mjs" "$DATA/server.log" ${STUDIO_PORT:+--port "$STUDIO_PORT"} >/dev/null 2>&1 </dev/null
  else
    ( cd "$DATA" && nohup "$NODE" "$APP/studio/start.mjs" ${STUDIO_PORT:+--port "$STUDIO_PORT"} >> "$DATA/server.log" 2>&1 & ) >/dev/null 2>&1 </dev/null
  fi
  for _ in $(seq 1 60); do
    URL="$("$NODE" "$APP/studio/start.mjs" --url 2>/dev/null)"
    [ -n "$URL" ] && break
    sleep 0.25
  done
fi
if [ -z "$URL" ]; then
  echo "تعذّر تشغيل الاستوديو. آخر سطور السجل:"
  tail -n 5 "$DATA/server.log" 2>/dev/null
  echo "شغّل التشخيص: bash \"$(wp "$APP")/scripts/doctor.sh\""
  exit 1
fi
if [ "${1:-}" != "--no-open" ]; then
  open_url "$URL"
fi
echo "الاستوديو يعمل: $URL"
