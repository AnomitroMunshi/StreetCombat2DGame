# Street Combat

A 2D side-view hand-to-hand fighting prototype for Godot 4: two procedural
stickman fighters in a minimalist training hall, one player against one AI.
It has keyframed martial-arts moves, ragdoll knockdowns, blowback physics,
cinematic finishers, and procedurally generated sound and music.

Built and tested with **Godot 4.7.2 stable** (GL Compatibility renderer).
No plugins and no imported assets: all graphics, sound effects and music are
generated from code.

## Run

From the editor: open Godot, choose **Import**, select `project.godot` in this
folder, then press **F5**.

From a terminal:

```powershell
& "D:\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path D:\firstGame
```

## Match flow

1. **Pre-match:** the dojo, both fighters standing relaxed and a **START MATCH**
   button. Nobody can move or attack yet. Press **Q** here to pick your stance.
2. **Start:** click the button or press **Enter**. Both fighters walk to their
   marks. The player salutes (fist in palm, small bow). The rival drops its chin
   and glares. Then both raise their stance guard.
3. **Countdown:** 3, 2, 1, **FIGHT!**, one second per number, with taiko cues.
   The player's controls and the AI are unlocked on the same tick.
4. **K.O.:** after the finisher, "K.O." stays up until the loser's body has
   stopped moving. Then the winner appears with a **RESTART MATCH** button.
   Enter or **R** also restarts. R works at any time.

Restarting reloads the scene, so health, AI, effects and animation all reset.
Everything in the flow is counted in simulation ticks, with no timers, so an
old countdown can never fire into a new match.

## Martial arts (M6.5, in progress)

Before a match, you choose a **martial art** on the style screen:
- Click a card, or press **Q** to cycle through them. Your fighter shows that
  style's guard and idle live.
- Press **ENTER**, or click CONFIRM, then START MATCH.

The rival always gets a different style. Styles are **locked** once the match
starts. After a match, **REMATCH** (or **R**) keeps your style, and
**CHANGE STYLE** returns to the selection screen.

The attack buttons (J K U O I L, plus W or S) do different things in each
style. **A style can never use a move outside its own set**, whether through a
key, the AI, a combo or a jump. The style screen lists every move with its key.

| Style | Identity | Moves |
|---|---|---|
| **Boxing** | Pressure and counterpunching. No kicks or sweeps at all. | J jab · K cross · U lead hook · I rear hook · O uppercut · L body hook · W+K overhand · S+K slip counter (head-height strikes miss during the slip) · air: jump punch |
| **Taekwondo** | Long-range kicking, with only two basic punches. | J jab · K cross · L side kick · I front kick · W+L high roundhouse · S+L axe kick · U spinning hook kick · away+L back kick · air: jump roundhouse (L/I), jumping spin kick (U, W+L), jump punch (J/K) |

**Focus meter and signature (F).** The thin gold bar under posture is
**Focus**. It fills as you fight well:

| Event | Focus |
|---|---|
| Light hit | +5 |
| Heavy hit | +10 |
| Kick | +8 |
| Counter-hit | +15 |
| Perfect parry | +20 |
| Perfect dodge | +12 |
| Block | +3, at most once every half second, so turtling can't farm it |

Misses earn nothing. Finishers and signature hits earn nothing either. At
100 the HUD shows **SIGNATURE READY – F**. Pressing **F** spends the whole
meter on your style's signature: Boxing's **Gazelle Hook** (an explosive step
into a rising hook) or Taekwondo's **540 Tornado Kick** (a leaping 1.5-turn
spinning kick). Signatures can be blocked, parried or dodged. A miss is not
refunded and leaves a long, punishable recovery. F with a part-full meter
does nothing. The rival uses its signature too, sparingly and in range.

**Style finishers.** On open floor, each style finishes with its own two
finishers:
- **Boxing:** The Final Bell, Eight-Count.
- **Taekwondo:** Cyclone 360, Heaven's Heel.

Air Smash and Wall Crush are shared by all styles and still take priority.

Muay Thai, Karate, Kung Fu and Kickboxing come next, each with its own
signature and two finishers. Styles are data
files in `styles/`; see `docs/ADDING_A_STYLE.md` and
`docs/M6.5_ARCHITECTURE.md`.

