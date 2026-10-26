import{execFile as b}from"node:child_process";import{sendJson as f,readJson as S}from"./http.mjs";const k=Object.freeze(["start","stop","settings"]),g=Object.freeze(["dictation","dictée","diktat","dictado","dettatura","ditado","dicteren","dikter","إملاء","املاء","听写","聽寫","音声入力","받아쓰기","диктовк","dyktowan","הכתבה"]),I=Object.freeze(["stop","arrêter","terminer","beenden","stoppen","detener","finalizar","interrompi","termina","parar","إيقاف","ايقاف","إنهاء","انهاء","停止","結束","終了","중단","중지","остановить","zatrzymaj","durdur"]),v=176,x="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",h=/-1719|-25211|-1743|assistive access|not allowed to send keystrokes|not authorized to send apple events|accessibility/i,T=`
function run(argv) {
  var cfg = JSON.parse(argv[0]);
  var mode = cfg.mode === 'stop' ? 'stop' : 'start';
  var has = function (name, words) {
    var n = String(name || '').toLowerCase();
    for (var i = 0; i < words.length; i++) if (n.indexOf(words[i].toLowerCase()) >= 0) return true;
    return false;
  };
  var se = Application('System Events');
  var front = se.processes.whose({ frontmost: true });
  if (!front.length) return 'nomenu';
  var bars = front[0].menuBars;
  if (!bars.length) return 'nomenu';
  var tops = bars[0].menuBarItems();
  var sawStop = false;
  for (var t = 1; t < tops.length; t++) {
    var menus = tops[t].menus;
    if (!menus.length) continue;
    var menu = menus[0];
    var names = menu.menuItems.name();
    for (var k = 0; k < names.length; k++) {
      if (!has(names[k], cfg.dict)) continue;
      var stopItem = has(names[k], cfg.stop);
      if (stopItem) sawStop = true;
      if ((mode === 'stop') !== stopItem) continue;
      var item = menu.menuItems[k];
      if (!item.enabled()) continue;
      item.click();
      return 'clicked';
    }
  }
  return mode === 'start' && sawStop ? 'already' : mode === 'stop' ? 'nostop' : 'nomenu';
}`,N=`
function run(argv) {
  Application('System Events').keyCode(Number(argv[0]));
  return 'key';
}`;function P(n){return["-l","JavaScript","-e",T,JSON.stringify({mode:n==="stop"?"stop":"start",dict:g,stop:I})]}function E(){return["-l","JavaScript","-e",N,String(v)]}const O=`
$src = @'
using System;
using System.Runtime.InteropServices;
public static class StudioDictation {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public InputUnion u; }
  [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
  static INPUT Key(ushort vk, bool up) { INPUT i = new INPUT(); i.type = 1; i.u.ki.wVk = vk; i.u.ki.dwFlags = up ? 2u : 0u; return i; }
  public static int WinH() {
    INPUT[] a = new INPUT[] { Key(0x5B, false), Key(0x48, false), Key(0x48, true), Key(0x5B, true) };
    return (int)SendInput((uint)a.Length, a, Marshal.SizeOf(typeof(INPUT)));
  }
}
'@
Add-Type -TypeDefinition $src
if ([StudioDictation]::WinH() -ne 4) { exit 3 }
exit 0
`;function U(){return["-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-EncodedCommand",Buffer.from(O,"utf16le").toString("base64")]}function m(n){return h.test(String(n||""))?"permission":"failed"}function y(n,o,{timeout:i=8e3}={}){return new Promise(a=>{b(n,o,{timeout:i,encoding:"utf8",windowsHide:!0},(r,s,p)=>{a({code:r?typeof r.code=="number"?r.code:1:0,stdout:String(s||""),stderr:String(p||r&&r.message||"")})})})}function D({platform:n=process.platform,run:o=y,log:i=()=>{}}={}){let a=!1;const r=()=>n==="darwin"||n==="win32";async function s(t){if(t==="start"){const l=await o("/usr/bin/defaults",["read","com.apple.assistant.support","Dictation Enabled"]);if(l.code===0&&l.stdout.trim()==="0")return{ok:!1,reason:"off"}}const e=await o("/usr/bin/osascript",P(t));if(e.code!==0)return i("[dictation] menu script failed:",e.stderr.trim().slice(0,200)),{ok:!1,reason:m(e.stderr)};const u=e.stdout.trim();if(u==="clicked"||u==="already")return{ok:!0,how:"menu",...u==="already"?{already:!0}:{}};const c=await o("/usr/bin/osascript",E());return c.code!==0?(i("[dictation] key script failed:",c.stderr.trim().slice(0,200)),{ok:!1,reason:m(c.stderr)}):{ok:!0,how:"key"}}async function p(){const t=await o("powershell.exe",U());return t.code!==0?(i("[dictation] Win+H failed:",t.stderr.trim().slice(0,200)),{ok:!1,reason:"failed"}):{ok:!0,how:"key"}}async function d(t){if(!r())return{ok:!1,reason:"unsupported"};if(a)return{ok:!1,reason:"busy"};a=!0;try{return n==="darwin"?await s(t):await p()}catch(e){return i("[dictation]",e&&e.message),{ok:!1,reason:"failed"}}finally{a=!1}}return{available:r,start:()=>d("start"),stop:()=>d("stop"),async settings(){return n!=="darwin"?{ok:!1,reason:"unsupported"}:{ok:(await o("/usr/bin/open",[x])).code===0}}}}function C(n,o,{platform:i=process.platform,run:a=y,log:r=()=>{}}={}){const s=D({platform:i,run:a,log:r}),p=t=>!(t&&t.lan),d=()=>({platform:i,available:s.available(),how:i==="darwin"?"menu":i==="win32"?"key":null});return n.get("/api/dictation",(t,e,u)=>{if(!p(u))return f(e,403,{error:"local only"});f(e,200,d())}),n.post("/api/dictation",async(t,e,u)=>{if(!p(u))return t.resume(),f(e,403,{error:"local only"});const c=await S(t,1024).catch(()=>null),l=c&&typeof c.action=="string"?c.action:"";if(!k.includes(l))return f(e,400,{error:"bad action"});const w=l==="settings"?await s.settings():l==="stop"?await s.stop():await s.start();f(e,200,w)}),{state:d}}export{k as ACTIONS,v as DICTATION_KEY_CODE,g as DICT_WORDS,N as KEY_SCRIPT,T as MENU_SCRIPT,x as SETTINGS_URL,I as STOP_WORDS,O as WIN_SCRIPT,m as classifyFailure,D as createDictation,C as dictationRoutes,E as keyArgs,P as menuArgs,y as runFile,U as winArgs};
