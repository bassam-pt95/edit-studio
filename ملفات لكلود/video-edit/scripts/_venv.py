# -*- coding: utf-8 -*-
"""ماك: سكربتات المونتاج تشتغل ببايثون المونتاج الخاص (<VEB_HOME>/tools/py، يبنيه 00_setup.sh --install بنسخ ثابتة).

قبل كانت numpy والتفريغ داخل بايثون Homebrew، واول brew upgrade لبايثون يخليها وراه ويوقف التفريغ (مراجعة 1.0.19، I2).
اي سكربت يحتاجها يستورد هالملف اول شي (`import _venv`): لو انشغل ببايثون ثاني (python3 حق الجهاز)، ينعاد تشغيله بنفس الاوامر
ببايثون المونتاج. ما فيه مجلد خاص او ما يشتغل (تثبيت قبل ما يتحدث، او بايثون اللي انبنى منه انشال)؟ يكمل بنفس البايثون.
  • ويندوز ما يحتاجه: python3 هناك اختصار يكتبه 00_setup.sh لبايثون المونتاج نفسه. لينكس ما تغير.
  • python3 -c "…" ما ينعاد (ما فيه ملف يتشغل من جديد).
  • VEB_VENV_EXEC علامة للتشغيل الثاني بس: تنشال اول ما يبدا، فالبرامج اللي يشغلها السكربت ما تورثها.
"""
import os, sys


def python(env=None, home=None):
    """بايثون المونتاج الخاص: <VEB_HOME>/tools/py/bin/python (مجلد البيانات الافتراضي نفس _paths.default_home على الماك)."""
    env = os.environ if env is None else env
    # mac-only: _again يشغله على الماك بس (ويندوز python3 فيه اختصار لبايثون المونتاج)
    veb = env.get('VEB_HOME') or os.path.join(home or os.path.expanduser('~'), 'Documents', 'video-edit')
    return os.path.join(veb, 'tools', 'py', 'bin', 'python')


def _again():
    if os.environ.pop('VEB_VENV_EXEC', None) or sys.platform != 'darwin':
        return
    script = sys.argv[0] if sys.argv else ''
    py = python()
    if not script or not os.path.isfile(script) or not os.path.exists(py):   # exists: رابط لبايثون انشال = ما يشتغل
        return
    if os.path.realpath(sys.prefix) == os.path.realpath(os.path.dirname(os.path.dirname(py))):
        return
    os.environ['VEB_VENV_EXEC'] = '1'
    try:
        os.execv(py, [py] + sys.argv)
    except OSError:
        os.environ.pop('VEB_VENV_EXEC', None)


_again()
