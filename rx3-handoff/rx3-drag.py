#!/usr/bin/env python3
"""Inject a perfectly smooth vertical drag at native RX3 screen coordinates (1280x800) through the touch bridge's
replay mode: a position update every 10 ms, evenly spaced, no jitter. Comparing this with a finger on the panel
tells whether choppy list scrolling comes from the panel's touch reports or from how the firmware scrolls.

usage: rx3-drag.py [x y_from y_to seconds]     default: 640 600 200 3  (upwards through the middle of the list)
       rx3-drag.py 640 600 200 0.3            a quick flick
Do not touch the panel while it runs: both would be feeding the same firmware input."""
import rx3_env
import subprocess, struct, time, sys
a = sys.argv[1:]
x, y0, y1 = (int(v) for v in (a[0:3] if len(a) >= 3 else (640, 600, 200)))
seconds = float(a[3]) if len(a) > 3 else 3.0
p = subprocess.Popen([rx3_env.BINDIR + '/rx3-touch-bridge', '--replay', rx3_env.ROOT + '/dev/tsc2007_2-0048'],
                     stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
def ev(t, c, v): p.stdin.write(struct.pack('llHHi', 0, 0, t, c, v)); p.stdin.flush()
steps = max(1, int(seconds / 0.01))
ev(3, 47, 0); ev(3, 57, 100); ev(3, 53, x); ev(3, 54, y0); ev(0, 0, 0)
time.sleep(0.1)                                        # settle on the first point, as a finger would
start = time.monotonic()
for i in range(1, steps + 1):
    ev(3, 54, round(y0 + (y1 - y0) * i / steps)); ev(0, 0, 0)
    time.sleep(max(0, start + i * 0.01 - time.monotonic()))
ev(3, 57, -1); ev(0, 0, 0); time.sleep(0.3)
p.stdin.close(); p.wait()
print('dragged x=%d from y=%d to y=%d in %.2f s (%d updates)' % (x, y0, y1, seconds, steps))
