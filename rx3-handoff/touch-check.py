#!/usr/bin/env python3
"""Measure how smoothly the touchscreen reports a drag, independent of the player.

Slide one finger slowly and steadily across the panel while it records. It prints how many position updates
arrived per second, how evenly they were spaced, and how far the finger jumped between them. A smooth panel
reports at a steady rate with small, even steps; long gaps or big jumps are what make scrolling feel choppy.

Panels whose touch controller has no interrupt line (Waveshare DSI panels on the vc4-kms-dsi-waveshare-panel
overlay, Goodix driver) are polled by the kernel, every 17 ms by default; --poll sets that interval first.

usage: sudo python3 touch-check.py [--poll MS] [SECONDS]      (default 6 s)"""
import glob, os, struct, sys, time, select

FMT = 'llHHi'; SZ = struct.calcsize(FMT)
EV_SYN, EV_ABS = 0, 3
ABS_MT_SLOT, ABS_MT_X, ABS_MT_Y, ABS_MT_TRACKING_ID = 0x2f, 0x35, 0x36, 0x39

def find_touchscreen():
    for ev in sorted(glob.glob('/sys/class/input/event*')):
        props = os.popen('udevadm info -q property -p ' + ev).read()
        if 'ID_INPUT_TOUCHSCREEN=1' in props:
            name = open(ev + '/device/name').read().strip()
            return '/dev/input/' + os.path.basename(ev), name, os.path.realpath(ev + '/device')
    sys.exit('No touchscreen found (no input device with ID_INPUT_TOUCHSCREEN=1).')

args = sys.argv[1:]; poll = None
if args[:1] == ['--poll']: poll = int(args[1]); args = args[2:]
seconds = float(args[0]) if args else 6.0
dev, name, sysdir = find_touchscreen()
pollf = sysdir + '/poll'
print('touchscreen: %s (%s)' % (dev, name))
if os.path.exists(pollf):
    if poll is not None:
        try: open(pollf, 'w').write(str(poll))
        except OSError as e: sys.exit('Could not set poll interval to %d ms: %s (run with sudo; the maximum is %s ms)'
                                      % (poll, e, open(sysdir + '/max').read().strip()))
    print('kernel polls it every %s ms (allowed %s..%s ms)' % (open(pollf).read().strip(),
          open(sysdir + '/min').read().strip(), open(sysdir + '/max').read().strip()))
else:
    print('interrupt driven (not polled)' + ('; --poll ignored' if poll is not None else ''))

fd = os.open(dev, os.O_RDONLY)
print('\nSlide one finger slowly across the screen now, for %g seconds...' % seconds)
slot = 0; down = False; x = y = None; frames = []      # (time, x, y) for each report while slot 0 is down
end = time.monotonic() + seconds
while time.monotonic() < end:
    if not select.select([fd], [], [], 0.05)[0]: continue
    data = os.read(fd, SZ)
    if len(data) != SZ: break                          # device gone
    sec, usec, t, c, v = struct.unpack(FMT, data)
    if t == EV_ABS:
        if c == ABS_MT_SLOT: slot = v
        elif slot == 0 and c == ABS_MT_TRACKING_ID: down = v >= 0
        elif slot == 0 and c == ABS_MT_X: x = v
        elif slot == 0 and c == ABS_MT_Y: y = v
    elif t == EV_SYN and c == 0 and down and x is not None:
        frames.append((sec + usec / 1e6, x, y))

if len(frames) < 10: sys.exit('\nOnly %d touch reports seen: touch the screen and keep the finger moving.' % len(frames))
gaps = [(b[0] - a[0]) * 1000 for a, b in zip(frames, frames[1:])]
moving = [(g, ((b[1] - a[1]) ** 2 + (b[2] - a[2]) ** 2) ** .5) for g, a, b in zip(gaps, frames, frames[1:])]
real = [g for g in gaps if g < 200]                    # leave out lifts of the finger
steps = sorted(d for g, d in moving if g < 200 and d > 0)
dupes = sum(1 for g, d in moving if g < 200 and d == 0)
med = lambda v: sorted(v)[len(v) // 2]
print('\n%d reports while touching' % len(frames))
print('rate        %.0f per second' % (1000 / (sum(real) / len(real))))
print('spacing     median %.1f ms, max %.1f ms; %d gaps over 30 ms' % (med(real), max(real), sum(1 for g in real if g > 30)))
if steps: print('movement    median %.0f px, max %.0f px per report; %d reports repeated the last position' % (med(steps), steps[-1], dupes))
print('\nSmooth is roughly: 60+ per second, max spacing under 30 ms, no big jumps.')
