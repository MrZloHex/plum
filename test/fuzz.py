#!/usr/bin/env python3
"""Mutate every test program and feed the result to plc.

Whatever the input, plc must answer with an error or valid IR: never a
crash, never a hang, and never "internal error" -- plc verifies its own
IR, so that message means the checker let through something codegen could
not handle. Reproducers are written to test/fuzz-found/.

    test/fuzz.py [runs-per-file] [seed]
"""
import glob, os, random, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
plc = os.environ.get('PLC', os.path.join(here, '..', 'bin', 'plc'))
runs = int(sys.argv[1]) if len(sys.argv) > 1 else 20
rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)

def mutate(src):
    lines = src.split('\n')
    kind = rng.randrange(4)
    if kind == 0:                                   # truncate
        return src[:rng.randrange(len(src) + 1)]
    if kind == 1:                                   # drop lines
        for _ in range(rng.randint(1, 3)):
            if lines: del lines[rng.randrange(len(lines))]
    elif kind == 2:                                 # duplicate a line
        if lines:
            i = rng.randrange(len(lines)); lines.insert(i, lines[i])
    else:                                           # swap two tokens' worth
        if len(lines) > 1:
            i, j = rng.randrange(len(lines)), rng.randrange(len(lines))
            lines[i], lines[j] = lines[j], lines[i]
    return '\n'.join(lines)

out_dir = os.path.join(here, 'fuzz-found')
bad = total = 0
for f in sorted(glob.glob(os.path.join(here, '*', '*.pl'))):
    if '/typecheck/' in f or '/fuzz-found/' in f:
        continue
    src, d = open(f).read(), os.path.dirname(f)
    for _ in range(runs):
        prog = mutate(src)
        path = os.path.join(d, '__fuzz.pl')
        open(path, 'w').write(prog)
        total += 1
        try:
            r = subprocess.run([plc, path, '-o', '/dev/null'], cwd=d,
                               capture_output=True, timeout=20)
            why = None
            if r.returncode < 0 or r.returncode >= 128:
                why = f'crashed with {r.returncode}'
            elif b'internal error' in r.stdout + r.stderr:
                why = 'produced invalid IR'
        except subprocess.TimeoutExpired:
            why = 'hung'
        os.remove(path)
        if why:
            bad += 1
            os.makedirs(out_dir, exist_ok=True)
            name = os.path.join(out_dir, f'{bad}-{os.path.basename(f)}')
            open(name, 'w').write(prog)
            print(f'{why}: {os.path.relpath(name)}')

print(f'{total} mutated programs, {bad} failures')
sys.exit(1 if bad else 0)
