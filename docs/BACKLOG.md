# Backlog

Findings from the playtest captures reviewed on 2026-10-26 (7 matches, one per style).
Timestamps are `clip @ seconds`.

## High priority: readability and bugs

- [ ] **HUD callouts overlap.** COUNTER, N HITS, DIZZY!, move names, SIGNATURE READY and "... READY" all draw in the same slot under each health bar (Bangla vs Muay Thai @31.5, Kickbox vs Karate @22–24, Muay Thai vs TKD @21–29). The combo text also covers the style name. Stack them in rows or queue them, and give READY a fixed row.
- [ ] **Fighters overlap at close range.** Bodies interpenetrate by half a torso or more in most exchanges (Boxing vs Bangla @11.5, 14.5, 20–23.5). Widen the push-box and separate the fighters on hit.
- [ ] **Speech bubbles don't follow the speaker.** The bubble stays where it was spoken when the fighter is knocked down (Bangla vs Muay Thai @17, 29.5; the knocked-out line in Karate vs Bangla @28.5–30).
- [ ] **Style select shows only 5 of 7 tabs.** Kickboxing and Bangla Maar are hidden behind a horizontal scroll. Fit all 7 (two rows or narrower tabs).
- [ ] **Winner off-screen after a finisher.** In Karate vs Bangla @30.5–32.5 the winner is cut off at the right edge, so the celebration isn't seen. Frame both fighters on the result screen.
- [ ] **The win title covers the winner.** "PLAYER/RIVAL WINS" sits over the winner's body (Muay Thai vs TKD @35.5, TKD vs Kickbox @22).

## Medium priority: visuals

- [ ] **Rival Karate and Taekwondo are too dark.** Black gi/dobok with dark skin on a dark background, so they're only readable by the outline.
- [ ] **Rival rim glow is always on** (`rim_glow`, fighter_visual.gd). It hides costume detail and competes with hit flashes. Dim it at idle, make it thinner, or use a floor marker instead.
- [ ] **Taekwondo and Karate look the same** (white uniform with a black belt). Give the dobok its V-neck trim or a different colour.
- [ ] **The dojo banner shows through the empty part of the health bar.** Make the bar background opaque.
- [ ] **Fighters are small on screen** (about a third of the window height). Zoom the camera in more during neutral play.

## Gameplay feel

- [ ] **Knockdowns are too frequent.** There were 3 in 15 s in TKD vs Kickbox, and that match ended in 23 s. Raise the threshold or require a combo.
- [ ] **Speech lines repeat** within seconds (শালা শুয়োর!, উফ্!). Add a cooldown per line and rotate through several lines.
- [ ] **Bangla Maar's win quote** is a censored swear on every win. Consider a cleaner line or a rotation.
- [ ] **The SIGNATURE READY prompt is easy to miss.** Pulse it or show a key icon by the Focus bar.

## Discussed earlier, not yet done

- [ ] **Bangla Maar balance.** It wins about 21% of AI-vs-AI matches because of the spec's lighter damage. Decide whether to buff it.
- [ ] **Overall style balance spread.** From Kung Fu at 67% down to Boxing at 38%; the target is roughly 45–55%.
- [ ] **Bundle a Bengali font.** Speech currently needs Nirmala UI or Vrinda installed. A free, openly licensed font (e.g. Noto Sans Bengali, OFL) would fix this, but it needs your approval before download.
- [ ] **Rounds.** Single round only: no round timer, no best-of-3.
- [ ] **Hurtboxes are fixed rectangles** and don't follow extended limbs.
- [ ] **AI difficulty select.** Difficulty is only adjustable through exported values on `EnemyAI`; there's no menu option.
- [ ] **Throws and grappling.** Design note only (`docs/V0.3_PLAN.md` §4). Parked on purpose; the Bangla Maar spec said no grappling yet.
- [ ] **Boxing quality checklist** (11 items from the Boxing pass) has never been checked off by a human playtest.
- [ ] Harmless "2 ObjectDB instances leaked" warning on exit (looping music held by the audio server).

## Audio and performance

- [ ] **Finisher audio clips.** It peaks at 0 dB in Kung Fu vs Kickbox @25–30 (Hundred Palms) and also in Muay Thai vs TKD. Add a limiter or lower the gain of stacked finisher sounds.
- [ ] **The captures average about 36 fps against a 60 fps timebase.** Check the in-game FPS during finishers to rule out frame drops.
