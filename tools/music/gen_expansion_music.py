"""Original synthesized Capoeira / JKD loops; no sampled recordings.

Usage: python tools/music/gen_expansion_music.py assets/audio/music/generated
Uses the existing synthesis helpers and imageio-ffmpeg to write looping OGGs.
"""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

import imageio_ffmpeg
import numpy as np
import gen_style_music as synth


def bow_note(midi, closed=False):
    """Metallic struck-string / resonator approximation, not a real berimbau."""
    t = np.arange(int(synth.SR * 0.55)) / synth.SR
    f = synth.note_hz(midi)
    phase = 2 * np.pi * f * t + 0.8 * np.exp(-t * 35)
    tone = np.sin(phase) + 0.4 * np.sin(phase * 2.01) + 0.18 * np.sin(phase * 3.97)
    tone *= synth.env(len(t), 0.001, 0.12 if closed else 0.25)
    return tone * (1 + 0.22 * np.sin(2 * np.pi * 11 * t))


def capoeira():
    synth.RNG = np.random.default_rng(811)
    tr = synth.Track(112, 32)
    b = tr.beat
    for bar in range(32):
        t = bar * tr.bar
        root = [50, 50, 55, 57][(bar // 4) % 4]
        # A dry, offbeat struck-string call answered by the hand drums.
        for at, degree, closed in [(0, 0, False), (0.75, 2, True), (1.5, 0, False), (2.5, 7, False), (3.25, 2, True)]:
            tr.add(t + at * b, bow_note(root + degree, closed), 0.24, -0.25)
        for at, pitch, slap in [(0, 115, False), (1, 230, True), (1.75, 160, False), (2.5, 115, False), (3, 250, True), (3.75, 180, True)]:
            tr.add(t + at * b, synth.hand_drum(0.32, pitch, slap), 0.5 if not slap else 0.3, 0.15)
        for eighth in range(8):
            tr.add(t + (eighth * 0.5 + (0.055 if eighth % 2 else 0)) * b, synth.hat(0.08), 0.14 if eighth % 2 else 0.09, 0.45)
        for at in [0, 1.5, 2.75]:
            tr.add(t + at * b, synth.sub_bass(root - 24, b * 0.65), 0.2)
        if 8 <= bar < 24 and bar % 2 == 0:
            for at, degree in [(0.5, 12), (1.5, 14), (2.25, 19), (3.25, 17)]:
                tr.add(t + at * b, synth.flute(root + degree, b * 0.5, breath=0.12), 0.065, 0.25)
        if bar % 8 == 7:
            for k in range(4):
                tr.add(t + (3 + k * 0.25) * b, synth.hand_drum(0.15, 180 + k * 35, True), 0.22)
    return tr.finish(reverb=0.12, room=0.65)


def jeet_kune_do():
    synth.RNG = np.random.default_rng(912)
    tr = synth.Track(118, 32)
    b = tr.beat
    riff = [(0, 0), (0.75, 0), (1.5, 7), (2.25, 10), (3, 7), (3.5, 3)]
    for bar in range(32):
        t = bar * tr.bar
        root = [40, 40, 43, 38][(bar // 4) % 4]
        sparse = 16 <= bar < 20
        for at in ([0, 2.5] if sparse else [0, 1.5, 2.75]):
            tr.add(t + at * b, synth.kick(0.32, 135, 48), 0.55)
        for at in [1, 3]:
            tr.add(t + at * b, synth.snare(0.16, 220), 0.32)
        for k in range(8):
            tr.add(t + k * b / 2, synth.hat(open_=(k == 7 and bar % 4 == 3)), 0.1 if k % 2 else 0.16, -0.25)
        for at, degree in riff[:3] if sparse else riff:
            tr.add(t + at * b, synth.sub_bass(root + degree, b * 0.34), 0.36)
            # Clipped midrange accents leave room for the fight's impacts.
            tr.add(t + at * b, synth.saw(root + degree + 12, b * 0.22, 1400, 0.002, (0.003, 0.12)), 0.12, 0.2)
        if bar % 4 == 2:
            for at, degree in [(0.5, 24), (1.25, 22), (2, 19), (3.25, 15)]:
                tr.add(t + at * b, synth.saw(root + degree, b * 0.35, 2500, 0.001, (0.008, 0.17)), 0.09, -0.2)
        if bar % 8 == 7:
            for k in range(3):
                tr.add(t + (3.25 + k * 0.25) * b, synth.snare(0.1, 180 + k * 50), 0.18)
    return tr.finish(reverb=0.09, room=0.5)


if __name__ == "__main__":
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    report = {}
    with tempfile.TemporaryDirectory(prefix="streetcombat-music-") as tmp:
        for name, compose in [("capoeira", capoeira), ("jeet_kune_do", jeet_kune_do)]:
            track = compose()
            wav = Path(tmp) / (name + ".wav")
            synth.write_wav(str(wav), track)
            subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(output / (name + "_theme.ogg"))], check=True)
            report[name] = {"seconds": len(track) / synth.SR, "rms_db": float(20 * np.log10(np.sqrt(np.mean(track ** 2)))), "peak_db": float(20 * np.log10(np.max(np.abs(track)))), "loop_boundary_delta": float(np.max(np.abs(track[-1] - track[0])))}
    print(json.dumps(report, indent=2))
