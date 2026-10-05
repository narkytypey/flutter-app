#!/usr/bin/env python3
"""WCAG 2.x contrast ratios. Usage:
  contrast.py FG BG            -> ratio
  contrast.py --table file     -> lines "label FG BG [min]" -> markdown table
Colours are #RRGGBB, or #RRGGBBAA (alpha composited over BG)."""
import sys

def parse(h):
    h = h.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return (r, g, b, a)

def over(fg, bg):
    r, g, b, a = fg
    return tuple(round(a * c1 + (1 - a) * c2) for c1, c2 in zip((r, g, b), bg[:3])) + (1.0,)

def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = c[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

def ratio(fg, bg):
    bgc = parse(bg)
    if bgc[3] < 1:
        raise SystemExit('background must be opaque')
    f = parse(fg)
    if f[3] < 1:
        f = over(f, bgc)
    l1, l2 = sorted((lum(f), lum(bgc)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)

if __name__ == '__main__':
    if sys.argv[1] == '--table':
        print('| Pair | FG | BG | Ratio | Needs | Result |')
        print('|---|---|---|---|---|---|')
        for line in open(sys.argv[2]):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('|')
            label, fg, bg = parts[0].strip(), parts[1].strip(), parts[2].strip()
            need = float(parts[3]) if len(parts) > 3 and parts[3].strip() else 4.5
            r = ratio(fg, bg)
            print(f'| {label} | `{fg}` | `{bg}` | {r:.2f}:1 | {need}:1 | {"pass" if r >= need else "**FAIL**"} |')
    else:
        print(f'{ratio(sys.argv[1], sys.argv[2]):.2f}')
