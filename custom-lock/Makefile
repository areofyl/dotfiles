CC      = cc
CFLAGS  = -O2 -Wall -Wextra $(shell pkg-config --cflags gtk4-layer-shell-0 gtk4)
LDFLAGS = $(shell pkg-config --libs gtk4-layer-shell-0 gtk4) -lpam -lm

lockscreen: lockscreen.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f lockscreen

.PHONY: clean
