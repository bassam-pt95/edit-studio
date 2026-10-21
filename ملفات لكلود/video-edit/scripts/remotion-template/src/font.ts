import {continueRender, delayRender} from 'remotion';
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
/* الخط يتحمّل عند أول استعمال بس — نطلبه صراحة قبل القياس عشان ما يطلع تحذير كاذب */
const finish = () => document.fonts.load(`700 80px "${T.font}"`, PROBE).catch(() => null)
  .then(() => { warnIfMissing(); continueRender(h); });
const W: [number,string][] = [[300,'Light'],[400,'Regular'],[500,'Medium'],[700,'Bold'],[900,'Black']];

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
