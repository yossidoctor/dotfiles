# Builds the small C helpers the bar shells out to:
#   pointer-y    — where the pointer is, used to decide whether the media popup
#                  is still being hovered
#   volume-level — the output device's volume, and whether it has one at all
#
# Built into the config directory and gitignored: machine-local, with the .c as
# the tracked source. sketchybarrc runs `make` itself when it is missing or
# older than that source.

BINS := pointer-y volume-level

all: $(BINS)

pointer-y: pointer-y.c
	cc -O2 -Wall -o $@ $< -framework ApplicationServices

volume-level: volume-level.c
	cc -O2 -Wall -o $@ $< -framework CoreAudio -framework AudioToolbox

clean:
	rm -f $(BINS)

.PHONY: all clean
