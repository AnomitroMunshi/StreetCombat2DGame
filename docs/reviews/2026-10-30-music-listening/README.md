# Music listening pack: 2026-10-30

For your listening review (backlog MUS-02, MUS-07, MUS-08 and MUS-10). Listen with the volume fixed: every preview is
normalised to −16 LUFS, so you judge the music, not its level.

## Files

- `<theme>_preview.mp3`: 30 seconds from 20 s in (or from the start for shorter loops), loudness-matched, with a
  short fade in and out.
- `<theme>_loop_seam.mp3`: the last 4 s of the loop straight into its first 4 s. This is exactly what you hear
  each time the track repeats. Listen for a click, a jump in level or rhythm, or a dead gap at the 4-second mark.

## Measurements

| Theme | Source | Loop length | Loudness of the file (LUFS) | In-game before | In-game after levelling |
|---|---|---:|---:|---:|---:|
| Menu | original | 90.0 s | −14.4 | −18.9 | −19.5 |
| Boxing | original | 89.5 s | −14.0 | −19.8 | −19.5 |
| Muay Thai | original | 89.8 s | −15.9 | −20.1 | −19.5 |
| Kung Fu | original | 89.9 s | −15.0 | −18.9 | −19.5 |
| Bangla Maar | original | 90.0 s | −14.7 | −19.1 | −19.5 |
| Karate | generated | 76.8 s | −16.5 | −21.5 | −19.5 |
| Taekwondo | generated | 60.0 s | −17.0 | −22.0 | −19.5 |
| Kickboxing | generated | 58.2 s | −17.4 | −22.4 | −19.5 |
| Capoeira | generated | 68.6 s | −16.5 | −21.5 | −19.5 |
| Jeet Kune Do | generated | 65.1 s | −15.9 | −20.9 | −19.5 |

**What was found and fixed:** the five generated placeholder themes played 2–3 dB quieter than your five originals,
so changing style changed the music level. All ten are now levelled to −19.5 LUFS in game (`MUSIC_FILES` gains in
`scripts/audio.gd`).

**Still needs your ears:**
1. **Quality (MUS-02, MUS-03):** do the five generated themes hold up next to your originals? They are numpy-synth
   placeholders, so if they sound thin, the fix is new recordings or real instruments, not mixing.
2. **Fatigue (MUS-02):** Taekwondo and Kickboxing loop roughly every minute. A 60–90 s loop was the target; say if
   either gets tiring over a three-round match.
3. **Seams (MUS-07):** any loop where the join is audible.
4. **Menu hook (MUS-08, MUS-10):** is the menu theme memorable within its first few seconds?

Reply with a list such as "redo kickboxing, seam on karate, menu fine", and I'll act on exactly those.
