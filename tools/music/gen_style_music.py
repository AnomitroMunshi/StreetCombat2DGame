"""Placeholder style themes for Karate, Taekwondo and Kickboxing.

Renders each track offline (numpy synthesis, seamless loop: the reverb tail is
wrapped to the start) to WAV; encode to OGG with ffmpeg:

    python gen_style_music.py OUT_DIR
    ffmpeg -i OUT_DIR/karate_theme.wav -c:a libvorbis -q:a 5 karate_theme.ogg

Directions follow docs/BACKLOG.md "Proposed sound palette". Replace the OGGs in
assets/audio/music/generated/ with real tracks any time (GameAudio.MUSIC_FILES).
"""
import sys
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(7)


def note_hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.beat = 60.0 / bpm
        self.bar = self.beat * beats_per_bar
        self.length = self.bar * bars
        n = int(self.length * SR) + SR * 3  # room for tails
        self.l = np.zeros(n)
        self.r = np.zeros(n)

    def add(self, t, sig, gain=1.0, pan=0.0):
        i = int(t * SR)
        sig = sig[: max(0, len(self.l) - i)]
        self.l[i:i + len(sig)] += sig * gain * (1.0 - max(pan, 0.0))
        self.r[i:i + len(sig)] += sig * gain * (1.0 + min(pan, 0.0))

    def finish(self, reverb=0.25, room=1.2):
        mono_ir = RNG.standard_normal(int(room * SR)) * np.exp(-np.linspace(0, 6.5, int(room * SR)))
        mono_ir[: int(0.012 * SR)] = 0.0
        mono_ir /= np.sqrt(np.sum(mono_ir ** 2))
        out = []
        for ch, seed in ((self.l, 1), (self.r, 2)):
            ir = np.roll(mono_ir, seed * 37)
            wet = np.fft.irfft(np.fft.rfft(ch, len(ch) + len(ir)) * np.fft.rfft(ir, len(ch) + len(ir)))[: len(ch)]
            mix = ch + wet * reverb
            n = int(self.length * SR)
            loop = mix[:n].copy()
            loop[: len(mix) - n] += mix[n:]  # wrap the tail: seamless loop
            out.append(loop)
        st = np.stack(out, axis=1)
        st = np.tanh(st * 1.4) / np.tanh(1.4)  # gentle glue
        st *= 10 ** (-17.0 / 20.0) / np.sqrt(np.mean(st ** 2))  # -17 dB RMS like the user's tracks
        peak = np.max(np.abs(st))
        if peak > 0.93:
            st = np.tanh(st / peak * 1.2) / np.tanh(1.2) * 0.93
        return st


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)


