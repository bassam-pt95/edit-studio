import{execFile as w}from"node:child_process";import{sendJson as f,readJson as b}from"./http.mjs";const S=Object.freeze(["start","stop","settings"]),k=Object.freeze(["dictation","dictée","diktat","dictado","dettatura","ditado","dicteren","dikter","إملاء","املاء","听写","聽寫","音声入力","받아쓰기","диктовк","dyktowan","הכתבה"]),g=Object.freeze(["stop","arrêter","terminer","beenden","stoppen","detener","finalizar","interrompi","termina","parar","إيقاف","ايقاف","إنهاء","انهاء","停止","結束","終了","중단","중지","остановить","zatrzymaj","durdur"]),I=176,v="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",x=/-1719|-25211|-1743|assistive access|not allowed to send keystrokes|not authorized to send apple events|accessibility/i,h=`
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
}`,T=`
function run(argv) {
  Application('System Events').keyCode(Number(argv[0]));
  return 'key';
}`;function N(t){return["-l","JavaScript","-e",h,JSON.stringify({mode:t==="stop"?"stop":"start",dict:k,stop:g})]}function P(){return["-l","JavaScript","-e",T,String(I)]}const E=`
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
`;function O(){return["-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-EncodedCommand",Buffer.from(E,"utf16le").toString("base64")]}function m(t){return x.test(String(t||""))?"permission":"failed"}function y(t,r,{timeout:n=8e3}={}){return new Promise(a=>{w(t,r,{timeout:n,encoding:"utf8",windowsHide:!0},(i,o,p)=>{a({code:i?typeof i.code=="number"?i.code:1:0,stdout:String(o||""),stderr:String(p||i&&i.message||"")})})})}function U({platform:t=process.platform,run:r=y,log:n=()=>{}}={}){let a=!1;const i=()=>t==="darwin"||t==="win32";async function o(e){if(e==="start"){const l=await r("/usr/bin/defaults",["read","com.apple.assistant.support","Dictation Enabled"]);if(l.code===0&&l.stdout.trim()==="0")return{ok:!1,reason:"off"}}const s=await r("/usr/bin/osascript",N(e));if(s.code!==0)return n("[dictation] menu script failed:",s.stderr.trim().slice(0,200)),{ok:!1,reason:m(s.stderr)};const u=s.stdout.trim();if(u==="clicked"||u==="already")return{ok:!0,how:"menu",...u==="already"?{already:!0}:{}};const c=await r("/usr/bin/osascript",P());return c.code!==0?(n("[dictation] key script failed:",c.stderr.trim().slice(0,200)),{ok:!1,reason:m(c.stderr)}):{ok:!0,how:"key"}}async function p(){const e=await r("powershell.exe",O());return e.code!==0?(n("[dictation] Win+H failed:",e.stderr.trim().slice(0,200)),{ok:!1,reason:"failed"}):{ok:!0,how:"key"}}async function d(e){if(!i())return{ok:!1,reason:"unsupported"};if(a)return{ok:!1,reason:"busy"};a=!0;try{return t==="darwin"?await o(e):await p()}catch(s){return n("[dictation]",s&&s.message),{ok:!1,reason:"failed"}}finally{a=!1}}return{available:i,start:()=>d("start"),stop:()=>d("stop"),async settings(){return t!=="darwin"?{ok:!1,reason:"unsupported"}:{ok:(await r("/usr/bin/open",[v])).code===0}}}}function L(t,r,{platform:n=process.platform,run:a=y,log:i=()=>{}}={}){const o=U({platform:n,run:a,log:i}),p=()=>({platform:n,available:o.available(),how:n==="darwin"?"menu":n==="win32"?"key":null});return t.get("/api/dictation",(d,e,s)=>{f(e,200,p())}),t.post("/api/dictation",async(d,e,s)=>{const u=await b(d,1024).catch(()=>null),c=u&&typeof u.action=="string"?u.action:"";if(!S.includes(c))return f(e,400,{error:"bad action"});const l=c==="settings"?await o.settings():c==="stop"?await o.stop():await o.start();f(e,200,l)}),{state:p}}export{S as ACTIONS,I as DICTATION_KEY_CODE,k as DICT_WORDS,T as KEY_SCRIPT,h as MENU_SCRIPT,v as SETTINGS_URL,g as STOP_WORDS,E as WIN_SCRIPT,m as classifyFailure,U as createDictation,L as dictationRoutes,P as keyArgs,N as menuArgs,y as runFile,O as winArgs};
