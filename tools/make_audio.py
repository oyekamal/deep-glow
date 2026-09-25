#!/usr/bin/env python3
"""Synthesize all game audio with stdlib only (wave + math + random). Run from project root."""
import math, random, struct, wave, os

SR = 22050
random.seed(7)

def write(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    g = 0.89 / peak if peak > 0.89 else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples))

def env(t, a, d, total):
    if t < a: return t / a
    return max(0.0, 1.0 - (t - a) / max(1e-6, d)) if t < total else 0.0

def note_hz(n):  # midi note -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)

def mix_into(buf, start, samples, gain=1.0):
    for i, s in enumerate(samples):
        j = start + i
        if j < len(buf): buf[j] += s * gain

def pluck(hz, dur, bright=0.5):
    n = int(dur * SR); out = []
    for i in range(n):
        t = i / SR
        e = math.exp(-t * 6.0)
        s = math.sin(2 * math.pi * hz * t) + bright * 0.5 * math.sin(4 * math.pi * hz * t) * math.exp(-t * 10)
        out.append(s * e * min(1.0, t * 400))
    return out

def pad(hz, dur):
    n = int(dur * SR); out = []
    for i in range(n):
        t = i / SR
        e = min(1.0, t / 0.4) * min(1.0, (dur - t) / 0.4)
        s = sum(math.sin(2 * math.pi * hz * d * t) for d in (1.0, 1.003, 0.997, 2.001)) / 4
        out.append(s * e)
    return out

# --- music: 4 chords x 4 beats, 96 bpm, A minor-ish, loops cleanly ---
bpm = 96; beat = 60 / bpm
chords = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]]  # Am F G Em
total = int(beat * 16 * SR)
music = [0.0] * total
for ci, ch in enumerate(chords):
    t0 = int(ci * 4 * beat * SR)
    mix_into(music, t0, pad(note_hz(ch[0] - 12), 4 * beat), 0.35)
    mix_into(music, t0, pad(note_hz(ch[2]), 4 * beat), 0.12)
    arp = [ch[0], ch[1], ch[2], ch[1] + 12, ch[2], ch[1], ch[0] + 12, ch[2]]
    for k, n in enumerate(arp):
        mix_into(music, t0 + int(k * beat / 2 * SR), pluck(note_hz(n + 12), beat * 1.2, 0.8), 0.22)
    for b in range(4):  # soft kick on each beat
        kick = [math.sin(2 * math.pi * (110 * math.exp(-i / SR * 18) + 40) * i / SR) * math.exp(-i / SR * 14) for i in range(int(0.25 * SR))]
        mix_into(music, t0 + int(b * beat * SR), kick, 0.35)
# tail wrap so loop seam is smooth
write("audio/music.wav", music)

# --- sfx ---
def sweep(f0, f1, dur, shape="sin", decay=4.0, noise=0.0):
    n = int(dur * SR); out = []; ph = 0.0
    for i in range(n):
        t = i / SR; k = t / dur
        f = f0 * (f1 / f0) ** k
        ph += 2 * math.pi * f / SR
        s = math.sin(ph) if shape == "sin" else (1.0 if math.sin(ph) > 0 else -1.0) * 0.5
        s = s * (1 - noise) + (random.random() * 2 - 1) * noise
        out.append(s * math.exp(-t * decay) * min(1.0, t * 300))
    return out

write("audio/start.wav", [a + b for a, b in zip(sweep(440, 880, 0.35, decay=5), sweep(660, 1320, 0.35, decay=5))])
write("audio/tick.wav", sweep(880, 900, 0.12, decay=25))
write("audio/go.wav", [a * 0.6 + b * 0.6 for a, b in zip(sweep(660, 660, 0.5, decay=6), sweep(990, 990, 0.5, decay=6))])
write("audio/pickup.wav", sweep(1200, 2400, 0.18, decay=14) + sweep(1800, 3000, 0.12, decay=20))
write("audio/hit.wav", sweep(300, 60, 0.45, "sq", decay=7, noise=0.45))
write("audio/death.wav", sweep(220, 30, 1.4, "sq", decay=2.6, noise=0.55))
print("ok")
