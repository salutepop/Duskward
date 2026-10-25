# Runtime QA and evidence boundaries

## Native model tests

Use `./tools/run-tests.sh` for the developer suites on Linux/macOS (or set `GODOT_BIN` to the Godot executable). It imports bundled resources, creates isolated temporary HOME/XDG directories, retains logs and fails on engine/script errors as well as test exit failures. It does not overwrite a player's saved game. The individual commands below require equivalent isolated user-data directories.


Run these with Godot 4.6.3 and a separate writable user-data directory:

```
godot --headless --path . --script tests/model_smoke.gd
godot --headless --path . --script tests/model_regression.gd
godot --headless --path . --script tests/rng_streams.gd
godot --headless --path . --script tests/checkpoint_validation.gd
godot --headless --path . --script tests/checkpoint_resources.gd
godot --headless --path . --script tests/presentation_clock_controls.gd
godot --headless --path . --script tests/presentation_layout.gd
godot --headless --path . --script tests/presentation_results.gd
```

The smoke test plays real default-profile combat with legal initial purchases. `model_regression` deliberately isolates the original classic encounter profile for unchanged combat-formula fixtures; it does not validate the new default difficulty. Separate suites cover the exact hard-profile catalog, finite hunts/killable defenders, boss-area damage to defenders, spawn partition/remainder/cap behavior, three RNG streams, profile-bound checkpoints and exact-resource recovery. Presentation suites cover clocks, analog mapping, geometry, results and redesigned UI. Assertion counts are reported by each exact source run rather than kept as a stale aggregate here.

`spawn_schedule` includes per-tick assertions: thousands of checks do not mean thousands of independent gameplay situations. Controlled fixture injection is distinguished from legal play. The independent QA package separately snapshots source, audits scripted policies, executes lawful full matches with normal economy and records source hashes/outcomes. Historical c86/RC2 results belong only to their earlier model/profile, not to the current experiment.

The active hard-v2 profile's initial six-seed policy comparison and tempo/growth/density targets are recorded before outcomes in `docs/TEMPO_CHANGELOG.md`. A scripted full-state policy is not a human difficulty or touch-comfort measurement. Optional hunting must be compared with skipping, brief visits and overstaying; AI-only survival and reward attribution are separate checks.

## Optional debug autoplay

Normal launches remain human controlled. Autoplay requires both a Godot debug build and one explicit whitelisted user argument:

```
godot --path . -- --qa-autoplay=guardian:priority
godot --path . -- --qa-autoplay=ranger:aggressive
godot --path . -- --qa-autoplay=arcanist:aggressive
godot --path . -- --qa-autoplay=ranger:hunt
```

Only the three known hero IDs and the fixed aggressive/priority/hunt policies are accepted. Controller revision3 retains the hunt integration policy; the earlier aggressive/priority strategy paths remain distinct and retain their conservative legacy heuristics. The controller does not accept code, URLs, credentials, scripts or resource amounts. It never persists the enabled state. An obvious QA AUTOPLAY badge stays visible throughout and after the run.

The controller observes the simulation but acts only through ordinary menu/catalog hitboxes and `Viewport.push_input` touchscreen events. It never calls simulation step, reset, buy, cast, health/gold grants, or time-scale controls. The actual scene advances through its ordinary, unmodified render-frame processing; this is not a guarantee that simulation keeps pace with wall time on a slow device. It stops on victory/defeat, a bounded 1800-simulation-second inconclusive limit, or an actionable QA error. A deliberate user/lifecycle pause is not silently dismissed.

Structured `QA_AUTOPLAY_*` log records and a `user://qa_autoplay_<hero>_<policy>.json` result record include simulation/wall time, seed, source identity, legal inventory, combat metrics, synthetic event count and the explicit statement that physical touch was not tested.

### Fixed hunt integration policy (controller revision 3)

The opt-in `hunt` policy is for exercising the visible solo-support loop, not a difficulty benchmark or an optimal player. It uses normal displayed purchase quotes on a disclosed richer-equipment route, normal skills, joystick events and the actual `hunt_start`/`hunt_return` hit targets. It never activates by setting model state. Each offered wave permits one planned trip. Entry requires castle HP strictly above60% and hero HP at least55%; those conditions are rechecked during an at-most8-simulation-second approach. Once active, clear/10seconds/castle≤60%/hero≤35% prompts the ordinary unsafe return. Skipped/aborted trips are not retried that wave.

Decision records include chosen/aborted approach, actual accepted start and return timestamps, return reason and observed closure. These are controller observations, not invented rewards. Camp failure, death, timeout and full-match defeat remain valid recorded outcomes. The UI/model still controls legality, pause, cooldowns, damage and time. The policy does not dismiss a human/lifecycle pause, does not know future spawns, and does not remove the emulator's ordinary slowdown. The original numerical-profile pilot and independent hunt/skip/overstay comparisons use separate source-bound harnesses.

