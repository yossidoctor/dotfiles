# Builds the small C helper the bar shells out to:
#   pointer-y — where the pointer is, used to decide whether the media popup is
#               still being hovered
#
# Built into the config directory and gitignored: machine-local, with the .c as
# the tracked source. sketchybarrc runs `make` itself when it is missing or
# older than that source.

BINS := pointer-y

all: $(BINS)

pointer-y: pointer-y.c
	cc -O2 -Wall -o $@ $< -framework ApplicationServices

clean:
	rm -f $(BINS)

.PHONY: all clean
