# Implementation coverage and honest limits

This is the offline Android **solo first-complete-version** interpretation of the supplied design, not an implementation of every future multiplayer/expedition expansion chapter.

## Delivered runtime systems

| Specification area | Current implementation |
|---|---|
| Engine / platform | Godot 4.6.3, Compatibility, landscape Android; standard GDScript |
| Core objective | Ten ordinary waves followed by one boss, castle defeat prioritized over same-tick victory |
| Heroes | Guardian, Ranger, Arcanist with their original base/growth values |
| Skills | All Q/W/E/R definitions, level gates, costs, windup reservation and commit, cooldown reduction, auto-aim |
| Guardian | Cone cleave, shield/taunt excluding siege/boss, capped-distance dash/slow, eight moving pulses |
| Ranger | Swept-hit arrows, actual-hit third-strike passive, piercing line, armed traps, backstep/haste, six-second bonus and secondary fire |
| Arcanist | Area burst, shield, four slow/damage pulses, area damage/self-heal, gated multi-target energy passive |
| Items | 8 basic, 9 intermediate, 6 advanced, 1 potion; all original prices and recursive recipes |
| Economy | 300 starting gold, explicit profile-based kill and wave rewards, six slots, atomic component consumption, 60% sell values |
| Item effects | Crit/attack speed/CDR caps, highest-source lifesteal with actual-HP and rolling cap, fortress DR, sanctuary shield persistent cooldown |
| Enemy AI | Hero acquisition/leash, base priority for siege, shooter retreat, melee windup, swept ranged projectiles, soft separation |
| Waves | Hard-v2 compositions, original per-enemy HP/damage scaling, remainder-preserving spawn queue and cap; clear exactly once; 3% castle repair |
| Solo support | Two killable local castle defenders; finite one-reward camps on waves 4/8; unsafe return channel while lane combat continues |
| Boss | 18,000 HP, resistances20, four-second120HP core interrupt, cone smash, warning/debris areas, two reinforcement thresholds, bounded enrage |
| Death | Wave-based respawn, resource restoration, initial protection, death cancels uncommitted/personal persistent effects |
| Saves | Content-bound preparation checkpoints, temporary write/check/rename, backup, boss restart from final preparation |
| UI | Korean hero selection, mobile joystick and skill controls, readable HUD, catalog/shop, help, pause/back/restart and results |
| Assets | Newly generated GPT Image environment and icon/character sheets; original procedural effects; licensed Korean font |

## Explicit adaptations and exclusions

- Basic attacks commit immediately when their interval is ready and continue while moving. This is a deliberate joystick/auto-attack mobile adaptation, not the desktop design's movement-cancellable preparation/commit/recovery cycle. Enemy attack warnings and skill windup/resource rules are retained.
- Ranger Q is an instantaneous piercing line shot with matching beam feedback, not a traveling piercing projectile with a lifetime hit-set. Ordinary ranged basic attacks do travel and use swept collision.
- Mobile quick taps use assisted targeting; deliberate skill-button drags provide manual direction/ground aim with an explicit cancel zone. This replaces desktop RTS mouse commands.
- First preparation waits for the player. Later preparation lasts 8 seconds; viewing menus pauses the solo simulation. Equipment transactions are preparation-only in this prototype; the specification's in-combat shop-radius transactions are not implemented.
- Potions use a separate three-item reserve so the six combat equipment slots stay readable and useful on phones.
- Arena navigation is an open single solo approach, not three obstacle-heavy networked lanes or a navmesh pathfinding showcase.
- Network co-op, host migration, anti-cheat/AFK reward policy, the full multiplayer expedition system, counteroffensive expansion, social features and ranking are excluded from the offline build.
- Active render-frame delta is capped at 150 ms before fixed stepping. Extreme low FPS therefore slows game time; explicit clock diagnostics expose this instead of claiming backlog-preserving real-time behavior.
- This build uses floating-point local simulation with an explicit seed and fixed step, not a cross-platform deterministic integer lockstep network implementation.
- Damage/event ordering is locally stable and tested for supported cases; it does not claim the full production multiplayer event-sourcing architecture.
- Accessibility/options remain limited: fixed tested text sizes and controls, a sound on/off toggle, and no player-adjustable UI scale, per-channel volume sliders, remappable touch controls, or shake/flash/damage-number sizing options. These are deferred presentation features, not silently completed specification requirements.
- Compact results report completed waves, deaths, cannon interruptions, simulation time and recorded incoming castle damage by source. They do not claim damage prevented, exact HP loss, control/healing contribution, time spent dead, or the specification's full per-wave failure analysis.
- Runtime model tests, automated bots, desktop rendering and Android emulator checks are different evidence categories. None proves physical-touch feel, thermal/battery performance or all-device compatibility.

## Profile and save transition

The active 0.3.0 hard-v2 experiment is a deliberate response to the requested faster, control-dependent game. Original data remains unchanged; `data/tempo_profile.json` changes composition/rewards/pacing and adds local support. Schema 4 binds that profile and three RNG streams. Earlier schema 1–3 and other-profile saves reject safely. See `docs/TEMPO_CHANGELOG.md` for predeclared hypotheses and exact deltas. Historical c86/RC2 results do not validate the new profile.

## QA status

Developer suites include original-formula isolated combat fixtures, default-profile first-wave play, profile catalogs, support lifecycle/geometry, partitioned spawning, RNG, checkpoints and UI. Controlled checks are not full difficult-play acceptance. Independent QA separately reports source-hashed contract and combat results and legal full-match policies. This file is a scope record, not a claim that final APK acceptance is already complete; consult the final dated QA artifact.
