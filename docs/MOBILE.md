# Mobile version: status (2026-10-30)

## Done in the game

- **Touch controls** (`scripts/touch_controls.gd`), first draft of your design (2026-10-30):
  - **Joystick**, bottom-left, 8 clock directions, screen-relative:

    | Joystick | Result |
    |---|---|
    | 12 quick flick | Jump straight up |
    | 12 hold + J/K | W+J / W+K |
    | Beyond 12 (extra upward travel past the ring) + J/K | Space+J / Space+K |
    | 2 / 10 | Jump right / left |
    | 3 / 9 | Walk right / left; a double flick dashes |
    | 6 hold | Crouch; 6 + J/K is S+J / S+K |
    | 6 → 4 / 6 → 8 flick | Roll right / left |

    A roll needs 6 held for a moment first, so it isn't triggered by accident.
  - **Buttons:**
    - J / K / L are clustered at the bottom-right, with a wide BLOCK pill under them. Hold BLOCK to block; a fresh
      press parries.
    - X is smaller and sits above the cluster, with a cooldown sweep.
    - F appears with a pulsing glow only at full Focus.
    - Buttons are about 40% opaque at rest and brighter while pressed.
    - The centre of the screen is kept clear.
  - **Behaviour:**
    - Every finger is tracked separately (multi-touch).
    - The controls press the same input actions as the keyboard, so all nine styles keep their own move mappings.
  - **Tuning:** the values to prototype are near the top of `touch_controls.gd`. They are the dead zone, the
    beyond-12 distance, the flick window, the roll hold, and the button positions and sizes.
- **Testing on PC:** turn on SETTINGS → TOUCH CONTROLS to see the buttons and press them with the mouse.
- **Menus** are ordinary buttons, so taps work on them already. This includes style select, START MATCH, AI difficulty,
  TRAINING, TUTORIAL, SETTINGS, PAUSE, REMATCH and CHANGE STYLE.
- **Already mobile-ready:**
  - The renderer is GL Compatibility, which runs on most Android phones.
  - The game is landscape at 1280×720, with `canvas_items` stretch and `keep` aspect.
- **Test:** `tests/test_touch.gd`. It drives every joystick gesture and button with real touch and drag events.

## Needed to build an Android APK (not installed on this PC)

1. **Godot 4.7.2 export templates:** in the editor, Editor → Manage Export Templates → Download.
2. **JDK 17 and the Android SDK:** Android Studio installs the SDK. In Godot, set both paths under Editor Settings →
   Export → Android.
3. **Android export preset:** Project → Export → Add → Android.
   - Screen orientation: landscape.
   - Leave the GL Compatibility renderer on.
   - Godot generates a debug keystore. A Play Store release needs your own keystore.
4. **Export** the APK, or use one-click deploy to a USB-connected phone.

Steps 1 and 2 are multi-gigabyte downloads, so they were left for you to start.

## Still open

- **Real-phone check:** button size and placement for thumbs, the beyond-12 distance, performance on a mid-range phone,
  and the notch / safe area.
- **Later:** an Edit mode for control size and opacity.
- **Pausing:** done. Android's back button pauses and resumes a fight, as P / Esc do.
- **Controller:** done, with default bindings (see `GameSettings.JOY_BINDINGS`). The d-pad or left stick moves, A
  jumps, X / Y / B are light / heavy / technique, RB blocks, LB is X and RT is the signature. START confirms, starts,
  rematches or pauses; SELECT cycles the style. Pad buttons can't be remapped yet.
