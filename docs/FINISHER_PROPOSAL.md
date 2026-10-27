# Style finishers — proposal for approval

Status: **proposal, nothing built.** Covers backlog FIN-STYLE-01..04, FIN-FEEL-01..06 and KAR-AIR-REF-01..03.
Mark each row ✅ / ✏️ (change) / ❌ in the approval table at the end.

## What changes

Today every style shares two contextual finishers: **Air Smash** (leap, grab, hammer-fist spike) when the killing
blow catches an airborne opponent, and **Wall Crush** (knee in, pin, double palm) near a wall. Only Wall Crush's
strike poses vary by style.

After this work each style owns **one airborne and one wall finisher**, chosen from the *attacker's* style.
Its two open-floor finishers stay as they are.

| Context (checked in this order) | Chance | Plays | Falls back to |
|---|---|---|---|
| Kill lands on an airborne / launched opponent | 70% | the style's air finisher | a ground finisher |
| Victim within 170 px of a wall | 60% | the style's wall finisher | a ground finisher |
| Otherwise | — | one of the style's two ground finishers | — |

The rule that stops the same finisher playing twice in a row stays. When it blocks the contextual finisher, the
game falls back to that style's own ground finishers, never another style's move. The old Air Smash and Wall Crush
stay in code under their old IDs so saved data and tests still resolve, but no style uses them any more.

## Rules every finisher follows

- **Shape:** anticipation (a weight shift you can read) → a fast drive into contact → a brief contact hold → a
  reaction that follows the direction of the blow → the attacker follows through and settles. Before the final
  blow: **≤ 1.1 s** and **at most 3 setup hits**.
- **Contact first:** the reaction, sound, spark and launch fire only once the intended limb is within 6 px of the
  intended body zone. The existing contact system does this; the new beats use the same `limb` and `reach` keys.
- **The victim comes to the strike:** an airborne victim falls into a contact zone. No stretching the winner's arm
  and no teleporting either fighter. No grabs.
- **Restrained slow motion:** only on the final contact (about 4 ticks at half speed, as now), with the current
  finisher camera and its smaller zoom.
- **Different endings:** airborne finishers end in a **spike or diagonal drive into the floor** (impact crater,
  dust, bounce, settle). Wall finishers end in a **wall impact and collapse** (crack decal, debris, slide down,
  slump). Ground finishers keep their **long launch**.
- **Style identity:** Boxing is punches only. Kickers chamber and recoil. Bangla Maar is reckless but still
  physically connected.
- **Blood:** a small directional spray on the final contact only, and a little more on wall impacts. *(Decision
  D3 below.)*

Timings are in physics ticks (60 per second). In the beat lists, *(new)* marks a pose to author and *(reuse)* one
that already exists.

---

## 1. Boxing

### Air: **FALLING CROSS** (punches only)
1. **10 ticks** — sink the hips under the falling opponent, rear hand loaded. `heavy_windup` *(reuse)*.
   Victim: keeps falling with `knock_fly`.
2. **8 ticks** — rising uppercut into the body as the victim drops into range. `uppercut_strike` *(reuse)*.
   Victim: folds at the waist and is held for a moment.
3. **18 ticks, final** — step in with a short overhand cross down onto the jaw. `overhand_hit` *(reuse)*.
   Victim: driven diagonally down and away; hits the floor and skids. Head snaps away from the fist.
4. **45 ticks** — the boxer resets to guard and rolls the shoulders. `guard`.

### Wall: **THE CORNER COUNT**
1. **8 ticks** — body hook (`rbody_load` → `rbody_hit`, *reuse*). Victim: folds and is pushed back 6 px toward the wall.
2. **8 ticks** — lead hook to the head (`lhook_hit`, *reuse*). Victim: head turns and the shoulders hit the wall (crack).
3. **6 ticks** — dip and load the rear hand (*new*, `cross_load_low`).
4. **18 ticks, final** — straight right through the chin (`heavy_strike`, *reuse*). Victim: head hits the wall (big crack),
   legs buckle, slides down the wall into a sit.
5. **40 ticks** — a composed step back and hands drop slightly. `guard` with `atk_move -3`.

## 2. Muay Thai