def lowpass(sig, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(sig)
    y = 0.0
    for i, x in enumerate(sig):
        y = (1 - a) * x + a * y
        out[i] = y
    return out


def lp_fast(sig, cutoff):
    # Frequency-domain brick-ish lowpass with a soft knee (fast for long signals).
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    spec *= 1.0 / (1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(sig))


def kick(dur=0.35, f0=120, f1=45):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(n, 0.001, 0.12) + RNG.standard_normal(n) * env(n, 0.0005, 0.004) * 0.3


def snare(dur=0.22, tone=190):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = lp_fast(RNG.standard_normal(n), 6000) - lp_fast(RNG.standard_normal(n), 400) * 0.3
    return noise * env(n, 0.001, 0.06) * 0.7 + np.sin(2 * np.pi * tone * t) * env(n, 0.001, 0.05) * 0.5


def hat(dur=0.06, open_=False):
    n = int((0.25 if open_ else dur) * SR)
    noise = RNG.standard_normal(n)
    noise = noise - lp_fast(noise, 7000)
    return noise * env(n, 0.0005, 0.09 if open_ else 0.018) * 0.5


def taiko(dur=0.9, f=62):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ff = f * (1 + 0.6 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(n, 0.002, 0.28)
    skin = lp_fast(RNG.standard_normal(n), 900) * env(n, 0.001, 0.03)
    return body + skin * 0.6


def hand_drum(dur=0.25, f=200, slap=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ff = f * (1 + 0.3 * np.exp(-t * 40))
    s = np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(n, 0.001, 0.08 if not slap else 0.04)
    s += lp_fast(RNG.standard_normal(n), 3500 if slap else 1500) * env(n, 0.0005, 0.012) * (0.8 if slap else 0.3)
    return s


def pluck(midi, dur=1.2, bright=0.5):
    # Karplus-Strong string.
    f = note_hz(midi)
    period = max(2, int(SR / f))
    n = int(dur * SR)
    buf = RNG.uniform(-1, 1, period)
    buf = lowpass(buf, 2000 + 6000 * bright)
    out = np.empty(n)
    decay = 0.996 - 0.004 * (1 - bright)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = decay * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.002, dur * 0.6)


def flute(midi, dur, vib=5.2, breath=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = note_hz(midi) * (1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.minimum(t / 0.25, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    air = lp_fast(RNG.standard_normal(n), note_hz(midi) * 3) * breath
    shape = np.minimum(t / 0.06, 1) * np.minimum((dur - t) / 0.12, 1).clip(0, 1)
    return (tone + air) * shape


def saw(midi, dur, cutoff=2000, detune=0.006, amp_env=(0.005, 10.0)):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune, 0.0, detune):
        f = note_hz(midi) * (1 + d)
        out += 2 * ((t * f) % 1.0) - 1
    out = lp_fast(out / 3, cutoff)
    shape = np.minimum(t / amp_env[0], 1) * np.minimum((dur - t) / 0.02, 1).clip(0, 1) * np.exp(-t / amp_env[1])
    return out * shape


def sub_bass(midi, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * note_hz(midi) * t) + 0.25 * np.sin(4 * np.pi * note_hz(midi) * t)
    return s * np.minimum(t / 0.008, 1) * np.minimum((dur - t) / 0.03, 1).clip(0, 1)


def pad(midis, dur, cutoff=900):
    out = sum(saw(m, dur, cutoff, 0.01, (0.4, 20.0)) for m in midis)
    n = len(out)
    t = np.arange(n) / SR
    return out * np.minimum((dur - t) / 0.5, 1).clip(0, 1)


# --- Karate: disciplined, sparse, tension and release -------------------------
def karate():
    tr = Track(100, 32)
    b, bar = tr.beat, tr.bar
    # D miyako-bushi: D Eb G A Bb.
    D, Eb, G, A, Bb = 50, 51, 55, 57, 58
    chords = [[D, A], [D, A], [Bb - 12, D], [G - 12, D], [D, A], [Eb, Bb], [G - 12, D], [A - 12, Eb]]
    koto = [D + 12, A, Bb, A, G, A, D + 12, None, Eb + 12, D + 12, Bb, A, G, Eb, D, None]
    flute_a = [(0, A + 12, 1.5), (2, Bb + 12, 0.5), (2.5, A + 12, 1.5), (4, G + 12, 2), (6, D + 12, 2)]
    flute_b = [(0, D + 24, 1), (1, Eb + 24, 1), (2, D + 24, 2), (4, Bb + 12, 1), (5, A + 12, 1), (6, G + 12, 2)]
    for bar_i in range(32):
        t0 = bar_i * bar
        section_b = bar_i >= 16
        ch = chords[bar_i % 8]
        tr.add(t0, pad([m - 12 for m in ch] + [ch[0]], bar, 700 if not section_b else 1100), 0.10)
        tr.add(t0, sub_bass(ch[0] - 12, bar * 0.95), 0.22)
        # Taiko: deliberate accents; denser in B, a roll into each 8-bar phrase.
        hits = [0, 2.5] if not section_b else [0, 1.5, 2, 3.5]
        if bar_i % 8 == 7:
            hits = [0, 1, 2, 2.5, 3, 3.25, 3.5, 3.75]
        for h in hits:
            tr.add(t0 + h * b, taiko(f=58 if h == 0 else 70), 0.55 if h == 0 else 0.35)
        # Koto motif in eighths (every other bar in A, every bar in B).
        if section_b or bar_i % 2 == 0:
            for k, m in enumerate(koto[(bar_i % 2) * 8:(bar_i % 2) * 8 + 8]):
                if m is not None:
                    tr.add(t0 + k * b * 0.5, pluck(m, 1.0, 0.6), 0.32, pan=-0.3)
        # Bamboo flute phrases, sparse.
        if bar_i % 4 in (1, 3):
            phrase = flute_b if section_b else flute_a
            for beat_at, m, length in phrase:
                if t0 + beat_at * b * 0.5 < tr.length:
                    tr.add(t0 + beat_at * b * 0.5, flute(m, length * b * 0.5 + 0.1), 0.16, pan=0.25)
        # Clacks (hyoshigi) on 4 in B.
        if section_b:
            tr.add(t0 + 3 * b, hand_drum(0.12, 900, True), 0.25, pan=0.4)
    return tr.finish(reverb=0.35, room=2.0)


# --- Taekwondo: agile and uplifting, rhythmic lift --------------------------------
def taekwondo():
    tr = Track(128, 32)
    b, bar = tr.beat, tr.bar
    # E Korean-style pentatonic: E G A B D.
    prog = [(40, [52, 55, 59]), (43, [55, 59, 62]), (45, [57, 60, 64]), (38, [54, 57, 62])]
    arp_a = [64, 67, 69, 71, 74, 71, 69, 67]
    arp_b = [76, 74, 71, 69, 71, 74, 76, 79]
    melody = [(0, 76, 1), (1, 74, 0.5), (1.5, 71, 0.5), (2, 69, 1), (3, 71, 1)]
    for bar_i in range(32):
        t0 = bar_i * bar
        root, ch = prog[(bar_i // 2) % 4]
        section_b = bar_i >= 16
        tr.add(t0, pad(ch, bar, 1400), 0.07)
        # Drums: four on the floor kick, backbeat snare, 16th hats.
        for k in range(4):
            tr.add(t0 + k * b, kick(0.3, 130, 48), 0.55)
        for k in (1, 3):
            tr.add(t0 + k * b, snare(), 0.35)
        for k in range(16):
            tr.add(t0 + k * b / 4, hat(open_=(k % 8 == 6)), 0.18 if k % 2 else 0.26, pan=0.3)
        # Janggu-style hand drum: deok-kung pattern.
        for at, f, slap in ((0, 160, False), (0.75, 320, True), (1.5, 160, False), (2.5, 320, True), (3, 160, False), (3.5, 320, True)):
            tr.add(t0 + at * b, hand_drum(0.25, f, slap), 0.28, pan=-0.35)
        # Bass on the offbeats with octave lift.
        for k in range(8):
            m = root - 12 + (12 if k % 4 == 3 else 0)
            tr.add(t0 + k * b / 2 + b / 4, sub_bass(m, b / 2), 0.26)
        # Bright plucked arpeggio.
        arp = arp_b if section_b else arp_a
        for k, m in enumerate(arp):
            tr.add(t0 + k * b / 2, pluck(m, 0.6, 0.85), 0.2, pan=0.2)
        # Lead melody in B, rising fill each 8 bars.
        if section_b and bar_i % 2 == 0:
            for at, m, length in melody:
                tr.add(t0 + at * b, saw(m, length * b * 0.95, 3500, 0.004, (0.01, 1.0)), 0.12)
        if bar_i % 8 == 7:
            for k in range(8):
                tr.add(t0 + 2 * b + k * b / 4, snare(0.1, 200 + k * 25), 0.12 + k * 0.03)
    return tr.finish(reverb=0.2, room=1.0)


# --- Kickboxing: driving breakbeat, punch-to-kick momentum ------------------------
def kickboxing():
    tr = Track(132, 32)
    b, bar = tr.beat, tr.bar
    riff_a = [45, None, 45, 48, None, 45, 50, 48]  # A minor, syncopated
    riff_b = [41, None, 41, 43, None, 43, 45, None]
    for bar_i in range(32):
        t0 = bar_i * bar
        section_b = bar_i >= 16
        riff = riff_b if section_b else riff_a
        if not section_b:
            # Breakbeat: kick on 1 and the 'and' of 2, snare on 2 and 4, ghost notes.
            for at in (0, 1.5, 2.75):
                tr.add(t0 + at * b, kick(), 0.6)
            for at in (1, 3):
                tr.add(t0 + at * b, snare(), 0.42)
            for at in (2.25, 3.75):
                tr.add(t0 + at * b, snare(0.1), 0.12)
        else:
            # Half-time B: kick on 1, big snare on 3, more space.
            tr.add(t0, kick(0.45, 110, 40), 0.65)
            tr.add(t0 + 2.5 * b, kick(), 0.4)
            tr.add(t0 + 2 * b, snare(0.35, 170), 0.5)
        for k in range(8):
            tr.add(t0 + k * b / 2, hat(open_=(k == 7)), 0.2, pan=-0.25)
        # Syncopated bass and the gritty riff (saw, slightly driven).
        for k, m in enumerate(riff):
            if m is None:
                continue
            tr.add(t0 + k * b / 2, sub_bass(m - 12, b / 2 * 0.9), 0.3)
            gr = saw(m, b / 2 * 0.85, 1800 if not section_b else 2600, 0.008, (0.003, 0.35))
            tr.add(t0 + k * b / 2, np.tanh(gr * 3) * 0.6, 0.16, pan=0.25)
            tr.add(t0 + k * b / 2, np.tanh(saw(m + 7, b / 2 * 0.85, 1800, 0.008, (0.003, 0.35)) * 3) * 0.6, 0.1, pan=-0.25)
        # B section: a sustained synth line on top for contrast.
        if section_b and bar_i % 2 == 0:
            for at, m, length in ((0, 69, 2), (2, 72, 1), (3, 71, 1), (4, 69, 3)):
                tr.add(t0 + at * b, saw(m, length * b, 2200, 0.01, (0.05, 3.0)), 0.1)
        if bar_i % 8 == 7:
            for k in range(6):
                tr.add(t0 + 2.5 * b + k * b / 4, snare(0.08, 180 + k * 15), 0.2)
    return tr.finish(reverb=0.15, room=0.9)


def write_wav(path, st):
    data = (np.clip(st, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    out = sys.argv[1]
    for name, fn in (("karate", karate), ("taekwondo", taekwondo), ("kickboxing", kickboxing)):
        st = fn()
        write_wav(f"{out}/{name}_theme.wav", st)
        print(name, f"{len(st) / SR:.1f} s", f"rms {20 * np.log10(np.sqrt(np.mean(st ** 2))):.1f} dB",
              f"peak {20 * np.log10(np.max(np.abs(st))):.1f} dB")
