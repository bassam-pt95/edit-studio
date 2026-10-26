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
/* رسالة وحدة لكل سكربتات المحرك الخفيف: سطر التثبيت الصحيح بمساره (00_setup.sh ما ينزلها، وnpm بلا prefix ينزلها بمجلد المهارة) */
const PUP_HINT='ما لقيت اداة الرسم (puppeteer-core) — نزلها مرة وحدة بعد موافقة المستخدم: npm i --no-audit --no-fund --prefix "'+path.join(HOME,'tools')+'" puppeteer-core';
function puppeteer(){
  for(const p of [process.env.PUPPETEER_PATH,'puppeteer-core',path.join(HOME,'tools','node_modules','puppeteer-core')]){
    if(!p) continue; try{ return require(p); }catch(e){}
  }
  throw new Error(PUP_HINT);
}
/* ويندوز: Edge اللي يشغله node فيه طبقة توافق (__COMPAT_LAYER، اداة Bash بتطبيق كلود تحط DetectorsAppHealth) يطلع على طول برمز 0 وpuppeteer يطيح.
   كروم ما يتاثر. فنعيد تشغيل نفس السكربت مرة وحدة بلاها — كل السكربتات تنادي chrome() قبل اي شغل */
function edgeOk(p){
  if(process.platform==='win32'&&process.env.__COMPAT_LAYER&&require.main&&/msedge\.exe$/i.test(p)){
    const env={...process.env}; delete env.__COMPAT_LAYER;
    const r=cp.spawnSync(process.execPath,[...process.execArgv,...process.argv.slice(1)],{stdio:'inherit',env});
    process.exit(r.status===null?1:r.status);
  }
  return p;
}
/* متصفح كروم: المسار حسب الجهاز، ويتغيّر بـCHROME_PATH */
function chrome(){
  if(process.env.CHROME_PATH) return edgeOk(process.env.CHROME_PATH);
  if(process.platform!=='win32'&&process.env.CHROME) return process.env.CHROME;   /* الماك ولينكس (مثل الحالي): CHROME كمان يغيّره بعد CHROME_PATH */
  const c=process.platform==='darwin'
    ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome']
    : process.platform==='win32'
      /* ويندوز: CHROME (متغير الاستوديو) ثم كروم، ثم Edge (موجود بكل ويندوز)، ثم متصفح ريموشن (chrome-headless-shell) لو نزل محركه */
      ? [process.env.CHROME||'',
         path.join(process.env['PROGRAMFILES']||'C:\\Program Files','Google\\Chrome\\Application\\chrome.exe'),
         path.join(process.env['PROGRAMFILES(X86)']||'C:\\Program Files (x86)','Google\\Chrome\\Application\\chrome.exe'),
         path.join(process.env.LOCALAPPDATA||'','Google\\Chrome\\Application\\chrome.exe'),
         path.join(process.env['PROGRAMFILES(X86)']||'C:\\Program Files (x86)','Microsoft\\Edge\\Application\\msedge.exe'),
         path.join(process.env['PROGRAMFILES']||'C:\\Program Files','Microsoft\\Edge\\Application\\msedge.exe'),
         path.join(HOME,'remotion-shared','node_modules','.remotion','chrome-headless-shell','win64','chrome-headless-shell-win64','chrome-headless-shell.exe')]
      : ['/usr/bin/google-chrome','/usr/bin/chromium'];
  const hit=c.find(p=>{ try{ return fs.existsSync(p); }catch(e){ return false; } });
  /* ويندوز: بلا متصفح نوقف بسبب واضح، مو بمسار ناقص يطيح فيه puppeteer بـENOENT */
  if(!hit&&process.platform==='win32') throw new Error('ما لقيت Chrome ولا Edge — ثبت Google Chrome او حدد CHROME_PATH');
  return edgeOk(hit||c[0]);
}
/* نفس قائمة chrome() فوق بوسائط محقونة (للاختبار والتشخيص) — chrome() نفسه ما يناديها */
function chromeCandidates(platform,env,home){
  home=home||HOME;
  if(platform==='darwin') return ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  if(platform==='win32'){
    const pf=env['PROGRAMFILES']||'C:\\Program Files', pf86=env['PROGRAMFILES(X86)']||'C:\\Program Files (x86)', la=env.LOCALAPPDATA||'';
    const shell='node_modules/.remotion/chrome-headless-shell/win64/chrome-headless-shell-win64/chrome-headless-shell.exe';
    return [env.CHROME||'',
            path.win32.join(pf,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(pf86,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(la,'Google\\Chrome\\Application\\chrome.exe'),
            path.win32.join(pf86,'Microsoft\\Edge\\Application\\msedge.exe'),
            path.win32.join(pf,'Microsoft\\Edge\\Application\\msedge.exe'),
            path.win32.join(home,'remotion-shared',shell)];
  }
  return ['/usr/bin/google-chrome','/usr/bin/chromium'];
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
let pmProbe=null;   /* ويندوز: نتيجة تجربة بايثون الكاشف، مرة وحدة لكل تشغيل */
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
  if(process.platform==='win32'){
    /* ويندوز: بايثون venv ادوات المونتاج (00_setup.sh) بمساره، مو python اللي في PATH. ونجربه: بلا numpy او cv2 او الكاشف نرجع null فالفحص يتخطى بهدوء.
       نحمل الكاشف نفسه (FaceDetection) مثل 00_setup.sh، مو بس الاستيراد: mediapipe بمسار فيه حروف غير انجليزية يستورد وما يلقى ملفات الكاشف (يطلع 5)،
       وهذا ما يحله التنزيل فنقول وش الحل — على stderr لان 03_cut_zoom.py يقرا الامر من stdout */
    const venv=path.join(HOME,'tools','py','Scripts','python.exe');
    const py=process.env.MOHRER_FACE_PYTHON||(fs.existsSync(venv)?venv:'python');
    if(pmProbe===null){
      /* التجربة تاخذ قرابة ثانية لكل اداة تنادينا، فلما تنجح نحفظها بـtools/face-probe.json باسم البايثون ووقت ملفه:
         venv جديد (00_setup.sh) يتجرب من جديد، والفشل ما ينحفظ */
      const stampF=path.join(HOME,'tools','face-probe.json');
      let key=null; try{ key=py+'|'+Math.round(fs.statSync(py).mtimeMs); }catch(e){}
      try{ if(key&&readJSON(stampF).ok===key) pmProbe=true; }catch(e){}
      if(pmProbe===null) try{ cp.execFileSync(py,['-c','import numpy,cv2,mediapipe as m\ntry: m.solutions.face_detection.FaceDetection(model_selection=1).close()\nexcept Exception: raise SystemExit(1 if m.__file__.isascii() else 5)'],{stdio:'ignore',windowsHide:true,env:{...process.env,PYTHONUTF8:'1'}}); pmProbe=true;
        if(key) try{ fs.writeFileSync(stampF,JSON.stringify({ok:key})); }catch(e){} }
      catch(e){ pmProbe=false; if(e.status===5) console.error('⚠️ كاشف الوجه ما يشتغل: بايثون او مجلد البيانات بمسار فيه حروف غير انجليزية، حط VEB_HOME بمسار انجليزي (التنزيل ما يحله)'); }
    }
    if(!pmProbe) return null;
    return JSON.stringify(py)+' -X utf8 '+JSON.stringify(path.join(__dirname,'personmask.py'));
  }
  return 'python3 '+JSON.stringify(path.join(__dirname,'personmask.py'));
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
/* ويندوز: قناع الشخص بنموذج MODNet (matte.py)، حواف الشعر احسن من mediapipe. اول venv القص (onnxruntime-directml: كرت الشاشة)،
   وبعده venv ادوات المونتاج (onnxruntime للمعالج، جاي مع faster-whisper). يرجع الامر اللي ينادى بـ <in> <out> [feather]،
   او null: بلا النموذج (00_setup.sh --install --cutout) او VEB_MATTE=0. الماك ما يناديه: Vision .accurate يبقى */
let mtProbe;   /* نتيجة التجربة مرة وحدة لكل تشغيل */
function matte(){
  if(process.platform!=='win32'||process.env.VEB_MATTE==='0') return null;
  if(mtProbe===undefined){
    mtProbe=null;
    if(fs.existsSync(path.join(HOME,'tools','models','modnet.onnx'))) for(const v of ['cutout','py']){
      const py=path.join(HOME,'tools',v,'Scripts','python.exe');
      if(!fs.existsSync(py)) continue;
      try{ cp.execFileSync(py,['-c','import numpy,cv2,onnxruntime'],{stdio:'ignore',windowsHide:true}); }catch(e){ continue; }
      mtProbe=JSON.stringify(py)+' -X utf8 '+JSON.stringify(path.join(__dirname,'matte.py')); break;
    }
  }
  return mtProbe;
}
/* قراءة JSON تتحمل BOM: PowerShell 5.1 يكتب UTF-8 ببداية EF BB BF (Set-Content · Out-File)، و> فيه يكتب UTF-16 — وJSON.parse يرفض الاثنين */
function readJSON(p){
  const b=fs.readFileSync(p);
  let s=b[0]===0xFF&&b[1]===0xFE ? b.toString('utf16le') : b.toString('utf8');
  if(s.charCodeAt(0)===0xFEFF) s=s.slice(1);
  return JSON.parse(s);
}
/* اسمنا لـreadJSON فوق (سكربتاتنا تناديه): نفس القراءة اللي تتحمل BOM وUTF-16 */
function readJson(p){ return readJSON(p); }
/* اسم ملف/مجلد يصلح على ويندوز — نفس sanitize_name بـ_paths.py بالحرف */
function sanitizeName(name,fallback){
  const clean=x=>String(x==null?'':x).normalize('NFC').replace(/[\x00-\x1f\x7f<>:"\/\\|?*]/g,'-').replace(/^ +/,'').replace(/[ .]+$/,'');
  let s=clean(name)||clean(fallback===undefined?'out':fallback)||'out';
  if(/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i.test(s.split('.')[0].replace(/ +$/,''))) s='_'+s;
  return s;
}
/* إطار المقطع: theme.json ← "frame": "tall" (الافتراضي) · "wide" · "square" → [W, H] */
const FRAMES={tall:[1080,1920], wide:[1920,1080], square:[1080,1080]};
/* ما فيه theme.json: طولي بصمت. موجود وما انقرا (مثل مسار ويندوز بشرطة خلفية وحدة): طولي، وتحذير مرة وحدة على stderr مو stdout */
let frameWarned=false;
function frame(work){
  try{ const t=readJSON(path.join(work,'theme.json')); return FRAMES[t.frame]||FRAMES.tall; }
  catch(e){
    if(e.code!=='ENOENT'&&e.code!=='ENOTDIR'&&!frameWarned){ frameWarned=true; console.error('⚠️ theme.json ما انقرا ('+e.message+') — اعتبرته طولي'); }
    return FRAMES.tall;
  }
}
/* المحرّك الخفيف (compose.html + 04/08*) مبني على 1080×1920 بس: إطار عريض/مربع يُرسم ويُفحص غلط بصمت. نحذّر بدل الصمت. */
function warnIfNotTall(work){
  const f=frame(work);
  if(f[0]!==1080||f[1]!==1920) console.error('⚠️ إطار هذا المقطع '+f[0]+'×'+f[1]+' والمحرّك الخفيف للطولي (1080×1920) فقط — الرسم والفحص بيطلعون غلط. استعمل ريموشن (04b_remotion.sh).');
  return f;
}
module.exports={defaultHome,warnIfNotTall,SKILL,HOME,ensure,data,puppeteer,PUP_HINT,puppeteerHint,chrome,chromeOrExit,chromeCandidates,personmask,runPersonmask,personmaskProblem,matte,pythonName,pyEnv,quotePath,readJSON,readJson,sanitizeName,frame,FRAMES};