### Air: **SKY KNEE**
1. **8 ticks** — two quick steps, arms reach up to frame (*new*, `knee_reach`; hands stay open and don't grab).
2. **10 ticks** — jump into a knee to the body as the victim falls (`fknee_hit`, *reuse*, `atk_vy -9`).
   Victim: folds over the knee.
3. **18 ticks, final** — still airborne, a downward diagonal elbow onto the back of the head or shoulder (*new*,
   `elbow_down`). Victim: spiked straight down; crater and bounce.
4. **45 ticks** — land in a Thai guard with the knee up (the existing intro knee-up pose).

### Wall: **IRON CORNER**
1. **8 ticks** — step in and plant the rear foot (`elbow_load`, *reuse*).
2. **10 ticks** — driving knee to the body; pushes the victim into the wall (`knee`, *reuse*). Victim: back hits the
   wall (crack).
3. **8 ticks** — short second knee (`fknee_hit`, *reuse*). Victim: folds.
4. **18 ticks, final** — horizontal elbow across the jaw (`elbow_hit`, *reuse*). Victim: head whips sideways along
   the wall and collapses sideways.
5. **40 ticks** — step back and bow the head (*new*, `wai_nod`, small).

## 3. Karate

### Air: **SKYLINE VERDICT** (matches your flying side-kick photo, KAR-AIR-REF)
1. **8 ticks** — sink and push off. `heavy_windup` *(reuse)*, lower.
2. **8 ticks** — airborne, knee chambered high, torso turning side-on (*new*, `flying_chamber`).
3. **18 ticks, final** — side kick, heel first, to the falling victim's torso. The rear knee stays **tucked under the
   hips** and the arms counterbalance without covering the contact (*new*, `flying_side_kick`).
   Victim: driven diagonally down and back, lands and skids far.
4. **12 ticks** — retract the leg in the air (`flying_chamber`, reversed).
5. **35 ticks** — land in a front stance with knife-hand, the same pose as the intro.

### Wall: **FINAL GYAKU**
1. **8 ticks** — a short knife-hand opening that parts the guard (*reuse* the knife-hand from the intro pose). Victim:
   stagger.
2. **8 ticks** — rooted reverse punch to the body (`thrust` family, *reuse*). Victim: folds, back to the wall.
3. **10 ticks** — the hips draw back and load: one clear, deliberate pause (*new*, `gyaku_load`).
4. **18 ticks, final** — the final reverse punch to the sternum with a *kiai*, the hips snapping forward
   (`gyaku_hit`, *reuse*). Victim: chest hits the wall (big crack) and slides straight down.
5. **40 ticks** — zanshin: the fist stays out for a moment, then returns to the front stance.

## 4. Kung Fu (the flowing, water-like motion is kept)

### Air: **DESCENDING DRAGON PALM** *(new name: "Dragon's Descent" is already Kung Fu's ground finisher, see D1)*
1. **10 ticks** — circular arm wind-up, weight flows back (`palm_windup`, *reuse*).
2. **10 ticks** — a rising palm under the falling victim's chest that turns their body flat (`palm_lead`, *reuse*).
   Victim: rotates flat in mid-air.
3. **18 ticks, final** — leaping hammer-palm straight down onto the chest (*new*, `hammer_palm`).
   Victim: spiked flat on their back; a ring-shaped dust shockwave.
4. **45 ticks** — land on one leg and settle into the crane stance.

### Wall: **WALL OF PALMS**
1. **6 / 6 / 6 ticks** — three alternating short chest and body palms on a monotone-cubic flow, with no stops
   (`palm_lead` / `palm_rear`, *reuse*). Each one pushes the victim a little closer to the wall.
2. **10 ticks** — sink, both palms drawn to the hip, a breath (`palm_windup`, *reuse*).
3. **18 ticks, final** — double palm to the chest (`palm_strike`, *reuse*). Victim: back flat against the wall
   (spider-web crack); slides down slowly.
4. **40 ticks** — a closing salute: fist into the palm (*new*, small).

## 5. Taekwondo

### Air: **SKYFALL AXE** *(new name: "Heaven's Heel" is already Taekwondo's ground finisher, see D1)*
1. **8 ticks** — hop step, arms up.
2. **10 ticks** — the leg swings straight up past the head and the victim falls into range (`axe_raise`, *reuse*).
3. **18 ticks, final** — the heel chops straight down onto the shoulder or collarbone (`axe_chop`, *reuse*).
   The heel touches before any effect fires. Victim: spiked into the floor; crater.
4. **40 ticks** — chamber back down into a bouncing guard.

### Wall: **CORNER CYCLONE**
1. **10 ticks** — roundhouse to the body (`bodyrh_hit`, *reuse*). Victim: folds and is pushed into the wall.
2. **8 ticks** — recoil and plant the support foot; the turn starts (`back_turn`, *new*), with a visible ball-of-foot
   pivot (LEG-04).
3. **18 ticks, final** — chambered spinning back kick, heel to the sternum (`back_extend`, *reuse*). Victim: the wall
   cracks behind them and they slump.
4. **40 ticks** — re-chamber, and the feet re-plant after the spin. This uses the spin-wrap fix, so no stuck rotation.

## 6. Kickboxing

### Air: **AIR BREAKER**
1. **8 ticks** — jump in (`jump_punch_windup`, *reuse*).
2. **8 ticks** — jumping straight punch to the falling victim's head (`jump_punch_strike`, *reuse*). Victim: head snaps back.
3. **18 ticks, final** — compact roundhouse in the air, shin to the ribs (*new*, `air_roundhouse`). Victim: knocked
   sideways and down, lands and rolls once.
4. **40 ticks** — land balanced and stay in guard.

### Wall: **CORNER BREAKER**
1. **6 / 6 ticks** — jab and cross to the body (*reuse*). Victim: folds, back to the wall.
2. **8 ticks** — a low kick to the thigh (`lowrh_hit`, *reuse*). Victim: the leg buckles and the head drops.
3. **18 ticks, final** — high roundhouse to the dropped head (`spin_kick` / high RH, *reuse*). Victim: the head hits the
   wall and they collapse sideways.
4. **40 ticks** — a slight bounce back on the feet.

## 7. Bangla Maar (strikes only, no grab)

### Air: **AKASH PATAK** — আকাশ পটক *("sky slam"; a placeholder name, you'll know better, see D2)*
1. **8 ticks** — a messy run-up and an overconfident leap; arms swinging (`hammer_windup`, *reuse*).
2. **6 ticks** — both fists raised over the head, the hands locked together.
3. **18 ticks, final** — a reckless double-hand hammer on the falling victim (`hammer_strike`, *reuse*).
   Victim: spiked into the floor.
4. **40 ticks** — the attacker also lands badly: stumbles, then recovers and shrugs (*new*, `stumble_land`).

### Wall: **DEOWAL DHAKKA** — দেওয়াল ধাক্কা
1. **12 ticks** — Jor Dhakka shoulder charge into the victim (*reuse*, `jd` poses). Victim: back hits the wall (crack).
   The attacker staggers off the impact.
2. **8 ticks** — huge wind-up for the slap, the hand going right back (`mega_slap_wind`, *reuse*).
3. **18 ticks, final** — a giant open-hand slap (`slap_hit`, *reuse*). Victim: the head spins along the wall and
   they drop sideways.
4. **40 ticks** — a "কি রে…" gloat stance, reusing the victory speech bubble timing.

---

## How it would be built

1. **Data.** Add `air_finisher` and `wall_finisher` to `MartialArtStyle` with validation: the ID must be known and
   must be of the right context type. 14 new `Kind` entries in `finisher.gd`, each with its own beat list (no
   template).
2. **Selection.** `choose()` reads the attacker's two IDs instead of the shared pair. Falling back keeps it within the
   attacker's style.
3. **Airborne entry.** A new beat key, `def_fall_to`, lets the victim's existing flight arc continue into a target
   contact height. The finisher waits (with a cap) for the victim to fall into range, instead of launching both
   fighters as Air Smash does.
4. **Wall reactions.** The wall impact reuses the existing crack and debris effects. A per-stage material
   (wood / concrete / metal) sets the colour, debris and thud sound. *Stage material is part of batch 6; until then
   every wall uses concrete.*
5. **Floor spike.** A crater and dust ring, an impact thud, a bounce of about 30 px, then settle. A ground-launch
   finisher never gets this.
6. **Tests.** Extend `test_finisher_contact` to all 14 new finishers: both facings, both walls, gaps of 70 and
   120 px, varied victim height and fall speed, an overlap of air with wall, and 30/60/120 FPS. Selection tests
   cover the attacker's style only and the fallback. Training preview lists the new names.
7. **Visual review.** Clips at normal speed and slowed, plus an effects-reduced contact frame, both directions.

## Rollout (FIN-FEEL-06: prototype first)

- **Batch 5a — prototype two:** **Karate SKYLINE VERDICT** (the one you gave a reference for) and **Muay Thai IRON
  CORNER**, with a timing sheet and before/after clips. **You review the feel here before I do the rest.**
- **Batch 5b:** Boxing, Kickboxing, Taekwondo.
- **Batch 5c:** Kung Fu and Bangla Maar, then remove the generic Air Smash and Wall Crush from normal play.

## Decisions needed

| # | Question | My recommendation |
|---|---|---|
| D1 | Kung Fu and Taekwondo air finishers: new names (**Descending Dragon Palm**, **Skyfall Axe**) or keep "Dragon's Descent" and "Heaven's Heel" as aerial variants? | New names. Two finishers with the same name would confuse the banner and training. |
| D2 | Bangla Maar air name: **Akash Patak**, keep **Air Smash**, or your own Bengali name? | Your call. You'll know what sounds right. |
| D3 | Blood: small spray on the final hit only, more on wall impacts, or none? | Small spray on the final hit, darker on wall impacts. |
| D4 | Prototype pair: Karate air plus Muay Thai wall? | Yes. One kick-based air finisher and one close-range wall finisher show both systems. |
| D5 | Keep the old Air Smash and Wall Crush selectable in training as "classic"? | No. Keep them in code only. |

## Approval table

| Style | Air finisher | ✅/✏️/❌ | Wall finisher | ✅/✏️/❌ |
|---|---|---|---|---|
| Boxing | Falling Cross | | The Corner Count | |
| Muay Thai | Sky Knee | | Iron Corner | |
| Karate | Skyline Verdict | | Final Gyaku | |
| Kung Fu | Descending Dragon Palm | | Wall of Palms | |
| Taekwondo | Skyfall Axe | | Corner Cyclone | |
| Kickboxing | Air Breaker | | Corner Breaker | |
| Bangla Maar | Akash Patak | | Deowal Dhakka | |
