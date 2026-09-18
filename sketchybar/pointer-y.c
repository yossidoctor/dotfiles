// pointer-y.c — print the pointer's distance in points from the top of the
// screen it is on.
//
// The media popup cannot be dismissed from mouse.exited alone: that event also
// fires on small movements inside a row, and on the BOTTOM row there is no
// subsequent mouse.entered to cancel a deferred close, so the menu shuts while
// the pointer is still sitting on it. Asking where the pointer actually is
// settles that directly instead of guessing from event order.
//
// Printed value is 0 at the top edge and grows downward, matching how the bar's
// own height and the popup's extent are reasoned about.
//
// A compiled helper rather than a Swift one-liner because this runs on every
// mouse.exited in the bar; see the makefile, which is the SoT for the build.

#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>

int main(void) {
  CGEventRef ev = CGEventCreate(NULL);
  if (!ev) {
    fprintf(stderr, "CGEventCreate failed\n");
    return 1;
  }
  CGPoint p = CGEventGetLocation(ev);
  CFRelease(ev);

  // CGEventGetLocation is already top-left origin, so the y value needs no flip.
  printf("%d\n", (int)p.y);
  return 0;
}
