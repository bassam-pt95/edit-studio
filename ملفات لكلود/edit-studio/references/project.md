# مشروع الاستوديو وطريقة تعديله

## القاعدة
لا تكتب `project.json` بيدك. كل تعديل بملف تغيير صغير وأداة `edit`:
```bash
mkdir -p "<البيانات>/studio/edits"
# اكتب الملف: <البيانات>/studio/edits/<رقم>.mjs   (انظر الأمثلة تحت)
bash "$S/studio.sh" edit "<المشروع>" "<البيانات>/studio/edits/<رقم>.mjs" --dry-run   # يتحقق بلا كتابة
bash "$S/studio.sh" edit "<المشروع>" "<البيانات>/studio/edits/<رقم>.mjs"             # يطبّق
bash "$S/studio.sh" edit "<المشروع>" --check                                           # «ok» = الملف سليم
```
- الأداة تتحقق من المشروع قبل الكتابة (أي خطأ: ترفض وما تكتب شي)، وتطبّق عبر الاستوديو المفتوح:
  التعديل يظهر عنده فوراً، **ويقدر يتراجع عنه بخطوة وحدة** (⌘Z، ويندوز: Ctrl+Z)، وتنحفظ نسخة قبله.
- `applied` = تمام. `refused …` = اقرأ السبب وصحّح ملف التغيير. `nothing changed` = ما تغيّر شي (راجع المعرّفات).

## ملف التغيير
```js
// <البيانات>/studio/edits/1.mjs
export default (p, h) => {
  h.op('setCaptionStyle', { patch: { size: 60 } });   // عمليات المحرّر نفسه (الأفضل)
  h.p.captions.words.find((w) => w.id === 'w_12').t = 'تشوفه';   // أو تعديل مباشر على h.p
};
```
- `h.op(name, args)` يطبّق عملية من عمليات المحرّر على `h.p` (نفس اللي تسويها أزرار الاستوديو). **بعد أي `h.op` اشتغل على `h.p`**.
- مساعدات: `h.wordsAt(frame)` الكلمات حول إطار (`{id, t, sent, on, off}`) · `h.sentenceWords(sent)` معرّفات كلمات جملة ·
  `h.itemsAt(frame)` العناصر فوق إطار · `h.frames(sec)` · `h.sec(frames)` · `h.words()` · `h.sentences()` · `h.clip(id)` · `h.item(id)` ·
  `h.layout()` · `h.ops` (أسماء كل العمليات).
- الوقت: الملاحظة فيها `frame` (من `notes --json`) = إطار الخط الزمني. `h.wordsAt(note.frame)` يعطيك الكلمات اللي حولها.

## العمليات الأكثر استخداماً
| الملاحظة | العملية |
|---|---|
| «احذف هالجملة/الكلمات» (من الفيديو نفسه) | `h.op('cutWords', {ids: [معرّفات الكلمات]})` يقص الفيديو تحتها ويقفل الفراغ. الجملة كاملة: `const w = h.wordsAt(frame).find((x) => x.t === 'كلمة منها'); h.op('cutWords', {ids: h.sentenceWords(w.sent)})` |
| «احذف هالصورة/الصوت» | `h.op('remove', {ids: ['x_…']})` |
| كلمة مكتوبة غلط | `h.op('setWordText', {id: 'w_…', t: 'النص الصحيح'})` |
| ميّز كلمة (لون التمييز) | `h.op('setWordFlags', {ids: ['w_…'], k: true})` (‏`false` يشيله) |
| سطر جديد قبل كلمة | `h.op('setWordFlags', {ids: ['w_…'], br: true})` |
| أخفِ كلمة من الكابشن | `h.op('setWordFlags', {ids: ['w_…'], hidden: true})` |
| الكابشن كله أكبر/لون/خط | `h.op('setCaptionStyle', {patch: {size: 60, color: '#FFFFFF', active: '#E0B04C', font: 'Cairo', weight: 700}})` |
| لون الكلمات المميزة | `h.op('setKeywordStyle', {patch: {color: '#E0B04C'}})` |
| «ترجم الكابشن للإنجليزي» | `h.op('setEnglish', {patch: {show: true}})` ثم لكل جملة `h.op('setSentenceEn', {id: 't_…', en: 'the English sentence'})` (‏`h.sentences()` فيها المعرّفات) |
| ارفع/نزّل الكابشن | `h.op('setCaptionPos', {y: 1500})` (بكسل من فوق، الإطار 1080×1920) |
| الكابشن يطلع بدري/متأخر | `h.op('shiftCaptions', {dSec: -0.1})` (الكل) · `h.op('moveWords', {ids, dSec: 0.05})` |
| كبّر/صغّر/حرّك صورة | `h.op('setTf', {ids: ['x_…'], patch: {s: 1.1, x: 0, y: -200}})` (‏x,y بكسل عن منتصف الإطار) |
| شفافية صورة | `h.op('setProps', {ids: ['x_…'], patch: {'tf.o': 0.8}})` |
| صوت أعلى/أخفض | `h.op('setProps', {ids: ['x_…'], patch: {'audio.gain': -6}})` (ديسيبل) |
| قدّم/أخّر عنصراً | `h.op('moveItems', {ids: ['x_…'], dFrames: 15})` |
| طوّل/قصّر عنصراً | `h.op('trimItems', {ids: ['x_…'], edge: 'R', delta: 30})` (إطارات؛ ‏`L` للبداية) |
| زوم على لقطة | `h.op('setSpineTf', {ids: ['c_…'], tf: {s: 1.15}})` (‏1 = بلا زوم، حتى 4) |
| علامته المائية | `h.op('setWatermark', {patch: {'tf.s': 1.2, on: true}})` |
| صوت المقطع العام | `h.op('setProjectAudio', {patch: {'sounds.gain': -3}})` |

⛔ **صوته وصورته ما تنلمس** (قاعدة مهارة المونتاج): لا تغيّر `audio.voice` ولا الألوان (`grades`، `color`) إلا بطلبه الصريح.

## شكل الملف باختصار (للقراءة)
- `fps` ‏[30, 1] · `width` 1080 · `height` 1920 · `name`.
- `assets{id: {kind: video|image|audio, file, …}}`: الملفات (المسارات داخل مجلد المشروع).
- `spine[]`: لقطات الفيديو بالترتيب `{id: 'c_…', asset, in (ثانية بالمصدر), dur (إطارات), tf?, view?}`.
- `attached[]`: كل شي فوق الفيديو `{id: 'x_…', role: media|sound|character|fx, asset, parent (لقطة), anchor (ثانية بمصدر اللقطة), dur (إطارات), lane, label, tf?, audio?}`.
  `x_i_…` صورة · `x_g_…` مشهد مرسوم · `x_s…` صوت.
- `captions`: `{enabled, style, keyword, sentences[{id: 't_…', s, e}], words[{id: 'w_…', sent, t (النص), s, e (ثواني بالمصدر), k? مميزة, br? سطر جديد, hidden?}]}`.
- `audio`: `{voice: {locked, gain}, sounds: {gain}, …}` · `window` (نوافذ الفيديو) · `background` · `watermark`.
- الكلمات مربوطة بوقت المصدر، فالقص ما يخرّبها: الكلمة اللي انقص وقتها تختفي لحالها.
