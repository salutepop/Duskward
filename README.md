# DUSKWARD · 황혼의 성채

A real offline, single-player hero siege game for Android, built in Godot 4.6.3 with GDScript and the Compatibility renderer. There is no login, advertising, payment, API key, telemetry, or runtime network dependency.

한국어 플레이 안내: [`docs/PLAYER_GUIDE_KO.md`](docs/PLAYER_GUIDE_KO.md).

## Play

Defend the castle through fifteen waves, then defeat the Rampart Breaker. Move into range to attack automatically. Spend gold between waves on equipment; higher-tier equipment automatically consumes eligible components and charges only the remaining recipe cost. Six equipment slots and a separate three-potion reserve are available. The castle is the loss condition, not the hero: a fallen hero respawns while enemies continue attacking.

- Android: landscape. Left stick moves; quick taps on right buttons cast Q/W/E/R with target assistance; drag a skill button to aim manually or into the cancel zone to cancel. Tap the vial to drink a potion. Gold cores interrupt the boss's four-second cannon attack; striped red ground attacks must be dodged.
- Desktop: WASD or arrows move; 1/2/3/4 cast all four skills. Q/E/R are alternate casts; W remains movement. Space drinks a potion. B opens equipment; Escape pauses/back; Enter starts the next wave in preparation.
- Equipment transactions happen only between waves. Opening the shop pauses this solo game. Backgrounding the application pauses and releases touch input. Return from the pause menu to resume deliberately.
- Checkpoints are saved at preparation boundaries and after shopping. Leaving during combat restarts from the previous preparation checkpoint; leaving during the boss restarts final preparation. This is not mid-combat save/restore.

The experimental 0.3.0 checkpoint format (schema 5) separates combat, lane and camp random streams, preserves exact HP/mana, and binds the active tempo profile. Older prototype schema 1–3 or different-profile checkpoints cannot be continued; the game explains the incompatibility and a new game remains available. See `docs/TEMPO_CHANGELOG.md`.

## Scope

Implemented: three selectable heroes, fifteen skills, all twenty-eight catalog items with recipes/stats/unique effects, eight ordinary enemy types, fifteen explicitly budgeted waves, destructible boss cores and three telegraphed boss patterns, reinforcement thresholds/enrage, levelling with growth points (skill ranks or stat allocation), death/respawn, healing, checkpoint save/restore, pause/restart, and win/loss.

Deliberate mobile/solo adaptations: fixed twin-hand touch controls and assisted aim rather than RTS mouse commands; one open arena rather than multiplayer lanes; unlimited first preparation rather than a thirty-second first-purchase countdown; a separate potion reserve instead of consuming an equipment slot. Two killable local castle defenders and finite optional hunts on waves 4/8 adapt the side-objective concept to solo play; the castle battle continues during a hunt. These are not multiplayer teammates or the supplied document's full expedition system. Multiplayer networking, counteroffensive expansion and online features are not included.

`data/balance.json` keeps the supplied 24-item catalog unchanged and appends additional set-effect items. The active experimental `data/tempo_profile.json` separately changes wave composition, spawn pacing and rewards: all eight enemy roles are scheduled across fifteen waves, growth follows the catalog's twelve experience per cost, ordinary preparation is six seconds and the boss preparation is fifteen. Hero/item stats, individual enemy HP/damage scaling and attack warnings are unchanged. The historical fast-v1 profile is preserved separately. These changes are hypotheses under fresh validation, not proof that the game is difficult or balanced. Passing tests does not establish that every build is equally competitive or that every phone performs well. Balance and touch ergonomics require measured playtests. See `IMPLEMENTATION_COVERAGE.md` and the accompanying QA report for specific verified and unverified claims.

## Run from source

Use `./tools/run-tests.sh` for the developer suites on Linux/macOS (or set `GODOT_BIN` to the Godot executable). It imports bundled resources, creates isolated temporary HOME/XDG directories, retains logs and fails on engine/script errors as well as test exit failures. It does not overwrite a player's saved game. The individual commands below require equivalent isolated user-data directories.


Install Godot **4.6.3 standard** (not .NET), then open `project.godot` and press Run. Assets and Korean font are bundled. The editor imports resources the first time.

```
godot --path .
godot --headless --path . --script tests/model_smoke.gd
godot --headless --path . --script tests/model_regression.gd
godot --headless --path . --script tests/rng_streams.gd
godot --headless --path . --script tests/checkpoint_validation.gd
godot --headless --path . --script tests/checkpoint_resources.gd
godot --headless --path . --script tests/presentation_clock_controls.gd
godot --headless --path . --script tests/presentation_layout.gd
godot --headless --path . --script tests/presentation_results.gd
```

If the host's home directory is not writable, set `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME` to writable test directories first. Tests use `user://`; use a separate data directory to avoid replacing a real player's checkpoint.

The independent QA suite outside this source package additionally exercises snapshot-based contract/combat, complete no-cheat bot matches and target-device flows. Test-state injection is labeled separately from legal full matches.

## Android export

Use exactly matching Godot 4.6.3 standard Android export templates and an official Android SDK/JDK. The included non-Gradle `Android` preset has no network permissions and supports ARM64 plus x86_64. The current template requires Android 7 / API 24 or later and targets API 36. The prototype APK is debug-signed for sideload testing, not a Google Play production release. Never redistribute a private keystore or credentials.

Export after configuring the editor's Android SDK/JDK paths and a local debug signing identity:

```
godot --headless --path . --editor --import --quit
godot --headless --path . --export-debug Android /absolute/path/Duskward-debug.apk
```

## Architecture

- `scripts/siege_model.gd`: authoritative deterministic-seeded simulation, combat, enemy and boss AI, transactional economy, checkpoints. No scene-tree/rendering dependency.
- `scripts/main.gd`: landscape rendering/UI, real multitouch input, pause and lifecycle behavior, simple original generated sound effects.
- `scripts/art.gd`: illustration integration and original procedural visual effects.
- `data/balance.json`: unchanged original data catalog. `data/tempo_profile.json`: active separately versioned experimental encounter/reward/support profile; both bind saved checkpoints.
- `data/ui_ko.json` / `scripts/ui_copy.gd`: Korean presentation catalog; stable simulation/save IDs are not translated.
- `tests/`: runtime Godot tests. Effects and model state are observable for independent QA.

The redesigned battlefield fills the device with a uniform world projection over a 1280×720 design box that expands to the screen aspect. World coordinates are meters in a 96×48 arena tracked by a clamped following camera; simulation steps at 30 Hz. Small solo populations permit straightforward target ordering and separation; this implementation is not a promise of network lockstep or the design document's 150-active-enemy/co-op performance envelope.

## Credits and licenses

Godot Engine: MIT license, https://godotengine.org/license/ . Full engine and bundled-component notices are included in `licenses/`. Original game code and procedural artwork created for this project. New illustrations generated with GPT Image for this project, not taken from Warcraft or other games. The current Korean UI uses bundled Pretendard Medium/SemiBold under SIL Open Font License1.1; unmodified font source hashes and rendering notes are in `assets/fonts/SOURCES.md`, and the full license is in `licenses/PRETENDARD_LICENSE.txt`. The historical Noto Sans CJK font and its license remain bundled for baseline comparison. See `assets/FONT_LICENSE.txt` and `assets/art/README.md` (the exact font license filename may be included beside the font).
