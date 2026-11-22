# The Wader's clicks from voice-acted takes (recorded with tools/wader_voice/recorder.html): cut each
# take into its bursts and clicks, then give them the creature's treatment, the same way the first
# voice was made (mix_voice.py): lowered for size with a second throat an octave under it, a torn
# edge, a short tiled echo. Writes one mono WAV per clip, plus the close-up rattle as a seamless loop.
#   python3 mix_wader_clicks.py <takes dir> <out dir> [A|B|C|D]
# Version A stays closer to the voice; B is deeper and less human (part of the vowel flattened out,
# a fixed throat resonance), but sounded like a typewriter: the flattening (which made the first
# voice's throat clicks sound like a printer), the metallic resonance, bright ticks and evenly spaced
# clicks. C keeps B's depth without those: no flattening or ring, the highs rolled off, each click a
# little higher or lower and the gaps between them uneven, a detuned second copy. D is C wetter and
# duller, as if heard through water.
import glob, os, subprocess, sys
import numpy as np
import voice_lib as V
from voice_lib import SR, pitch, band, fit, drive, devoice, pool_reverb

TAKES, OUT = sys.argv[1:3]
VERSION = sys.argv[3] if len(sys.argv) > 3 else 'A'
RAW_TOO = len(sys.argv) > 4            # also write each clip as recorded (for a before/after preview)
P = dict(A=dict(semis=-4, sub=0.30, flat=0.0, comb=0.0, drv=1.6, wet=0.12),
         B=dict(semis=-7, sub=0.45, flat=0.4, comb=0.35, drv=2.2, wet=0.15),
         C=dict(semis=-7, sub=0.45, flat=0.0, comb=0.0, drv=1.6, wet=0.16, hi=3200, jitter=1, double=0.4),
         D=dict(semis=-7, sub=0.55, flat=0.0, comb=0.0, drv=1.5, wet=0.22, hi=2300, jitter=1, double=0.45))[VERSION]
rng = np.random.default_rng(23)
ROOM = dict(rt_low=1.0, rt_high=0.45)


def load(path):
    cmd = ['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-']
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    return x / (np.abs(x).max() + 1e-9)