## Controls

| Key        | Action                      |
|------------|-----------------------------|
| A / D      | Move (backing up is slower) |
| Space      | Jump (hold A/D to jump in that direction) |
| A A / D D (double-tap) | Dodge: backstep sway (away) or slip-in (toward), with invulnerability. **Very close (within 80 px), toward the opponent: slip past behind them** |
| Hold S + double-tap A/D | **Evasive roll:** forward rolls through the opponent to their other side; backward rolls retreat |
| Space + toward | Jump; a jump from normal range clears the opponent and lands behind them (cross-up) |
| J          | Jab (light punch)           |
| K          | Cross (heavy punch)         |
| U          | Backhand (lead-hand backfist) |
| O          | Uppercut (launcher / anti-air) |
| L          | Side kick                   |
| W + L      | High kick (face level)      |
| A/D (away) + L from standing | Spinning back kick: turn, heel thrust (slow, strongest push). Retreating then L stays a side kick |
| S + L      | Sweep (low, always knocks down) |
| I          | Front kick (push kick)      |
| L or I in the air | Jump kick (one per jump) |
| J / K / U / O in the air | Jump punch: flying forward punch (one air attack per jump) |
| S (hold)   | Crouch: head-level strikes pass over you |
| Shift      | Tap just before a hit to **parry**; hold to block |
| S + Shift  | Low block (needed against sweeps) |
| Q          | Cycle your fighting stance  |
| Enter / click | START MATCH / RESTART MATCH button |
| R          | Restart the match (back to the pre-match screen) |
| F1         | Toggle developer overlay (off by default) |

## Combat rules

All timing is in fixed 60 Hz simulation ticks (`_physics_process`), never in
render frames.

| Attack    | Startup | Active | Recovery | Damage | Hitstun | Blockstun | On block |
|-----------|--------:|-------:|---------:|-------:|--------:|----------:|---------:|
| Jab       | 5       | 3      | 11       | 6      | 16      | 10        | -3       |
| Cross     | 11      | 3      | 20       | 13     | 22      | 14        | -8       |
| Side kick | 9       | 4      | 17       | 10     | 18      | 12        | -8       |
| Front kick| 7       | 3      | 15       | 8      | 17      | 13        | -4       |
| Backhand  | 6       | 2      | 12       | 7      | 16      | 11        | -3       |
| Uppercut  | 9       | 3      | 18       | 12     | 24      | 14        | -7       |
| Jump kick | 4       | 8      | 12*      | 11     | 20      | 12        | —        |
| Jump punch| 3       | 6      | 10*      | 8      | 18      | 10        | —        |
| High kick | 7       | 3      | 18       | 12     | 20      | 14        | -8       |
| Sweep     | 10      | 3      | 19       | 9      | knockdown | 12      | -10      |
| Dodge     | 2       | 9 (invulnerable) | 5 | —   | —       | —         | —        |
| Block     | 2       | hold   | 6        | 0      | —       | —         | —        |

\* Air attacks end as soon as you land, followed by 8 ticks of landing lag.
A jump without an attack has 4 ticks of landing lag.

The full table, including hitboxes, knockback and lunge, is in
`scripts/combat_data.gd` under `ATTACK_TABLE`.

- **Buffer:** an attack press is held for 10 ticks, until the fighter can act.
- **Combos:** during the first few ticks of recovery (`cancel_window`), a
  buffered attack chains into the next swing, up to 3 swings. Two conditions:
  the swing must have **connected** (hit or blocked), and the branch must be
  listed in `CombatData.CHAINS`. A whiffed attack always plays out its full
  recovery.

  | From | Can chain into |
  |---|---|
  | Jab (J) | anything |
  | Backhand (U) | J, K, O, L, W+L |
  | Cross (K) | L, I, W+L, O, S+L |
  | Uppercut (O) | J, U, W+L (juggle) |
  | Side kick (L) | J, U, K |
  | Front kick (I) | L, W+L |
  | High kick (W+L) | J, K |
  | Sweep, air attacks | nothing |

  Heavy enders never repeat (no cross→cross). The 3rd swing is a finisher
  with extra knockback and stun. Juggles end with a knockdown on the 3rd hit.
