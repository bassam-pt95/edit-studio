/* مسارات المهارة وبيانات المستخدم — نفس _paths.py بالضبط.
   SKILL: مجلد المهارة (قراءة فقط) · HOME: بيانات المستخدم (~/Documents/video-edit أو VEB_HOME) */
const path=require('path'), fs=require('fs'), os=require('os'), cp=require('child_process');
const SKILL=path.join(__dirname,'..');
/* مجلد البيانات الافتراضي: ماك/لينكس ~/Documents/video-edit كما كان. ويندوز: نفس المجلد لو مساره ASCII وخارج OneDrive، وإلا C:\EditStudio
   (نفس قاعدة _paths.py والاستوديو platform.mjs dataHomeDefault). VEB_HOME يغلب. الوسائط محقونة للاختبار. */
function defaultHome(o){
  o=o||{}; const env=o.env||process.env, platform=o.platform||process.platform, home=o.home||os.homedir();
  if(env.VEB_HOME) return env.VEB_HOME;
  if(platform!=='win32') return path.join(home,'Documents','video-edit');
  const plain=path.win32.join(home,'Documents','video-edit');
  const od=env.OneDrive||env.OneDriveConsumer||env.OneDriveCommercial;
  const exists=o.exists||(f=>{ try{ return fs.statSync(f).isDirectory(); }catch(e){ return false; } });
  const synced=!!od&&exists(path.win32.join(od,'Documents'));
  const risky=/[^\x20-\x7e]/.test(plain)||/onedrive/i.test(plain)||/[\\/]AppData[\\/]/i.test(plain);
  return (risky||synced)?path.win32.join(o.driveRoot||'C:\\','EditStudio'):plain;
}
const HOME=defaultHome();
function ensure(){ for(const d of ['','sounds','refs','tools']) fs.mkdirSync(path.join(HOME,d),{recursive:true}); return HOME; }
function data(...p){ return path.join(HOME,...p); }
/* أداة الرسم بالمتصفح: تُنزَّل مرة وحدة بمجلد بيانات المستخدم (tools/) لأن مجلد المهارة للقراءة فقط */
function puppeteer(){
  for(const p of [process.env.PUPPETEER_PATH,'puppeteer-core',path.join(HOME,'tools','node_modules','puppeteer-core')]){
    if(!p) continue; try{ return require(p); }catch(e){}
  }
  throw new Error('ما لقيت أداة الرسم (puppeteer-core، للمحرّك الخفيف بس — ريموشن ما يحتاجها). ثبّتها مرة وحدة: '+puppeteerHint());
}
/* متصفح كروم: المسار حسب الجهاز، ويتغيّر بـCHROME_PATH (أو CHROME).
   ويندوز: كروم ثم إيدج (موجود بكل ويندوز) ثم متصفح ريموشن الخفيف لو منزّل. ما لقى شي → خطأ عربي واضح. */
