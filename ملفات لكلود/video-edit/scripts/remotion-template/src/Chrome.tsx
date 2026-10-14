import {staticFile, Img} from 'remotion';
import {T, VEND, HAS_LOGO, VH, WIDE, BG_STYLE} from './theme';
import {p, rgba, mix, lum} from './util';

/* ═══ الخلفية — لونه هو، وعليها ملمس خفيف يخليها أفخم من لون سادة.
   theme.json ← bgStyle: grain حبيبات (الافتراضي) · lines شبكة خطوط · dots شبكة نقاط · both حبيبات مع شبكة.
   ⛔ ولا لون من عندنا: التدرّج من لون خلفيته، والخطوط والنقاط من لون نصّه.
   ⛔ الأرقام هنا نفسها اللي يبني بها الاستوديو الخلفية لما يفتح المقطع (tools/fw/core.mjs plainBackground):
      غيّر رقماً هنا = غيّره هناك، وإلا طلع الرندر غير اللي يشوفه بالاستوديو. */
const DARK = lum(T.bg) < 0.22;
const GRAIN = "data:image/svg+xml;utf8," + encodeURIComponent(
  `<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'>
     <filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/>
       <feColorMatrix type='matrix' values='0 0 0 0 ${DARK ? 1 : 0}  0 0 0 0 ${DARK ? 1 : 0}  0 0 0 0 ${DARK ? 1 : 0}  1.1 0 0 0 -0.42'/></filter>
     <rect width='180' height='180' filter='url(#n)'/></svg>`);
const fill: React.CSSProperties = {position:'absolute', inset:0};

export const LiveBG: React.FC<{t:number}> = ({t}) => {
  if (BG_STYLE === 'live') return <MovingBG t={t}/>;
  const base = `linear-gradient(180deg,${mix(T.bg,'#FFFFFF',DARK ? 0.045 : 0.35)} 0%,${T.bg} 50%,${mix(T.bg,'#000000',DARK ? 0.22 : 0.07)} 100%)`;
  const la = rgba(T.ink, DARK ? 0.085 : 0.075), da = rgba(T.ink, DARK ? 0.16 : 0.17);
  const grain = BG_STYLE === 'grain' || BG_STYLE === 'both';
  const lines = BG_STYLE === 'lines' || BG_STYLE === 'both';
  return (
    <div style={{...fill, overflow:'hidden', background:base}}>
      {lines && <div style={{...fill, background:
        `linear-gradient(${la} 2px,transparent 2px) 0 0/90px 90px,linear-gradient(90deg,${la} 2px,transparent 2px) 0 0/90px 90px`}}/>}
      {BG_STYLE === 'dots' && <div style={{...fill, background:`radial-gradient(${da} 2.6px,transparent 3.2px) 0 0/60px 60px`}}/>}
      {grain && <div style={{...fill, opacity:DARK ? 0.34 : 0.30, backgroundImage:`url("${GRAIN}")`, backgroundRepeat:'repeat'}}/>}
    </div>);
};

/* الخلفية المتحركة القديمة (bgStyle: "live"): تدرّج بارد + ثلاثة توهّجات تنجرف ببطء + حبيبات. */
const MovingBG: React.FC<{t:number}> = ({t}) => {
  const b1 = 0.5 + 0.5*Math.sin(t*0.62), b2 = 0.5 + 0.5*Math.sin(t*0.44 + 2);
  const dx = Math.sin(t*0.23)*70, dy = Math.cos(t*0.19)*54;
  const glow = (cx:number, cy:number, r:number, col:string, a:number) => ({
    position:'absolute' as const, left:cx-r, top:cy-r, width:r*2, height:r*2,
    background:`radial-gradient(circle, ${rgba(col,a)} 0%, ${rgba(col,a*0.28)} 60%, rgba(0,0,0,0) 100%)`});
  return (
    <div style={{position:'absolute', inset:0, overflow:'hidden',
      background:`linear-gradient(180deg,${mix(T.bg,T.sky,0.10)} 0%,${T.bg} 52%,${mix(T.bg,'#000000',0.14)} 100%)`}}>
      <div style={glow(400+dx*0.6, 430+dy*0.6, 560, T.sky, 0.13+0.07*b1)}/>
      <div style={glow(700-dx*0.6, 1330-dy*0.6, 500, mix(T.sky,'#000000',0.30), 0.09+0.06*b2)}/>
      <div style={glow(560, 980, 460, T.acc, 0.030)}/>
      <div style={{position:'absolute', inset:0, opacity:DARK ? 0.34 : 0.30,
        backgroundImage:`url("${GRAIN}")`, backgroundRepeat:'repeat'}}/>
    </div>);
};

/* ═══ الشارة — تحت يسار، نصّ لاتيني بظلّ غامق، بلا لوح.
   ⛔ كانت كبسولة أعلى الوسط: تأكل الحيّز فوق رأسه وتصادم عناوين الرسومات.
   فمكانها تحت يسار — وبلا شريط تقدّم (يزاحم ويشتّت). */
const HANDLE_Y = WIDE ? VH - 96 : 1546;
export const Badge: React.FC<{t:number}> = ({t}) => {
  const a = p(t,0.25,0.7) * (t > VEND-0.3 ? 1-p(t,VEND-0.3,VEND) : 1);
  if (a <= 0 || !T.handle) return null;
  return (
    <div style={{position:'absolute', left:52, top:HANDLE_Y, opacity:a*0.92,
      display:'flex', alignItems:'center', gap:12}}>
      {HAS_LOGO && <Img src={staticFile('logo.png')} style={{width:34, height:34, opacity:0.7}} />}
      <span dir="ltr" style={{fontFamily:'"Helvetica Neue", Helvetica, Arial, sans-serif',
        fontWeight:600, fontSize:28, color:rgba(T.ink,0.62),
        textShadow:`0 2px 14px ${rgba(T.bg,0.85)}, 0 0 6px ${rgba(T.bg,0.9)}`}}>{T.handle}</span>
    </div>);
};

export const Card: React.FC<React.PropsWithChildren<{style?:React.CSSProperties; radius?:number}>> =
  ({children, style, radius=20}) => (
  <div style={{background:rgba(T.bg,0.96), border:`2.5px solid ${rgba(T.ink,0.09)}`,
    boxShadow:`0 20px 48px ${rgba(T.ink,0.30)}`, borderRadius:radius, ...style}}>{children}</div>
);