- **Interrupts:** an attack can end early only by being hit, by chaining,
  or (for a jump kick) by landing. You can't walk, block, jump or turn around
  mid-attack.
- **One hit per swing:** each swing can connect at most once, then its hitbox
  is spent.
- **Jumping:** 2 ticks of squat, then about 28 ticks in the air, peaking near
  110 px. Falling uses stronger gravity than rising, so the arc is snappy rather
  than floaty. Your direction at takeoff sets your momentum. Holding a direction
  in the air steers slightly, and releasing it keeps your momentum. Punches can't be used in the air.
  A kick button gives one jump kick per jump. If you get hit in the air you pop
  up slightly, which allows juggles. A high enough jump can cross over the
  opponent, because pushboxes only collide when both fighters are close in
  height.
- **Backhand:** a quick snap to the head with a little more reach than the jab.
  Good in the middle of a chain, e.g. J-U-K.
- **Uppercut:** short reach, but its hitbox extends well above the head, so it
  works as an anti-air against jump-ins. On hit it launches the opponent about
  45 px into the air, and the next attacks in the chain can juggle them. When
  blocked it doesn't launch, and it is the riskiest punch to get blocked.
- **Knockdown:** the 3rd consecutive hit of a combo knocks the opponent off
  their feet. They fly back, slam down and bounce (dust and shake), lie down for
  about 0.6 s, then get up in stages: sit up, crouch, stand. While down or
  getting up they can't be hit. A KO uses the same fall and stays down.
- **Juggle limit:** from the 4th hit of a combo onward, each hit stuns 3 ticks
  less (minimum 6). Long juggles and restarted chains always end, but normal
  3-hit chains are unaffected.
- **Front kick:** a fast push kick. It shoves the opponent about 55 px away,
  which makes it a spacing tool, and its pushback leaves you fairly safe if
  it's blocked.
- **Block timing:** the guard takes 2 ticks to come up, so it must be raised
  before the hit. Dropping it, or attacking or jumping out of it, costs 6 ticks
  of guard release. An attack buffered during the release fires right after.
- **Dodge / step:** double-tap A or D. Away from the opponent is a backstep
  sway (about 93 px), toward them is a slip-in (about 77 px). Frames 2-10 of 16
  are invulnerable and show blue afterimages. An attack pressed during the
  dodge is held and fires the moment it ends, which is your counter. The AI
  sometimes backsteps attacks instead of blocking them.
- **High kick (W + L):** fast for a kick, lands at head height, unsafe on block.
- **Crouch (hold S):** a low squat with the guard up and a shorter hurtbox.
  The high kick and backhand whiff over you, but the jab, cross and mid kicks
  still hit. You can't walk while crouched, but you can attack, jump or dodge
  straight out of it.
- **Low block (S + Shift):** sweeps are low attacks, so a standing block does
  not stop them. Only a low block does. The low block also blocks everything
  else. The AI low-blocks when it sees a sweep coming.
- **Back kick (away + L from standing):** a spinning back kick. The fighter
  turns its back on the opponent and thrusts the heel straight into them.
  - 13 damage, the biggest push in the game, and a good chance to send the
    opponent flying.
  - Slow (11-tick startup) and very unsafe if blocked or missed. It never chains.
  - Press away and L together after standing still. If you've been walking
    backwards, L stays a side kick.
- **Changing sides:** there are three ways to get behind the opponent.
  - **Jump** over them from normal range. A forward jump clears them once your
    feet are 60 px up and your centre passes theirs.
  - **Slip past:** dodge toward them from very close (within 80 px).
  - **Roll:** hold S and double-tap toward them for a forward roll through them.

  While you are crossing, the bodies don't block each other. After you land,
  any remaining overlap is resolved smoothly by moving only you (up to 6 px per
  tick, never a teleport), on to the side your centre reached. If your centre
  didn't get past theirs, you're eased back.

  Walking can never pass through. A raised guard doesn't turn around, so
  landing behind a blocking opponent and attacking hits their back. Facing
  flips only once the two centres are more than 8 px apart, so it never
  flickers. Against a wall with no room, the crossing ends in a clean
  separation.