function chromeCandidates(platform,env,home){
  home=home||HOME;
  if(platform==='darwin') return ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  if(platform==='win32'){
    const pf=env['PROGRAMFILES']||'C:\\Program Files', pf86=env['PROGRAMFILES(X86)']||'C:\\Program Files (x86)', la=env.LOCALAPPDATA||'';
    const shell='node_modules/.remotion/chrome-headless-shell/win64/chrome-headless-shell-win64/chrome-headless-shell.exe';
    return [path.win32.join(pf,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(pf86,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(la,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(pf86,'Microsoft\\Edge\\Application\\msedge.exe'),
            path.win32.join(pf,'Microsoft\\Edge\\Application\\msedge.exe'),
            path.win32.join(la,'Microsoft\\Edge\\Application\\msedge.exe'),
            path.win32.join(home,'remotion-shared',shell)];
  }
  return ['/usr/bin/google-chrome','/usr/bin/chromium'];
}
function chrome(opts){
  const o=opts||{}, platform=o.platform||process.platform, env=o.env||process.env, exists=o.exists||(p=>{ try{ return fs.existsSync(p); }catch(e){ return false; } });
  const ov=env.CHROME_PATH||env.CHROME; if(ov) return ov;
  const c=chromeCandidates(platform,env,o.home);
  const hit=c.find(exists);
  if(hit) return hit;
  if(platform==='win32') throw new Error('ما لقيت متصفح (كروم أو إيدج) على الجهاز — ثبّت Google Chrome، أو حدّد مساره بـCHROME_PATH (مثال: set CHROME_PATH=C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe)');
  return c[0];
}
/* للسكربتات: نفس chrome() بس الخطأ يطلع رسالة عربية نظيفة ويخرج 2 بدل stack */
function chromeOrExit(){ try{ return chrome(); }catch(e){ console.error('⛔ '+e.message); process.exit(2); } }
/* سطر تثبيت أداة الرسم الخفيفة (puppeteer-core) بمجلد بيانات المستخدم — مو بمجلد المهارة (للقراءة فقط) */
function puppeteerHint(){ return 'npm i --no-audit --no-fund --prefix "'+data('tools').replace(/\\/g,'/')+'" puppeteer-core'; }
/* بايثون: VEB_PYTHON يغلب · ويندوز python (python3 هناك اختصار المتجر الفاضي) · غيره python3 */
function pythonName(platform,env){
  platform=platform||process.platform; env=env||process.env;
  return env.VEB_PYTHON||(platform==='win32'?'python':'python3');
}
/* بيئة بايثون: UTF-8 صريح — ويندوز بدونها يطبع cp1252 فيطيح أي print عربي أو ✅ */
function pyEnv(env){ return Object.assign({},env||process.env,{PYTHONUTF8:'1',PYTHONIOENCODING:'utf-8'}); }
/* اقتباس مسار لأمر shell: ويندوز (cmd) بعلامتي تنصيص عادية، غيره JSON (نفس السابق بالضبط) */
function quotePath(p,platform){ return (platform||process.platform)==='win32' ? '"'+String(p).replace(/"/g,'')+'"' : JSON.stringify(p); }
/* قاصّ الشخص وكاشف الوجه: بالماك مكتبة أبل (Vision) تُبنى مرة، وبغيره نسخة بايثون (mediapipe).
   يرجّع الأمر اللي ينادى بـ <in> <out> [quality] [feather] — أو null لو ما تجهّز. */
function personmask(binDir){
  if(process.platform==='darwin'){
    const BIN=path.join(binDir,'personmask');
    if(!fs.existsSync(BIN)){
      fs.mkdirSync(binDir,{recursive:true});
      // mac-only: Vision (swiftc) — بغير الماك نسخة بايثون تحت
      try{ cp.execSync('swiftc -O -o '+JSON.stringify(BIN)+' '+JSON.stringify(path.join(__dirname,'personmask.swift')),{stdio:'pipe'}); }
      catch(e){ return null; }
    }
    return JSON.stringify(BIN);
  }
  return pythonName()+' '+quotePath(path.join(__dirname,'personmask.py'));
}
/* يشغّل أمر personmask ويرجّع {ok,status,stdout,stderr} بدل ما يرمي — الحرّاس يقرّرون الرسالة.
   status 3 = ناقص mediapipe/opencv (personmask.py يخرج به) · opts.exec محقون للاختبار. */
function runPersonmask(PM,inDir,outDir,quality,feather,opts){
  const o=opts||{}, ex=o.exec||cp.execSync;
  const platform=o.platform||process.platform;
  const cmd=PM+' '+quotePath(inDir,platform)+' '+quotePath(outDir,platform)+' '+quality+' '+feather;
  try{ const out=ex(cmd,{stdio:'pipe',env:pyEnv(o.env)}); return {ok:true,status:0,stdout:String(out||''),stderr:'',cmd}; }
  catch(e){ return {ok:false,status:e.status,stdout:String(e.stdout||''),stderr:String(e.stderr||''),cmd,message:e.message}; }
}
/* رسالة فشل personmask مفهومة: 3 = ناقص mediapipe/opencv (تلميح التثبيت)، غيره = خطأ فعلي (stderr) */
function personmaskProblem(r,platform){
  platform=platform||process.platform;
  if(r.status===3){
    const pip=(platform==='win32'?'pip':'pip3')+' install "mediapipe<0.10.30" opencv-python numpy';
    return {kind:'missing',text:(r.stdout.trim()||'ناقص mediapipe أو opencv')+'\n   ثبّتها: '+pip+'   (mediapipe 0.10.21 يشتغل على Python 3.12)'};
  }
  return {kind:'error',text:'قاصّ الشخص/كاشف الوجه فشل: '+(r.stderr.trim()||r.message||('رمز الخروج '+r.status))};
}
/* JSON بلا BOM: PowerShell 5.1 (Set-Content -Encoding utf8) يكتب BOM فيرفضه JSON.parse */
function readJson(p){ return JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'')); }
/* اسم ملف/مجلد يصلح على ويندوز — نفس sanitize_name بـ_paths.py بالحرف */
function sanitizeName(name,fallback){
  const clean=x=>String(x==null?'':x).normalize('NFC').replace(/[\x00-\x1f\x7f<>:"\/\\|?*]/g,'-').replace(/^ +/,'').replace(/[ .]+$/,'');
  let s=clean(name)||clean(fallback===undefined?'out':fallback)||'out';
  if(/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i.test(s.split('.')[0].replace(/ +$/,''))) s='_'+s;
  return s;
}
/* إطار المقطع: theme.json ← "frame": "tall" (الافتراضي) · "wide" · "square" → [W, H] */
const FRAMES={tall:[1080,1920], wide:[1920,1080], square:[1080,1080]};
function frame(work){
  const p=path.join(work,'theme.json');
  if(!fs.existsSync(p)) return FRAMES.tall;
  try{ return FRAMES[readJson(p).frame]||FRAMES.tall; }
  catch(e){ console.error('⚠️ theme.json موجود وما انقرا ('+e.message+') — اعتبرت الإطار طولي. صلّحه أو اكتبه ببايثون بدل PowerShell.'); return FRAMES.tall; }
}
/* المحرّك الخفيف (compose.html + 04/08*) مبني على 1080×1920 بس: إطار عريض/مربع يُرسم ويُفحص غلط بصمت. نحذّر بدل الصمت. */
function warnIfNotTall(work){
  const f=frame(work);
  if(f[0]!==1080||f[1]!==1920) console.error('⚠️ إطار هذا المقطع '+f[0]+'×'+f[1]+' والمحرّك الخفيف للطولي (1080×1920) فقط — الرسم والفحص بيطلعون غلط. استعمل ريموشن (04b_remotion.sh).');
  return f;
}
module.exports={defaultHome,warnIfNotTall,SKILL,HOME,ensure,data,puppeteer,puppeteerHint,chrome,chromeOrExit,chromeCandidates,personmask,runPersonmask,personmaskProblem,pythonName,pyEnv,quotePath,readJson,sanitizeName,frame,FRAMES};
