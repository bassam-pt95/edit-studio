# B Studio

مهارة مونتاج لكلود، مع استوديو تعدّل فيه مقطعك بيدك: الكابشن، الصور، الصوت، الألوان، وشكل الشاشة. وفيه «المساعد»: محادثة داخل الاستوديو بحساب Claude أو ChatGPT حقك (Codex)، تكتب له أو تحط ملاحظة بـM ويعدّل قدامك.

يشتغل على ماك بمعالج أبل (M1 وأحدث)، وعلى ويندوز من Git Bash.

## التركيب
افتح كلود على قسم Code، أو افتح Codex، واكتب له:

> ركّب B Studio من https://github.com/bassam-pt95/edit-studio

وهو يكمّل الباقي، ويقول لك لو احتاج منك شي. عندك نسخة قديمة؟ نفس الجملة: الجديدة تتركّب، والقديمة تروح لسلة المهملات، ومشاريعك ما تنلمس.

## التحديث
اكتب لكلود أو Codex: «حدّث الاستوديو». ينزّل آخر نسخة من هنا ويركّبها، ويقول لك وش الجديد. والدليل يتحدّث معها على سطح المكتب.

## اقتراح أو مشكلة
اكتبها في [Issues](https://github.com/bassam-pt95/edit-studio/issues). والدليل ينحط على سطح المكتب بعد التركيب.

## وش بالمستودع
- `ملفات لكلود/edit-studio`: مهارة الاستوديو.
- `ملفات لكلود/video-edit`: مهارة المونتاج.
- `ملفات لكلود/install.sh`: ملف التركيب.
- `دليل B Studio.pdf`: الدليل.

## الرخصة
[الرخصة](LICENSE.md) باختصار:
- الاستخدام مجاني لمقاطعك ومقاطع عملائك، وكل اللي تسويه فيه ملكك.
- الاستوديو مقفول: لا تعدّله، ولا تاخذ منه ميزة أو جزء من الكود، ولا تبني عليه، ولا تنشره.
- عندك اقتراح؟ اكتبه في Issues. ومبرمج وتبي تساعد؟ تواصل مع صاحب الاستوديو، والشغل بدعوة منه.

## English
**B Studio** is a video-editing skill for Claude with a small studio you run on your own machine: captions, pictures, sound, colour and framing on a timeline, plus an assistant inside the studio that edits with you through your own Claude or ChatGPT (Codex) account. The interface is Arabic or English. It runs on Apple-silicon Macs and on Windows from Git Bash.

- **Install:** open Claude on the Code tab, or open Codex, and write: *Install B Studio from https://github.com/bassam-pt95/edit-studio*. Claude does the rest.
- **Update:** write *Update the studio*. Your projects are not touched.
- **Ideas and problems:** [Issues](https://github.com/bassam-pt95/edit-studio/issues).
- **License:** proprietary, all rights reserved, see [LICENSE.md](LICENSE.md). Free to use for your own and your clients' videos. You may not modify the studio, take any part of its code, build on it or republish it.

---
**إلى كلود (لما يطلب المستخدم التركيب من هذا الرابط):** نزّل المستودع وشغّل ملف التركيب، ثم اتبع آخر سطر يطبعه:

```bash
T="$(mktemp -d)" && curl -fsSL https://github.com/bassam-pt95/edit-studio/archive/refs/heads/main.tar.gz | tar -xz -C "$T" && bash "$T"/*/"ملفات لكلود/install.sh"
```

ما يحتاج تسجيل دخول ولا مفاتيح. لا تعدّل شي في النسخة المركّبة، ولا ترفع منها شي لإعدادات كلود.