- **Evasive roll (hold S + double-tap):** 4 ticks to tuck, 16 ticks rolling
  (170 px forward, or 130 px back), and 9 ticks to rise. You are invulnerable
  for ticks 3–14 only, and use a low hurtbox throughout. Facing is locked
  during the roll, and an attack pressed during it fires as it ends. All of
  these values are the `ROLL_*` constants in `combat_data.gd`.
- **AI and side changes:** when you cross over, the rival waits a human
  reaction time (its reaction frames plus 2–6 ticks) before turning and
  acting. It never predicts where you'll land, but it can still anti-air a
  jump.
- **Sweep (S + L):** a low leg sweep that always knocks down if it isn't blocked. The
  swept fighter's feet are kicked out from under them.
- **Blocking:** hold Shift while idle or walking. A blocked hit does no damage,
  causes blockstun and has reduced pushback. Heavy attacks are unsafe on block.
- **Perfect parry:** pressing Shift opens a 4-tick parry window (2 of them
  before the guard is even up). A hit inside the window is deflected: no
  damage, a bright glint and metallic ring, and the attacker staggers for
  24 ticks, long enough for any counter. Attacking, dodging or jumping
  cancels the deflect at once. Keep holding Shift and you are simply blocking.
  Sweeps must be parried low (S + Shift).
- **No parry spam:** after an attempt, no new window opens for 30 ticks
  (pressing again just blocks). Letting go of an unused attempt within 14
  ticks, or attacking out of it, costs 14 ticks of recovery instead of 6. A
  successful parry resets the cooldown, so parries can be chained.
- **Perfect dodge:** if a strike passes through you during the dodge's
  invulnerable frames, the dodge skips its recovery and your counter comes out
  sooner. You hear a whoosh and see a ring.
- **AI defence:** the rival dodges instead of blocking when its posture is
  above 70%, and always punishes a broken guard. Otherwise it mostly blocks. Sometimes (15%) it times a parry
  against slow attacks it can read (startup of 8 or more ticks). It punishes
  a staggered player.
- **Posture (thin bar under health):** a guard meter separate from HP. It fills
  from the centre outward when you:
  - block a strike, by that attack's own posture value: jab 6, cross 14,
    kicks 14–16, sweep 10;
  - have your attack parried: 1.5× its posture value plus 8;
  - get hit while staggered or during an attack's startup (a **counter hit**).

  Ordinary hits do not fill it. After 1.5 s without new posture damage it drains
  quickly in neutral and slowly while guarding.

  Full posture **breaks the guard**: a shatter effect, a GUARD BREAK callout, and
  about 0.9 s of BROKEN, with no blocking or acting. That is a guaranteed punish.
  The first hit ends the break, so it never becomes a stun loop. Afterwards
  posture is empty and locked for 2 seconds (a grey bar). A counter hit never
  breaks the guard by itself: it stops one point short.
- **Directional guard:** a raised guard does not turn around. If the opponent
  jumps over you while you hold block, their attack hits your back. Let go of
  Shift and block again to face them.
- **Trades:** both fighters' hits are checked before either is applied, so
  simultaneous hits both land.
- **KO and finishers:** a hit that would KO starts a scripted **finisher**.
  The camera zooms in, the final blow plays in slow motion, then "K.O." and the
  winner appear. Both the player and the AI get finishers.

## Finishers

The game picks the finisher that fits the situation; on open floor it picks
one of two at random.

| Finisher | When | Sequence |
|---|---|---|
| Air Smash | Opponent is airborne, or the kill was an uppercut | Leap together, reach and grab, overhead hammer-fist, spike into the floor, crater and shockwave |
| Wall Crush | Opponent is within ~170 px of the pillar behind them | Flying knee into the wall, a cross while pinned, then a double palm strike; the wall cracks and they slump against it |
| Palm Flurry | Open floor (random) | 4 alternating palm strikes, a load-up, then a double palm that blasts them across the arena |
| Spinning Heel Kick | Open floor (random) | Jab and cross, a spin with the back turned, then a head-high heel kick that sends them tumbling |
| Tornado Kick 360 | Open floor (random) | Jab and cross, coil, then a jumping full 360 spin into a high roundhouse |

