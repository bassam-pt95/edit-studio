---
name: studio-chat
description: How a Claude chat edits the user's video through B Studio (once called «استوديو المونتاج» or Edit Studio): every change goes through the studio's own tools (project_summary first, then apply, draw, redraw, edit_graphic, openings, behind-the-person), lands live on the open timeline as one undo step, and the chat never writes project files or bakes the user's face into a graphic. Use when the user asks to edit, caption, cut, add a graphic, picture, sound, opening or move to the clip open in the studio, or says "افتح الاستوديو" / "عدّل في الاستوديو".
---

# Editing a clip through the studio from a chat

The studio is the editor the user has open in the browser. This plugin gives the chat the studio's own tools (the MCP
server `studio`), the same ones the assistant inside the editor uses. Every change lands live on the open timeline as ONE
undo step named «تعديل من المحادثة» (the user can press Cmd/Ctrl+Z), and his own edits made meanwhile are kept.

## Start

1. Call `project_summary`. It says which clip you work on, what is in it and what is wrong with it. If the studio is not
   running, say so and ask the user to open it; do not look for the project files.
2. `playhead` says where the user is and what he picked. `overview` and `get` read the timeline, `find_words` finds a
   word, `pauses` lists silences, `strip` and `frame` show a still or a row of stills: look (Read the image) before you
   change anything you cannot judge from numbers.
3. Several clips? `use_project` switches; the chat keeps to one clip until it is told otherwise.

## Change things

- **apply**: the editor's operations in order (see `operations` for the list and the arguments). Give `check_at` for
  anything visible and look at the picture it returns before you answer. Times in frames where an operation says so.
- **draw**: a simple graphic you write yourself (a chart, a counter, a title, an arrow, a list): plain JavaScript,
  transparent canvas over his video, one idea, a few seconds. `redraw` draws it again after a note; `edit_graphic`
  changes a graphic that is already there; `graphic` (with an item id) says how a picture or graphic was made, so
  whether its inside can be changed.
- **Openings and moves on his footage** are operations of `apply`: `addOpening {at, strength?}` (say soft, medium or
  strong; name one only if he does; it picks an unused one), `swapOpening`, `setOpeningStrength`, `addMoveKey`,
  `setMoveKey`, `removeMoveKey`, `addMoveFx`. They are drawn live after his colour grade.
- **Behind the person**: `setBehind {ids, on}` puts a picture, a drawn graphic or a title between the room and him (the
  studio cuts him out with its own matte; on a machine without it the item shows in front, and says so). Or draw with
  `behind: true`.
- **Voice-only clips**: when `project_summary` says VOICE-ONLY, the clip was made from a recording with no picture: no
  face and no footage of him. Openings and moves, behind the person, punch-in and windows, the colour grade and the
  baked-face check do not apply (the operations are refused). Scenes take the full frame over the paper background, and
  every moment needs one: `preflight` warns when more than 1.5 s shows only the background.
- **Captions he did not say**: whisper sometimes squeezes in words from the sentence before (a frame each) or writes its
  stock phrase («اشتركوا في القناة») over his words. Fix the caption, never the video: `setSentenceWords {id, words}`
  writes a sentence again word by word in source seconds (time the words on his voice; keep a word's `id` where the
  word stays), `setWordText` changes one word, `removeWords` takes words off the caption only. `cutWords` cuts the video
  under words: only for words he really said and wants gone.
- **Pictures and sounds**: `add_media` brings a picture or a sound in, `find_sounds` looks for sounds on this machine, and
  `sound_places` checks that each placed sound hits where something happens in the picture.
- **Plan and notes**: `plan_get`, `plan_set_section` (give the card's `rev` from `plan_get`: a card he changed since is refused, read it again), `plan_propose` (a change he approves on the card), `plan_working`, `plan_inspire`, `plan_mark_built` (with `note`) keep the plan; `notes`, `note`, `resolve_note`
  answer the notes the user left on the timeline.

## Never

- Never write `project.json` or `plan.json` yourself (no Write, Edit, `cp`, `sed -i`, a script). The plugin's guard hook
  blocks it, and a write from outside lands with no undo step and can overwrite what the user did in the open editor.
- Never make a second project for a clip that already has one.
- Never bake his face or his colour into a graphic or a block: scenes are transparent layers over his video, and his
  colour stays live. A block with his face rendered into it is refused (`baked_faces` lists the ones already there:
  rebuild them with the moves above).
- Never claim a change is done before you looked at the result (`check_at`, `frame`).
