# Acting on the live Mac

The user is working on this Mac while a session runs, so anything that changes the screen or where input goes lands in the middle of their work: a keystroke typed into the window they are writing in, focus pulled away mid-sentence, a window or tab closed under them.

That covers every keystroke or click sent through `hs -c` or `osascript`; every `aerospace` command beyond the read-only ones (`list-*`, `config`, `--version`); opening, focusing, moving, resizing or closing an app, window or tab; and every `test-harness.sh start`.

Each such action waits for the user's explicit yes, given in this conversation after a brief: what will happen on screen, how many seconds it takes, that they should stay off the Mac until it ends, and what the screen looks like after. A request to test, reproduce or "do it yourself" is the task, and the yes comes after the brief. A yes covers the one run it was given for; a follow-up probe or a retry is a new run with its own brief and its own yes.

The end screen in the brief is what the user gets back, on every path out of the run: a run that stops early closes the tabs and windows it opened and undoes the layout it changed before the banner, as part of the same yes, and a change it cannot undo is named in the report.

Recorded runs go through `test-harness.sh`; its header is the SoT for the mechanics.

Skip: reading config, logs and AeroSpace state (`aerospace list-windows`, `hs -c` that only returns values), and stills with `screencapture -x`, which change nothing on screen.