The finisher picked is random on open floor and never repeats the previous
one (this is remembered across restarts). Every finisher ends with a
follow-through beat: the attacker returns to stance, or lands in a low crouch
after the aerial finishers.

Finishers are presented with letterbox bars, a camera that zooms in and then
follows the flying victim, slow motion on the final blow, a white flash,
speed-line bursts and shockwave rings. KO'd bodies may bounce off the walls
before coming to rest.

Finishers are data in `scripts/finisher.gd`. Each one is a list of beats
(duration, poses, movement, launches, hits), so they're easy to tweak or extend.
A simultaneous lethal trade skips the finisher and shows "DOUBLE K.O.".


### Finisher presentation and stage damage

Finishers follow the finisher VFX reference sheet. An **additive light layer**
supplies:
- warm impact **flares** with long rays on every contact, and a huge one on
  the final blow;
- blue **energy crescents**: the palm-blast shockwave fan, and the arc of
  spinning kicks;
- **glowing spin arcs**;
- blue **speed lines** behind the attacker, and warm ones behind a launched
  victim.

The attacker also wears a **blue aura** for the whole finisher. Impacts throw
**angular, lit debris chunks** and **billowing, soft-edged dust clouds**. The
final-blow screen flash is kept moderate, so it never washes out the effects.

Every finisher runs the same sequence:

1. Setup and anticipation.
2. Contact with hitstop.
3. Slow motion on the final blow only.
4. Victim reaction.
5. Environmental damage.
6. Aftermath.
7. The result, which appears only once the body is at rest.

The finisher is accompanied by a **taiko build-up** that accelerates under the
choreography (the fight track is ducked). A **victory sting** plays with the result.

| Finisher | What happens |
|---|---|
| **Air Smash** | A downward streak burst at the hammer-fist. The spike **smashes the floorboards**: a dark broken hole ringed with pale splintered wood, broken board ends sticking up, and a few cracks running along the planks. **Floorboard splinters** fly up and scatter, with a dust burst and a shockwave. |
| **Wall Crush** | Every strike dents the pillar (a crushed hollow with a raw-wood rim), and the cracks run along it and stay on it. **Splinters burst out of the dent** on each hit, more each time. Grit trickles from the cracks while the victim is pinned. The final palm adds an inward streak burst. Chunks fall, and the pillar jolts. |
| **Palm Flurry** | Every palm pushes a **crescent of air**. The final blast is a huge shockwave with forward streaks and blown dust. The body tumbles, then **skids**, leaving a dust trail and **scuff marks** on the boards. |
| **Spinning Heel / Tornado** | **Wind swirls** around the spinning body, and **dust kicks up on takeoff**. At contact the heel's arc flashes through the head, with streaks and sparks. |

Notes on the stage damage:
- All damage is visual (decals and particles). It never changes collision.
- Debris (chips and splinters) is pooled and capped at 90, decals at 140, and transient effects at 260, for mobile. Flying pieces are drawn in front of the fighters; settled pieces rest on the floor.
- Effects use a seeded RNG.
- Cracks and craters persist until the match restarts.
## Architecture

```
project.godot            1280x720, 60 Hz physics, input map
scenes/main.tscn         Arena, camera, 2 fighters, AI, overlay, HUD
scenes/fighter.tscn      Reusable fighter: Fighter (logic) + Visual (drawing)
scripts/combat_data.gd   Attack tables, tuning constants, Intent type (no deps)
scripts/fighter.gd       Fixed-tick combat state machine
scripts/fighter_visual.gd  Joint-based stickman, read-only view of Fighter
scripts/enemy_ai.gd      State-based AI that outputs an Intent
scripts/finisher.gd      FinisherDirector: picks and plays scripted KO finishers
scripts/stances.gd       Stances: the 8 fighting stances (guard pose, idle rhythm, lead foot)
scripts/effects.gd       FxLayer: sparks, particles, rings, speed lines, dust, crack decals
scripts/audio.gd         GameAudio: procedural SFX + threaded BGM render, voice pool, limiter
scripts/hud.gd           Health bars, combo counter, messages, dev panel
scripts/main.gd          Input, tick order, hit resolution, hitstop, KO, restart
```

