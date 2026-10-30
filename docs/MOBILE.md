# Mobile version: status (2026-10-30)

## Done in the game

- **Touch controls** (`scripts/touch_controls.gd`)
  - A direction pad on the left: ◀ ▶ ▲ ▼.
  - Buttons on the right: LIGHT, HEAVY, TECH, JUMP, BLOCK, X and SIG.
  - Each button presses the same input action as its keyboard key, so combat behaves identically.
  - Two-finger chords work: ▲ + LIGHT is W+J, ▼ + BLOCK is a low block, JUMP + LIGHT is a power move.
  - Double-tapping a direction dodges.
  - The buttons show during fights, training and the tutorial on any touch-screen device.
- **Testing on PC:** turn on SETTINGS → TOUCH CONTROLS to see the buttons and press them with the mouse.
- **Menus** are ordinary buttons, so taps work on them already. This includes style select, START MATCH, AI difficulty,
  TRAINING, TUTORIAL, SETTINGS, PAUSE, REMATCH and CHANGE STYLE.
- **Already mobile-ready:**
  - The renderer is GL Compatibility, which runs on most Android phones.
  - The game is landscape at 1280×720, with `canvas_items` stretch and `keep` aspect.
- **Test:** `tests/test_touch.gd`. It presses the buttons with real screen-touch events, including a two-finger chord.

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

- **Real-phone check:** button size and placement for thumbs, performance on a mid-range phone, and the notch / safe
  area.
- **Pausing:** the PAUSE button works by tap. Android's back button should probably also pause the game; this is not
  wired yet.
- **Controller support:** still open (REVIEW-05).
