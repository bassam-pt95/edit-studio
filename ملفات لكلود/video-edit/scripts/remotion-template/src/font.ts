import {cancelRender, continueRender, delayRender} from 'remotion';
import {T, FONT_LOCAL} from './theme';

/* ⛔ القاعدة ١٤ — الوزن الغائب يخرّب الفيديو بصمت.
   كثير من الخطوط المثبّتة محلياً (خصوصاً الخطوط التجارية) العائلة الأساسية فيها 400 و700 بس،
   والأوزان 300/500/900 عائلات **منفصلة** ('… Light' · '… Med' · '… Black').
   فطلبُ 800 يعطي بولد مزيّفاً. نجمعها كلها بعائلة وحدة بـ@font-face + local(). */
const h = delayRender('font');
/* ⛔ Remotion ما يتأكد إن الخط تحمّل: لو الخط مو مثبّت (fontLocal) أو الرندر أوفلاين، الكابشن كله يطلع بخط النظام بلا أي تحذير.
   نقيس عرض نص بخطه مقابل monospace — لو تساووا فالخط غايب، ونطبع FONT_MISSING (04b/المستخدم يشوفه بسجل الرندر). */
const PROBE = 'نصّ تجريبي ABC';
const warnIfMissing = () => {
  try {
    const c = document.createElement('canvas').getContext('2d');
    if (!c) return;
    const probe = PROBE;
    c.font = `700 80px "${T.font}", monospace`; const a = c.measureText(probe).width;
    c.font = '700 80px monospace'; const b = c.measureText(probe).width;
    if (a === b) console.error('FONT_MISSING ' + T.font + ' — الخط مو متوفر، الكابشن بيطلع بخط النظام');
  } catch (e) { /* القياس اختياري */ }
};
const W: [number,string][] = [[300,'Light'],[400,'Regular'],[500,'Medium'],[700,'Bold'],[900,'Black']];
/* ويندوز (رندر 04b بس، REMOTION_FONT_STRICT): خط الكابشن ما تحمل = الرندر يوقف، بدل كابشن بخط بديل بصمت.
   نقيس النص بالخط وبدونه: نفس العرض = المتصفح ما لقاه. بدون المتغير (الماك والاستوديو) نكمل كما كان. */
const STRICT = !!((window as any).process?.env?.REMOTION_FONT_STRICT);
const done = (): void => {
  if (!STRICT) { continueRender(h); return; }
  const f = `700 80px "${T.font}"`, s = 'سلام 123';
  document.fonts.load(f, s).then(() => {
    const c = document.createElement('canvas').getContext('2d')!;
    c.font = `${f}, monospace`; const a = c.measureText(s).width;
    c.font = '700 80px monospace';
    if (a === c.measureText(s).width) throw new Error('fallback');
    continueRender(h);
  }).catch(() => cancelRender(new Error('⛔ الخط «' + T.font + '» ما تحمل: ' + (FONT_LOCAL
    ? 'ثبته على الجهاز او شيل fontLocal من theme.json' : 'تاكد من النت ومن اسمه في Google Fonts'))));
};
/* الخط يتحمّل عند أول استعمال بس: نطلب كل وزن صراحة قبل أول فريم وقبل القياس. بعد fonts.ready كل الأوزان كانت
   «unloaded» (مقاس على كروم بالماك)، ونسخة زياد لويندوز شافت أول فريم بكل تبويب ريموشن بخط بديل. */
const finish = () => Promise.all(W.map(([w]) => document.fonts.load(`${w} 40px "${T.font}"`, PROBE + ' 123'))).catch(() => null)
  .then(() => { warnIfMissing(); done(); });

if (FONT_LOCAL) {
  const base = T.font.replace(/\s+/g,'');                       // الاسم بلا مسافات
  const css = W.map(([w,n]) =>
    `@font-face{font-family:'${T.font}';font-style:normal;font-weight:${w};` +
    `src:local('${T.font} ${n}'),local('${base}-${n}');font-display:block;}`).join('\n');
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  document.fonts.ready.then(finish);
} else {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = 'https://fonts.googleapis.com/css2?family=' + encodeURIComponent(T.font) +
    ':wght@300;400;500;700;900&display=swap';
  link.onload  = () => document.fonts.ready.then(finish);
  link.onerror = () => finish();
  document.head.appendChild(link);
}