Dependencies point one way: `main -> finisher / fighter / enemy_ai / hud / effects / audio -> combat_data`.
The visual reads its parent Fighter, and Fighter never touches visuals, input
or AI. The player and the AI drive fighters the same way, through
`CombatData.Intent`, so touch controls can later plug in as another Intent
source.

Order of one tick: read input, AI intent, `Fighter.tick()` for both,
pushboxes, gather hits, apply hits, then feedback. During hitstop the
simulation is frozen, but player presses are still buffered.

## Smooth rendering

Combat runs at a fixed 60 Hz. Godot physics interpolation is enabled, so
fighters move smoothly on high refresh-rate monitors (120/144 Hz+). Poses are
sampled in continuous time between ticks. During hitstop the pose freezes on
the impact frame.

## Fighting stances

There are 8 stances, taken from the reference sheet: Bladed (player default),
Squared (right foot forward, pressure), Boxing Guard, Muay Thai Guard (lead knee
up), Karate (long, low, rear fist chambered), Kung Fu (low and wide, open
hands), Grappler (bent forward, hands out to clinch) and Counter-Fighter
(upright, lead hand low, head movement).

- Each stance sets the guard every move starts from and returns to, the idle
  rhythm, and which foot leads.
- **Q** cycles your stance. Your choice is remembered across restarts.
- The AI picks a random stance each match and never uses yours. If you switch
  into its stance, it changes to another one.
- Stances are style only: frame data and damage are the same in every stance.
- The stance name is shown under each health bar.

## Blowback physics

- Strong hits can launch the opponent even outside combos: front kick 40%,
  side kick 30%, cross 15% (no blowback on blocked hits).
- A launched body may tumble in the air, bounces once off the floor (harder
  falls bounce higher), bounces once off a wall if it hits one fast enough, and
  then may do backward breakfall rolls before a quick crouch get-up.
- A body that comes to rest too close to a pillar slides clear of it.

## Character look

Fighters are solid silhouettes drawn from the same 12-joint skeleton that
drives animation and the ragdoll:

- Tapered limbs: thick thighs and upper arms narrowing to the calves, ankles and
  wrists. Solid fists and shoe-shaped feet.
- A side-profile torso: chest out in front, a narrower waist, hips and
  shoulders. The head has a jaw and chin profile.
- One outline is drawn around the whole body first, so overlapping limbs merge
  into a single clean silhouette. Far-side limbs are shaded for depth.
- The player is an ivory silhouette with a dark outline. The rival is a
  charcoal silhouette with a red rim glow, matching the reference sheet. Both
  wear an accent-coloured belt with a hanging knot, a headband with trailing
  tails, and wrist wraps.
- Colours are exported on the Fighter (`body_color`, `accent_color`,
  `outline_color`, `rim_glow`), so new characters are just new values.

## Body mechanics (from the stance and animation review)

- **Planted feet:** while standing, walking, crouching, blocking or reeling, the
  legs are solved with 2-bone IK to feet fixed on the floor, so the body never
  skates. A foot that drifts too far from its stance spot steps there in a
  short arc while the other foot stays planted. Feet re-plant after being
  knocked back.
- **Footwork:** walking takes quick, strictly alternating steps. Advancing, the
  front foot steps first; retreating, the rear foot steps back first. The
  stance narrows while moving and the hips settle slightly whenever a leg would
  lock straight, so the trailing leg keeps a natural knee bend through the
  whole stride.
- **Body rotation:** the lead and rear shoulders and hips are separate joints.
  Side-on stances (Bladed, Karate) spread them wide and squared stances stack
  them. Moves rotate too: the jab reaches with the lead shoulder, and the cross
  turns the rear shoulder through.
- **Natural idle:** breathing (the chest rises and falls), slow weight shifts
  between the feet, small guard-hand adjustments, and the head kept level
  toward the opponent.
- **Guard and knees:** every stance keeps at least one hand at the chin and
  both knees bent.
- **Smooth stance changes:** the pose springs into the new stance and the feet
  step into their new spots.