Revision3 changes only the `hunt` combat policy: guardian approaches to0.8m while retaining shipped assisted taps; the arcanist approaches a ready/affordable boss ultimate to its actual body-radius reach; visible boss smash escape uses the locked cone and holds the chosen exit through that warning. Guardian/ranger dash attempts are suppressed during that escape. These are explicitly versioned controller corrections, not hero-stat buffs or human-play changes. The close-stance mechanism comparison and visible-geometry regressions motivated them; no final-match success is implied by adopting the rules. Legacy aggressive/priority policies retain their prior positioning, R gate and dodge heuristics for historical comparisons.

### Android artifact separation

Godot 4.6.3 deliberately does not honor arbitrary command-line extras from an exported Android launcher intent. Do not bypass that restriction. Long rendered tests use a separately named, visibly labeled, debug-only QA APK with the supported export extra-args option baked in. Its application identity and exact config/hash differences must be recorded separately from the normal APK.

The normal delivery APK has no baked autoplay flag and is tested independently using Android OS input and lifecycle operations. A full match in a QA variant is evidence for that variant's runtime/rendering behavior, not a claim of byte-for-byte full-match testing of the normal binary.

The build process may add `data/build_info.json` to an immutable export snapshot with the original source commit and artifact variant. The controller reports `development-unbound` if that identity file is absent rather than inventing provenance.

## Visual and device limits

Headless execution can exercise real scene/input code and detect drawing errors, but does not establish image quality. Rendered screenshots can establish visible composition/clipping, not human touch comfort. Android emulator tests can establish installation/runtime/lifecycle paths, not representative physical-device GPU performance, thermals, battery life or every Android model.

Characters currently use original generated sprite illustrations with procedural movement, flashes and attack/death effects, not a full production frame-animation library. No Warcraft assets are used. The source data is the supplied proposed balance catalog; successful bots do not make all item routes equally competitive.


## Slow-frame clock accounting

The mobile prototype intentionally admits at most 150 ms of active frame time into its 30 Hz simulation per rendered frame. This preserves bounded response after a stall instead of bursting through enemy warnings. It is an explicit adaptation from the design's backlog-preserving clock: at extreme low frame rates, simulation slows relative to wall time. This is not hidden acceleration, and a long rendered run must not be described as verified real-time performance merely because it finishes.

`main.clock_metrics()` reports active Godot frame delta, separate monotonic active time, admitted/completed simulation time, fractional remainder, dropped active time, capped-frame counts and pause/background time. New game/load deliberately resets the old fractional remainder and records it. QA heartbeat/result records include these diagnostics; the controller never changes the clock policy. Synthetic test deltas and actual monotonic timing are separate evidence categories. Title/menu/background time must not be counted as active dropped time.

## Analog movement convention

Joystick direction is inverse-projected from the rendered arena into world space, then normalized and multiplied by the original stick magnitude. Thus a diagonal thumb drag points along the displayed motion, while half deflection produces half intended world speed in every direction. The existing dead zone remains; no input smoothing or artificial delay is introduced. The redesigned 1280×640 battlefield now has a uniform projection for the 48×24 world; the inverse-direction mapping remains valid if a future viewport changes that ratio.


## Same-frame input snapshot safety

Hit targets describe the last painted view; they are not authority to act after navigation. View/page/run/phase transitions and item selection invalidate that snapshot, and actions also validate their current menu context. A successful purchase invalidates old targets when the quoted cost, consumed components or availability changes. Stable same-item/price purchases can still repeat without an arbitrary timing debounce. Independent public-Viewport input regressions cover close-shop → hidden Buy, page/item/start transitions, help-page controls, discounted recipe quotes and a valid same-frame double-potion purchase. The exact source-bound results belong in the QA report, not inferred from this design note.

## Result metric semantics

The presentation-only result summary reads existing counters without changing combat, saves or random streams. `completed_wave`, `deaths` and `cannons_cancelled` count completed waves, actual hero deaths and actual boss-cannon interruptions. `elapsed` is accumulated simulation time including active preparation and boss introduction, excluding paused/menu/background time; it is not wall time. Reloading a preparation checkpoint restores its elapsed timeline, so discarded combat attempts are not accumulated into this number. `base_damage_by_kind` and `base_damage` record incoming castle damage, including terminal overkill and additional same-tick damage. They must not be relabeled as actual HP loss or prevented damage. The top two positive source totals plus Other preserve the unrounded aggregate; visible numbers are only display formatting. Durations at or above100 hours use the explicit lower-bound label `100시간+` to avoid huge loaded values overflowing or clipping; the helper retains the original simulation seconds. Enemy `damage_dealt` is separately capped at actual enemy HP loss, so these metrics do not share one universal damage definition.
