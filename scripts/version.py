#!/usr/bin/env python3
"""VARV. versionsnummer: samma nummer i sw.js och på sidan.

  python3 scripts/version.py          höjer sista siffran (1.1.9 blir 1.1.10)
  python3 scripts/version.py 1.2.0    sätter ett bestämt nummer
  python3 scripts/version.py --check  kontrollerar att alla ställen stämmer
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLACES = [
    (ROOT / "sw.js", r'(const CACHE="varv-v)([\d.]+)(";)'),
    (ROOT / "index.html", r'(VARV\. version )([\d.]+)( ·)'),
    (ROOT / "index.html", r'(const APPVER=")([^"]+)(";)'),
]

def current():
    found = []
    for path, pat in PLACES:
        m = re.findall(pat, path.read_text(encoding="utf-8"))
        if len(m) != 1:
            sys.exit(f"Hittade {len(m)} träffar för {pat} i {path.name}, väntade 1")
        found.append(m[0][1])
    return found

arg = sys.argv[1] if len(sys.argv) > 1 else None
vals = current()
if arg == "--check":
    if len(set(vals)) != 1:
        sys.exit(f"Versionerna skiljer sig: {vals}")
    print(vals[0])
    sys.exit(0)
if arg:
    new = arg
else:
    a = vals[0].split(".")
    new = ".".join(a[:-1] + [str(int(a[-1]) + 1)])
if not re.fullmatch(r"\d+\.\d+\.\d+", new):
    sys.exit("Versionen ska se ut som 1.1.9")
for path, pat in PLACES:
    t = path.read_text(encoding="utf-8")
    path.write_text(re.sub(pat, lambda m: m.group(1) + new + m.group(3), t, count=1), encoding="utf-8")
print(new)