- **Rim glow:** the rival's glow is softer at rest and full during action.
- **Combat personalities:** the player is mobile (faster walk, quick back-off,
  for counter-fighting). The rival is a pressure fighter: it advances
  steadily, backs off slowly and rarely, blocks more and dodges less. Damage and
  frame data are the same for both.

## Animation

- **Moves are keyframe timelines** keyed to the frame data. Kicks follow real
  technique: chamber, extend (hips drive, support leg bent, rear arm
  counter-balancing), re-chamber, then back to stance. Punches have a windup,
  an accelerating strike, follow-through, and a retract.
- **Stance and guard:** boxing stance with a rhythmic idle bounce. The high
  guard tucks the elbows, covers the face with the forearms and drops the chin.
  Blocked hits jolt the guard back and show a guard flash.
- **Jumps:** a deep crouch, toes pointed on the rise, knees tucked at the peak,
  and legs reaching down to land. Air steering works in both directions.
- **Feet stay planted:** crouches come from bending the knees, and the hips are
  placed from leg geometry, so feet never float above the floor.
- **Strikes stop on the target:** a fist or foot never passes through the
  opponent. If it would reach more than a few pixels into the body, the strike
  pulls back along its own windup until it just lands. Up close, punches
  become short hooks and kicks become knee-like jabs. This is presentation
  only: hitboxes are unchanged. Whiffs, high kicks over a crouch, and
  strikes through a dodge keep their full extension.
- **Hit reactions** depend on where and how hard you are hit:
  - light head hits (jab, backhand) are a short flinch with the guard half up;
  - heavy head hits (cross, high kick) whip the head and shoulders back with
    the arms flung;
  - body hits fold the body, lightly or deeply;
  - uppercuts and air hits arch the body back with the arms thrown up;
  - sweeps take the feet away.

  The joint impulses scale with the weight of the hit.
- **Body mechanics:** the cross and uppercut turn the rear heel out as the
  hips drive through. The sweep keeps the body back and lets the leg reach.
- **Leg sweep (S + L),** following the reference sheet:
  1. the body drops onto the bent rear leg;
  2. the lead leg slides out, the torso pitches forward and the lead hand goes
     to the floor for balance;
  3. the straight lead leg sweeps along the floor at ankle height and carries
     on in a low follow-through arc;
  4. the body recovers to the stance.

  A swept opponent has the feet kicked out toward the sweeper and falls onto
  their back.
- **Back kick:** the body turns its back on the opponent through the startup,
  pulls the knee in, thrusts the heel straight back into the target, then
  completes the turn during recovery. This is a visual spin only; gameplay
  facing never changes.
- **Active idle (fighting bounce):** in neutral, both fighters keep moving:
  - a bounce: the hips dip over planted feet, so the knees bend;
  - weight shifts between the feet;
  - heel lifts, with the toes staying on the floor;
  - shoulder roll;
  - torso sway with a level head;
  - small guard adjustments.

  Each stance has its own loop (`Stances.DATA["idle"]`):
  - **boxing:** energetic springy bounce;
  - **Muay Thai:** measured and upright, with the lead heel rising;
  - **karate:** bladed, with long elastic weight shifts;
  - **kung fu:** fluid, hands tracing circles;
  - **grappler:** low and grounded, big slow shifts, heels flat;
  - **counter-fighter:** minimal, sharp settle-and-hold adjustments;
  - **bladed / squared:** mobile hop / heavy rolling pressure.

  Each fighter has its own `idle_tempo` and `idle_phase` (the rival runs at
  0.92× with an offset), so the two never move in sync. The idle starts as
  soon as the guard rises during the countdown. It fades out within a few
  frames when you act, and eases back in over about half a second after any
  action, so recoveries look settled. It also damps as posture fills. It is
  purely visual: the gameplay root, collider and hitboxes never move, and
  input is never delayed. Tunable constants: `IDLE_FADE_IN`, `IDLE_FADE_OUT`,
  `IDLE_POSTURE_DAMP`, `MAX_IDLE_BOB`, `MAX_HEEL_LIFT` in `fighter_visual.gd`,
  plus the per-stance values.
- **Draw order:** the fighter who is attacking is drawn in front, so strikes
  read clearly at impact.