def segments(x, merge=0.16, min_len=0.05, rel=0.07, keep=0.3):
    # The bursts in a take: where the level is up, joined across the short gaps between clicks.
    # Lip noises and breaths before a burst are much quieter than it, and are left out.
    hop = 240
    e = np.abs(x[:len(x) // hop * hop]).reshape(-1, hop).max(1)
    on = e > e.max() * rel
    runs, start = [], None
    for i, a in enumerate(np.append(on, False)):
        if a and start is None: start = i
        if not a and start is not None: runs.append([start, i]); start = None
    joined = []
    for r in runs:
        if joined and (r[0] - joined[-1][1]) * hop < merge * SR: joined[-1][1] = r[1]
        else: joined.append(r)
    out = []
    for a, b in joined:
        if (b - a) * hop >= min_len * SR and e[a:b].max() >= keep * e.max():
            out.append((max(0, a * hop - int(0.012 * SR)), min(len(x), b * hop + int(0.06 * SR))))
    return out


def gate(x, thr=0.045, release=0.03):
    # Quiet the room hiss between clicks (it comes up a lot once the voice is driven): the gain follows
    # the level, open at once on a click and closing over 30 ms after it.
    hop = 48
    e = np.abs(np.pad(x, (0, -len(x) % hop))).reshape(-1, hop).max(1)
    k = np.exp(-hop / (release * SR))
    for i in range(1, len(e)):
        e[i] = max(e[i], e[i - 1] * k)
    g = np.clip((e - thr * 0.5) / (thr * 0.5), 0.0, 1.0) ** 2
    g = np.convolve(np.repeat(g, hop)[:len(x)], np.ones(96) / 96, 'same')
    return x * g


def edges(x, a=0.004, b=0.04):
    x = x.copy(); na, nb = int(a * SR), min(int(b * SR), len(x) // 2)
    x[:na] *= np.linspace(0, 1, na); x[-nb:] *= np.linspace(1, 0, nb)
    return x


def throat(x, g, delay=0.009):
    # A fixed resonance, like a long windpipe: a feedback comb (about 110 Hz and its overtones).
    m = len(x) + SR
    fr = np.fft.rfftfreq(m, 1 / SR)
    y = np.fft.irfft(np.fft.rfft(x, m) / (1 - g * np.exp(-2j * np.pi * fr * delay)), m)[:len(x)]
    return 0.6 * x + 0.4 * y / (np.abs(y).max() + 1e-9) * np.abs(x).max()


def click_starts(x):
    # Where each click in a burst starts (as the booth page finds them).
    hop = 96; n = len(x) // hop
    env = np.abs(x[:n * hop]).reshape(n, hop).max(1); peak = env.max()
    pre = np.concatenate([[0], np.cumsum(env)]); thr = max(peak * 0.16, 0.012); out = []; last = -10 ** 9
    for i in range(n):
        lo, hi = max(0, i - 30), max(0, i - 2)
        bg = (pre[hi] - pre[lo]) / (hi - lo) if hi > lo else 0
        if env[i] > thr and env[i] > bg * 2.2 and i - last > 20:
            out.append(i * hop); last = i
    return out


def unevenly(seg):
    # Undo the machine-gun evenness: every click a little higher or lower and louder or softer, and
    # the gap after it stretched or squeezed. Pieces overlap by a few ms so nothing clicks at the joins.
    on = click_starts(seg)
    if len(on) < 3:
        return seg
    bounds = [max(0, on[0] - int(0.004 * SR))] + [o - int(0.004 * SR) for o in on[1:]] + [len(seg)]
    out = np.zeros(int(len(seg) * 1.5) + SR); pos = 0; xf = int(0.003 * SR)
    for a, b in zip(bounds[:-1], bounds[1:]):
        piece = seg[a:b]
        if len(piece) < 2 * xf:
            continue
        piece = pitch(piece, rng.uniform(-1.3, 1.3)) * rng.uniform(0.65, 1.0)
        w = np.ones(len(piece)); w[:xf] = np.linspace(0, 1, xf); w[-xf:] = np.linspace(1, 0, xf)
        m = min(len(piece), len(out) - pos); out[pos:pos + m] += (piece * w)[:m]
        gap = int(len(piece) * rng.uniform(0.72, 1.35))
        pos += max(gap, 2 * xf) - xf
    head = seg[:bounds[0]]
    return np.concatenate([head, out[:pos + int(0.08 * SR)]])


def voice(seg):
    if P.get('jitter'):
        seg = unevenly(seg)
    # Lowered for size (which also slows it), with a second throat an octave under.
    body = pitch(seg, P['semis'])
    s = body + fit(band(pitch(seg, P['semis'] - 12), hi=700), len(body)) * P['sub']
    s /= np.abs(s).max() + 1e-9
    if P['flat']:
        d = devoice(s)
        s = (1 - P['flat']) * s + P['flat'] * d / (np.abs(d).max() + 1e-9)
    if P['comb']:
        s = throat(s, P['comb'])
    if P.get('double'):
        # A second copy a fraction higher and 17 ms late: thicker and less exact, like two throats.
        d2 = fit(np.concatenate([np.zeros(int(0.017 * SR)), pitch(s, 0.35)]), len(s))
        s = s + d2 * P['double']
    s = drive(band(s, lo=90), P['drv'])
    if P.get('hi'):
        s = band(s, hi=P['hi'])              # after the edge, so its harsh top is rolled off too
    return s


def room(s):
    return pool_reverb(s, wet=P['wet'], **ROOM).mean(1)          # mono: it plays from a point in the hall


def room_loop(s):
    # The same echo, wrapped round the loop point, so the loop has no seam.
    st = pool_reverb(s, wet=P['wet'], **ROOM).mean(1)
    n = len(s)
    out = st[:n].copy(); tail = st[n:]
    out[:len(tail)] += tail[:n]
    return out


def write(name, x, sub=''):
    os.makedirs(OUT + sub, exist_ok=True)
    name = sub.strip('/') + '/' + name if sub else name
    x = band(x, lo=70)
    x = x / (np.abs(x).max() + 1e-9) * 0.89
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', f'{OUT}/{name}.wav'], input=pcm, check=True)


os.makedirs(OUT, exist_ok=True)
count = dict(single=0, slow=0, fast=0)
for path in sorted(glob.glob(TAKES + '/*')):
    kind = os.path.basename(path).split('_')[1].split('.')[0]
    x = gate(load(path))
    if kind == 'rattle':
        # The long close-up rattle: the whole take, looped. The ends are cross-faded into each other.
        a, b = segments(x, merge=0.6, keep=0.2)[0][0], segments(x, merge=0.6, keep=0.2)[-1][1]
        s = voice(x[a:b]); xf = int(0.5 * SR); n = len(s) - xf
        ramp = np.sin(np.linspace(0, np.pi / 2, xf))
        loop = s[:n].copy(); loop[:xf] = s[:xf] * ramp + s[n:] * np.cos(np.linspace(0, np.pi / 2, xf))
        write('wader_rattle_close', room_loop(loop))
        if RAW_TOO: write('wader_rattle_close', x[a:b], '/raw')
        print('rattle: %.1f s loop from %s' % (n / SR, os.path.basename(path)))
        continue
    segs = segments(x, merge=0.3 if kind == 'single' else 0.16)
    for a, b in segs:
        count[kind] += 1
        name = 'wader_%s_%02d' % ({'single': 'click'}.get(kind, kind), count[kind])
        write(name, room(voice(edges(x[a:b]))))
        if RAW_TOO: write(name, edges(x[a:b]), '/raw')
    print('%-6s %s: %d clips: %s' % (kind, os.path.basename(path), len(segs), ' '.join('%.2f' % ((b - a) / SR) for a, b in segs)))
print('version %s: %d clicks, %d slow bursts, %d fast bursts' % (VERSION, count['single'], count['slow'], count['fast']))
