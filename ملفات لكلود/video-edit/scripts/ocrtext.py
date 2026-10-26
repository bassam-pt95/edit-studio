#!/usr/bin/env python3
"""
ocrtext.py <صورة>  — بديل ocrtext.swift على ويندوز: يقرا النص بالصورة (عربي وانجليزي)
بمحرك ويندوز المدمج Windows.Media.Ocr عن طريق PowerShell، بلا تنزيل ولا pip.
يطبع نفس JSON حق ocrtext.swift: [{"t","c","x","y","w","h"}] لكل سطر، الاحداثيات 0..1
والاصل فوق-يسار. ويندوز ما يعطي ثقة، فـc دايم 1.0.
OCR_LANGS (افتراضي ar,en): اللغة الاولى اساس، والباقي يضيف السطور اللي ما تغطيها.
"""
import os, sys, re, json, base64, subprocess, tempfile
if os.name == 'nt' and not sys.flags.utf8_mode and (sys.flags.ignore_environment or not os.environ.get('PYTHONUTF8')):
    os.environ['PYTHONUTF8'] = '1'; import subprocess; sys.exit(subprocess.call([sys.executable, '-X', 'utf8', *sys.orig_argv[1:]]))

# يقرا OCR_IN ويكتب OCR_OUT (UTF-8، فالعربي ما يتلخبط بصفحة رموز الكونسول): {w,h,res:{lang:[[text,[[x,y,w,h,text],...]],...]},missing:[...]}
PS = r'''
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $null = $task.Wait(-1); $task.Result }
try {
  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($env:OCR_IN)) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $tr = New-Object Windows.Graphics.Imaging.BitmapTransform
  $max = [Windows.Media.Ocr.OcrEngine]::MaxImageDimension
  $big = [Math]::Max($dec.PixelWidth, $dec.PixelHeight)
  if ($big -gt $max) { $s = $max / $big; $tr.ScaledWidth = [uint32][Math]::Floor($dec.PixelWidth * $s); $tr.ScaledHeight = [uint32][Math]::Floor($dec.PixelHeight * $s) }
  $bmp = Await ($dec.GetSoftwareBitmapAsync([Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8, [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied, $tr,
    [Windows.Graphics.Imaging.ExifOrientationMode]::RespectExifOrientation, [Windows.Graphics.Imaging.ColorManagementMode]::DoNotColorManage)) ([Windows.Graphics.Imaging.SoftwareBitmap])
} catch { $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }; [IO.File]::WriteAllText($env:OCR_OUT, $e.Message, (New-Object Text.UTF8Encoding $false)); exit 3 }
$res = @{}; $missing = @()
foreach ($tag in ($env:OCR_LANGS -split ',')) {
  $eng = $null
  try { $lang = New-Object Windows.Globalization.Language $tag; if ([Windows.Media.Ocr.OcrEngine]::IsLanguageSupported($lang)) { $eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang) } } catch { }
  if ($eng -eq $null) { $missing += $tag; continue }
  $r = Await ($eng.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])
  $res[$tag] = @(foreach ($ln in $r.Lines) { ,@($ln.Text, @(foreach ($wd in $ln.Words) { $b = $wd.BoundingRect; ,@($b.X, $b.Y, $b.Width, $b.Height, $wd.Text) })) })
}
$json = ConvertTo-Json -Compress -Depth 8 @{ w = $bmp.PixelWidth; h = $bmp.PixelHeight; res = $res; missing = @($missing) }
[IO.File]::WriteAllText($env:OCR_OUT, $json, (New-Object Text.UTF8Encoding $false))
'''


def run_ps(img, langs):
    fd, outp = tempfile.mkstemp(suffix='.json'); os.close(fd)
    ps = os.path.join(os.environ.get('SystemRoot', r'C:\Windows'), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
    env = dict(os.environ, OCR_IN=img, OCR_OUT=outp, OCR_LANGS=','.join(langs))
    try:
        p = subprocess.run([ps, '-NoProfile', '-NonInteractive', '-EncodedCommand',
                            base64.b64encode(PS.encode('utf-16-le')).decode('ascii')],
                           env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
        if p.returncode not in (0, 3):
            sys.stderr.write(p.stderr); sys.exit(p.returncode)
        with open(outp, encoding='utf-8-sig') as f:   # رمز 3: الصورة ما انفتحت، والملف فيه السبب
            return (json.load(f), '') if p.returncode == 0 else (None, f.read().strip())
    finally:
        os.remove(outp)


def box(words):
    x0 = min(w[0] for w in words); y0 = min(w[1] for w in words)
    x1 = max(w[0] + w[2] for w in words); y1 = max(w[1] + w[3] for w in words)
    return x0, y0, x1 - x0, y1 - y0


def covered(a, b):                                  # كم من a داخل b
    ix = max(0, min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]))
    iy = max(0, min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1]))
    return ix * iy / (a[2] * a[3]) if a[2] * a[3] > 0 else 1


AR = re.compile('[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]')


def line_text(words):
    # ويندوز يرتب الكلمات من اليسار؛ السطر العربي يتقرا من اليمين، والكلام الانجليزي داخله يبقى من اليسار
    ws = sorted(words, key=lambda w: w[0])
    if not any(AR.search(w[4]) for w in ws):
        return ' '.join(w[4] for w in ws)
    out, run = [], []
    for w in reversed(ws):
        if AR.search(w[4]):
            out += run[::-1] + [w[4]]; run = []
        else:
            run.append(w[4])
    return ' '.join(out + run[::-1])


if len(sys.argv) < 2 or not os.path.isfile(sys.argv[1]):
    print('{"error":"no image"}'); sys.exit(1)
if os.name != 'nt':
    sys.stderr.write('ocrtext.py لويندوز فقط؛ بالماك: swift ocrtext.swift <صورة>\n'); sys.exit(2)
langs = [l.strip() for l in os.environ.get('OCR_LANGS', 'ar,en').split(',') if l.strip()]
d, err = run_ps(os.path.abspath(sys.argv[1]), langs)
if d is None:
    if err: sys.stderr.write(err + '\n')
    print('{"error":"no image"}'); sys.exit(1)
if langs[0] in d['missing']:
    sys.stderr.write('قراءة العربي بالصور مو مركبة بويندوز، فهالمرة قريت الانجليزي بس. تركيبها: الاعدادات ← الوقت واللغة'
                     ' ← اللغة والمنطقة ← العربية (او اضف لغة) ← خيارات اللغة ← التعرف على النص (Optical character recognition)\n')
W, H = d['w'], d['h']
kept = []                                           # [box, text]
for lang in langs:
    base = list(kept)
    for _, words in d['res'].get(lang) or []:
        if not words:
            continue
        b = box(words)
        if any(covered(b, k[0]) >= 0.3 for k in base):
            continue
        kept.append([b, line_text(words)])
kept.sort(key=lambda k: (k[0][1], k[0][0]))
out = [{"t": t, "c": 1.0, "x": round(b[0] / W, 5), "y": round(b[1] / H, 5),
        "w": round(b[2] / W, 5), "h": round(b[3] / H, 5)} for b, t in kept]
print(json.dumps(out, ensure_ascii=False))