- **Ragdoll:** knocked-down and KO'd bodies become a Verlet ragdoll with
  12 joints, bone-length constraints, joint limits, gravity, and collisions
  with the floor and walls. It blends smoothly back into the get-up
  animation. It is interpolated between ticks, so thrown bodies stay smooth at
  any refresh rate and in slow motion. Throws seed the ragdoll with spin in
  proportion to their force. Trained breakfall rolls stay animated as a curled ball that rolls
  without slipping.
- **Afterimages** trail fast strikes, finishers and flying bodies.

## Audio

All sound is synthesized at startup by `scripts/audio.gd`. There are no audio
files.

- **Sound effects:** whooshes, light and heavy hits, block clack, landing,
  body slam, wall impact, rolling, KO boom, and a finisher gong sting.
- **Music:** a driving fight track at 140 BPM in A minor, 16 bars
  (about 27 s) that loop seamlessly. It has a punchy kick and snare, 16th-note
  hats, a distorted saw bass with octave jumps, taiko accents, and a square-wave
  lead: a stabbing riff for bars 1-8, then a melody doubled by a plucked string
  for bars 9-16. Crashes and drum fills mark the sections. It renders on a
  worker thread in about 1 s, and the music ducks during finishers.
- A hard limiter on the master bus prevents clipping when impacts stack up.

## Physical animation

- Joints act like damped springs, so they overshoot slightly and settle. Hit
  reactions are whippy and knocked-down bodies are floppy.
- If an attack is interrupted, its joint momentum carries into the hit reaction.
- Clean hits apply an impulse to the joints. Head hits snap the head and torso
  back; body hits fold the fighter forward and buckle the knees.
- Strikes follow through slightly past their pose at impact.
- Lying, sitting and crouching are joint poses with the hips locked to the
  floor, so limbs never pass through the ground.

## Developer overlay (F1)

- Green rectangle: hurtbox. Yellow line at the feet: pushbox.
- Orange outline: hitbox during startup. Solid red: active hitbox.
  Grey: active but already spent.
- Labels above each fighter, plus a panel showing tick, hitstop, each
  fighter's state and frame, buffered input, AI state and the last hit event.

## Tests

Headless tests live in `tests/`. Run them all, starting with an import/parse
check:

```bash
GODOT="D:/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_all.sh
```

| Test | Covers |
|---|---|
| `test_core.gd` | Frame data, combos, block / low block, parry (window, whiff, cooldown, low), perfect dodge, cross-up guard, both facing directions, knockdown, dodge, finisher selection and choreography, audio |
| `test_input.gd` | Real key mapping (W+L, S+L, S crouch, double-tap dodge, stance cycling) |
| `test_flow.gd` | Start button, input lock, countdown order and timing, simultaneous unlock, button mashing, restart mid-countdown |
| `test_match.gd` | A full scripted match against the real AI, KO, then restart |
| `test_ai_finisher.gd` | AI finisher on a passive player; result only after the body is at rest |
| `test_ai_defense.gd` | AI blocks most, parries some, punishes a stagger (seeded) |
| `test_styles.gd` | Style registry and validation, Boxing cannot kick, Taekwondo has no boxing combos, air moves and combos follow the style, new moves in both directions, slip counter, AI rivals never use an illegal move |
| `test_movement.gd` | Jump cross-ups (both directions, moving rival, simultaneous jumps, walls), forward/backward roll, close slip-past, walking never passes, back hits after crossing, AI reaction delay |

The V0.3 plan and audit are in `docs/V0.3_PLAN.md`.

## Known limitations

- Single round. No round timer, no best-of-3.
- Hurtboxes are fixed rectangles; they don't follow extended limbs.
- No throws yet (see the grappling note in `docs/V0.3_PLAN.md`).
- At the 60 px minimum distance, forward-leaning torsos can still overlap slightly. Strikes no longer pass through bodies.
- Godot prints a harmless "2 ObjectDB instances leaked" warning on exit,
  because the audio server is still holding the looping music when the engine
  shuts down.
- AI difficulty is set by exported values on the `EnemyAI` node
  (`aggression`, `block_chance`, `reaction_frames`, `jump_in_chance`,
  `anti_air_chance`).
