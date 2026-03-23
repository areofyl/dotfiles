#!/usr/bin/env python3
"""ASCII plasma animation with gruvbox palette - plays then dissipates."""
import sys, os, math, time, select, termios, tty, signal

# Gruvbox colors
GRUVBOX = [
    (29, 32, 33),      # dark bg
    (50, 48, 47),      # bg0_h
    (60, 56, 54),      # bg1
    (80, 73, 69),      # bg2
    (102, 92, 84),     # bg3
    (124, 111, 100),   # bg4
    (146, 131, 116),   # gray
    (168, 153, 132),   # warm tan
    (189, 174, 147),   # fg4
    (213, 196, 161),   # fg2
    (235, 219, 178),   # fg cream
]

# Build smooth palette cycling through retro amber/warm tones
PALETTE = []
cycle = [0, 1, 2, 4, 6, 8, 10, 9, 7, 5, 3, 1, 0]
steps_per = 22
for i in range(len(cycle) - 1):
    c1 = GRUVBOX[cycle[i]]
    c2 = GRUVBOX[cycle[i + 1]]
    for s in range(steps_per):
        t = s / steps_per
        r = int(c1[0] + (c2[0] - c1[0]) * t)
        g = int(c1[1] + (c2[1] - c1[1]) * t)
        b = int(c1[2] + (c2[2] - c1[2]) * t)
        PALETTE.append((r, g, b))
PAL_LEN = len(PALETTE)

CHARSET = " .,:;+*%#@"
SPEED = 1.8
SCALE = 0.1
FPS = 25
PLAY_TIME = 0.0    # no full plasma, start fading immediately
FADE_TIME = 0.25   # seconds to dissipate

# Precompute sin table
SIN_TABLE = [math.sin(i * math.pi * 2 / 1024) for i in range(1024)]
def fast_sin(x):
    return SIN_TABLE[int(x * 162.97) % 1024]


def main():
    cols, rows = os.get_terminal_size()
    w, h = cols, rows

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    out = sys.stdout

    def cleanup(*_):
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        out.write("\033[0m\033[H\033[J\033[?25h")
        out.flush()

    signal.signal(signal.SIGINT, lambda *_: (cleanup(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda *_: (cleanup(), sys.exit(0)))

    try:
        tty.setcbreak(fd)
        out.write("\033[?25l\033[2J")
        out.flush()

        start = time.monotonic()
        frame_time = 1.0 / FPS
        total_time = PLAY_TIME + FADE_TIME

        while True:
            t0 = time.monotonic()
            elapsed = t0 - start
            if elapsed >= total_time:
                break

            t = elapsed * SPEED
            buf = []

            # Calculate fade: 1.0 during play, fades to 0.0 during dissipate
            if elapsed < PLAY_TIME:
                fade = 1.0
            else:
                fade = 1.0 - (elapsed - PLAY_TIME) / FADE_TIME

            for row in range(h):
                buf.append(f"\033[{row + 1};1H")
                for col in range(w):
                    v = fast_sin(col * SCALE + t)
                    v += fast_sin(row * SCALE + t * 0.7)
                    v += fast_sin((col + row) * SCALE * 0.5 + t * 0.5)
                    v += fast_sin(math.sqrt(col * col + row * row) * SCALE * 0.4 + t * 1.2)

                    idx = int((v * 0.25 + 0.5) * PAL_LEN) % PAL_LEN
                    pr, pg, pb = PALETTE[idx]

                    # Fade towards black
                    pr = int(pr * fade)
                    pg = int(pg * fade)
                    pb = int(pb * fade)

                    # During fade, characters also thin out
                    if fade < 1.0:
                        char_idx = int(idx * (len(CHARSET) - 1) / (PAL_LEN - 1) * fade)
                        char = CHARSET[char_idx]
                    else:
                        char = CHARSET[idx * (len(CHARSET) - 1) // (PAL_LEN - 1)]

                    buf.append(f"\033[38;2;{pr};{pg};{pb}m{char}")
                buf.append("\033[0m")

            out.write("".join(buf))
            out.flush()

            # Check for keypress to skip
            remaining = frame_time - (time.monotonic() - t0)
            if remaining > 0:
                r, _, _ = select.select([sys.stdin], [], [], remaining)
                if r:
                    break
            else:
                r, _, _ = select.select([sys.stdin], [], [], 0)
                if r:
                    break

    finally:
        cleanup()


if __name__ == "__main__":
    main()
