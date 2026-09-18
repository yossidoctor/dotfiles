// menubar-hide.c — suppress the native macOS menu bar completely.
//
// macOS offers no setting for this: "Automatically hide and show the menu bar"
// always keeps the hover reveal, which is the behavior being removed here.
//
// SLSSetMenuBarInsetAndAlpha at alpha 0.0 is a special case rather than merely a
// transparent bar — at exactly 0.0 the menu bar stops accepting mouse events, so
// the reveal never triggers and clicks fall through to what is behind it. That
// behavior is documented in yabai's man page for its menubar_opacity config,
// which is the same call.
//
// SIP can stay ENABLED. This is a plain SkyLight call on an ordinary connection,
// not a Dock.app injection: yabai reaches it without its scripting addition,
// unlike the space/shadow/layer features that do require SIP off.
//
// macOS resets the alpha on space changes, display changes and Mission Control
// exit, so a one-shot call does not persist — menubar-watch.sh re-applies it on
// those events. Build via `make` in this directory; the makefile is the SoT for
// the compile line.
//
// Usage: menubar-hide [0.0 .. 1.0]   (no argument means 0.0; 1.0 restores)

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

// Private SkyLight symbols; there is no public header for any of these.
extern int SLSMainConnectionID(void);
extern int SLSSetMenuBarInsetAndAlpha(int cid, double u1, double u2, float alpha);

int main(int argc, char **argv) {
  float alpha = 0.0f;
  if (argc > 1) {
    alpha = strtof(argv[1], NULL);
    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;
  }

  int cid = SLSMainConnectionID();
  int err = SLSSetMenuBarInsetAndAlpha(cid, 0, 1, alpha);
  if (err != 0) {
    fprintf(stderr, "SLSSetMenuBarInsetAndAlpha failed: %d\n", err);
    return 1;
  }
  return 0;
}
