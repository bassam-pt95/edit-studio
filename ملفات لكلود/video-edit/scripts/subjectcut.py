# -*- coding: utf-8 -*-
"""قصّ «الموضوع» من صورة بغير الماك — نفس واجهة subjectcut.swift:

    python3 subjectcut.py <in> <out.png> [--keep]

  --keep : بمقاس الصورة الأصلي وبنفس المكان (طبقة تتحرك فوق صورتها)
  بدونه : PNG شفاف مقصوص على حدود الموضوع
يطبع «ok WxH instances=N» مثل نسخة Swift، ويخرج 3 لو ما لقى موضوعاً، 2 لو الاستعمال غلط، 4 لو rembg غير مثبّت.

يحتاج (اختياري، يُثبَّت يدوياً بموافقة المستخدم): pip install "rembg[cpu]" pillow
أول تشغيل ينزّل نموذج u2net (~170 ميقا) مرة وحدة. الماك: الأحسن subjectcut.swift (Vision، بلا تنزيل).
⛔ القص هنا من نموذج غير Vision: النتيجة تختلف شوي، راجع الصورة بعينك قبل ما تعتمدها (المرايا والزجاج بالذات).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _paths; _paths.utf8_guard()   # ويندوز بدون UTF-8: يعيد التشغيل بـ-X utf8 (ماك/لينكس: لا شي)


def crop_to_subject(img, threshold=8):
    """يقص صورة RGBA على حدود البكسلات اللي ألفاها فوق العتبة. يرجّع None لو ما فيه شي."""
    box = img.getchannel("A").point(lambda v: 255 if v > threshold else 0).getbbox()
    return img.crop(box) if box else None


def main(argv):
    if len(argv) < 3:
        print("usage: subjectcut.py <in> <out.png> [--keep]")
        return 2
    keep = "--keep" in argv
    try:
        from rembg import remove
        from PIL import Image
    except ImportError:
        print('⛔ rembg غير مثبّت — اختياري لقص الخلفية بغير الماك: pip install "rembg[cpu]" pillow '
              "(أول تشغيل ينزّل نموذجه ~170 ميقا)")
        return 4
    if not os.path.exists(os.path.expanduser(os.path.join("~", ".u2net", "u2net.onnx"))):
        print("ℹ️ أول مرة: rembg ينزّل نموذجه u2net (~170 ميقا) — مرة وحدة بس", file=sys.stderr)
    with Image.open(argv[1]) as im:
        res = remove(im.convert("RGBA"))
    out = res if keep else crop_to_subject(res)
    if out is None:
        print("no subject")
        return 3
    out.save(argv[2], "PNG")
    print(f"ok {out.width}x{out.height} instances=1")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
