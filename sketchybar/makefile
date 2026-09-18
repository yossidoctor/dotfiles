# Builds the two small C helpers the bar shells out to:
#   menubar-hide  — suppresses the native menu bar (see menubar-hide.c for why
#                   the call works with SIP enabled)
#   pointer-y     — where the pointer is, used to decide whether the media popup
#                   is still being hovered
#
# Both are built into the config directory and are gitignored: they are
# machine-local, and the .c files are the tracked sources. sketchybarrc runs
# `make` itself when a binary is missing or older than its source.

BINS := menubar-hide pointer-y

all: $(BINS)

# SkyLight is a private framework and carries SLSSetMenuBarInsetAndAlpha;
# CoreGraphics does not export it, so linking against CoreGraphics alone fails
# at link time. It is reached by adding PrivateFrameworks to the framework
# search path rather than by naming a dylib inside it — the binary lives in the
# dyld shared cache and the on-disk Versions/A path does not exist.
PRIVATE := /System/Library/PrivateFrameworks

menubar-hide: menubar-hide.c
	cc -O2 -Wall -o $@ $< -F$(PRIVATE) -framework SkyLight

pointer-y: pointer-y.c
	cc -O2 -Wall -o $@ $< -framework ApplicationServices

clean:
	rm -f $(BINS)

.PHONY: all clean
