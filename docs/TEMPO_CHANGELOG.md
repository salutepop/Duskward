# Faster siege iteration: experimental profile

The user requested more monsters, quicker growth and more frequent pressure on 2026-10-24. These are hypotheses to test, not measured success claims. The original `data/balance.json` remains byte-identical to the supplied proposal. The new runtime profile is separately versioned in `data/tempo_profile.json`; historical c86/RC2 results do not validate it.

## First hypothesis (fast-v1)

- Ordinary wave composition: each original nonzero count multiplied by1.35 and rounded to the nearest whole enemy.
- Spawning: initial group of3, then one enemy per0.50s instead of0.90s; existing60-active-enemy safety cap remains.
- Later preparation:8s instead of15s; first preparation still waits for the player and menus still pause solo play.
- Kill rewards:8 gold and15 XP per enemy budget cost instead of6 and12. Wave-clear gold/XP multiplied by1.25, rounded to integer rewards.
- No global speed multiplier. Enemy attack windups, boss warning windows, skill windups/cooldowns, projectile speeds, hero stats, enemy HP/damage growth and item prices are unchanged.
- Two modest AI defenders protect the castle area. They are local NPCs, not multiplayer teammates, and do not intercept siege targeting.
- Optional finite hunting camps on waves4/8 are a solo adaptation, not the original multiplayer expedition system. The castle battle continues; leaving the main approach trades defense time for a small, one-time reward. Exact contract and tests are recorded with the implementation.

## Measurements required before promotion

First enemy contact; levels2/4/6/12; first useful intermediate/advanced purchase; spawn duration and peak live/nearby enemies; interval between meaningful threats; hero/base damage and deaths; legal full-match outcomes across heroes/builds; optional hunt risk/reward versus skipping; AI-only failure and bounded contribution; camp expiry/return/death/wave-clear/defeat precedence and replay-safe rewards; unchanged reaction windows. Human pace and touch comfort cannot be inferred from bot completion alone.

## Support contract (first implementation)

- `defenders`: two killable, stationary castle-side NPCs at(7,10)/(7,14),260HP,14 physical damage per1.2s,6m range,22s respawn. Normal enemies can attack them; siege still targets the castle. They can shoot boss/cores but cannot independently deal120 damage in the four-second core window. Their projectiles never trigger hero crit/lifesteal/passives. Their actual HP damage and deaths/kills are recorded separately; ordinary enemy rewards remain shared and settle once. Preparation restores defenders to full.
- `hunt`: states waiting → available → active → cleared/returning/closed. Waves4/8 offer one camp at(28,6), six seconds after wave start. Reaching2.5m activates only while the hero lives and castleHP is above35%. Activation failure consumes nothing. Activated camps contain3 crawlers+1 guard and expire after25s. Camp enemies have no per-kill rewards, never seek the castle/defenders, leash within5.5m of home, and do not count toward lane completion.
- A successful clear pays120G/100XP once, only after castle-survival and hero-survival checks. Timeout/death beats a pending clear; a living same-tick last camp+lane kill settles camp reward before wave clear. Wave-end closes any remaining camp. There is no respawn/repeat farm within that wave.
- `request_hunt_return()` accepts active or cleared camps only. Two-second channel blocks movement/new basic attacks/new skills, but incoming damage continues and death cancels. Requesting return abandons unfinished reward eligibility, even if an earlier projectile lands during the channel. At castleHP≤30%, an explicit request returns instantly. Return never heals, resets cooldowns, grants invulnerability or saves combat state.
- Lane spawning, AI, hero combat and the castle clock continue during hunting/return. Menus retain their existing solo pause semantics. Checkpoints remain preparation-only and restore both resources and reward timeline, so reload cannot preserve a bounty while replaying its unpaid opportunity.
- Schema4 binds original data + tempo profile + ruleset and persists separate combat/lane/camp RNG states. Old schema1–3 and mismatched profiles reject safely. `Model.new("classic")` exists for comparison/isolated regression only, not as a new player-facing difficulty menu.

## Predeclared pilot targets

With lawful advance/priority input: Ready→first player hit≤8 simulation seconds; levels2/4/6 by20/45/75s; first declared-route intermediate purchase≤70s and advanced purchase≤150s. Median waves2–9 start-to-clear≤35s; review<15s for insufficient decision space. Efficient5–8min full runs are a hypothesis, not a human playtime claim. Flag more than24 enemies within8m and repeated overlapping lethal warnings for review. These targets were shared with independent QA before pilot outcomes and may fail; changes need a dated rationale, not retroactive passing labels.

Before the first pilot, campY moved from4 to6 after the new UI projection showed hero heads overlapping the central HUD atY4. This is a visibility correction, not outcome-driven balance tuning. `lane_gold/xp` includes all ordinary kills; `hero_lane_* + defender_lane_*` reconciles that subtotal. Camp and wave-clear rewards are separate. `hunt_seconds` measures active/channel time, not all physical time away from the castle.

## Correctness fix: spawn schedule (2026-10-24)

Independent tests on9bf28cc found0.50s intervals landing every16 rather than15 ticks at30Hz (last queued first-wave spawn11.2s instead of10.5s). Fast-profile scheduling now uses a small float-boundary epsilon and preserves fractional remainder. Cap-blocked time is discarded as spawn debt, so opening a slot never causes a catch-up burst. The existing simulation/renderer time caps are unchanged. Classic comparison scheduling is intentionally retained. Partition tests cover30Hz,60Hz,0.1s,0.07s, oversized caller delta and a blocked60-enemy queue.

## Correctness fix: defender boss-area participation (2026-10-24)

Independent controlled9bf tests reproduced defenders taking no damage inside the visible boss smash and debris areas, while the hero did. This was an integration omission, not intentional immunity. Live defenders now use the same cone/apex/radius and warning/active windows; they take the existing raw180 smash or35/s debris damage (with the existing enrage snapshot), have no hero armor/item passives, and die/respawn through their normal policy. Outside-area and warning-only controls stay safe. Cannon damage remains castle-only. Dead defender targets do not redirect attacks to the castle, and already-launched allied shots keep their existing short lifetime without hero procs.

## Hard-v2 composition hypothesis (2026-10-24, pre-pilot)

The user then explicitly requested substantial difficulty and control-dependent play, not simply faster/easier growth. The predeclared table in `data/tempo_profile.json` has22/28/32/36/40/43/46/49/52/56 enemies, skirmishers from wave1, shooters/guards from wave2 and siege from wave3. Camp waves4/8 carry2/4 siege enemies. Queue shuffle remains seeded; first spawn/contact by kind must be measured rather than assumed from a wave number.

Total budget770 versus fast-v1's611 and original450. Per-cost gold returns to6, but total ordinary earned gold remains5465 (4620 kills+845 rounded clear rewards), versus5733 in fast-v1 and3375 in the original. Thus it is only a4.7% reduction from fast-v1, still61.9% above original, while budget pressure rises26%. It is not a reversion of total growth. XP remains15/cost with1.25×clear rewards. Original data and the first experimental profile are retained separately; unchanged warnings, clocks, hero/item stats and individual enemy scaling remain explicit.

Predeclared seeds101/202/303/404/505/606 compare inactive, stationary-auto, moving-basic, wasteful-skill, basic-dodge and priority/interrupt/return policies. Initial calibration targets: no inactive/stationary full victories, moving-basic≤1/6 victories per hero, priority≥2/6 per hero plus two coherent guardian builds, and≥1/6 with250ms delayed/noisy input. These are small-sample hypotheses, not population win-rate estimates. A full-state scripted policy is not a human player; all-priority wins do not alone justify arbitrary nerfs. Track early choice affordability, unused gold/stat caps, lane leakage, reaction opportunities and visual density. Existing fast-v1 results are not reattributed to hard-v2.

## Correctness clarification: unchosen hunt opportunities (2026-10-24)

A controlled red/green regression found death cleanup closing waiting/available camps before activation, including before the six-second offer was visible. That silently consumed a choice the player had not made. Unactivated opportunities now survive hero death until their normal wave-end lifetime. Once activated, death still consumes the opportunity; partial rewards, replay farming and return invulnerability are not added. Existing activated timeout and wave-end closure remain. The 21-assertion lifecycle test reproduces the original failure (eight cascading assertion failures from this one behavior), then verifies actual respawn, first activation, activated death, second-respawn no-replay, timeout and unactivated wave-end controls. This is a correctness change, not a numerical difficulty adjustment. The initial hard-v2 pilot remains bound to its pre-patch source.

## Explicit optional-hunt input (2026-10-24)

The camp entry radius overlaps some upper-lane movement. Independent pilot traces showed incidental activation during ordinary pursuit/avoidance, so proximity alone did not represent a deliberate optional choice. The opt-in revision removes automatic activation: a fresh nearby `hunt_start` action is required. Pure `can_start_hunt()` shares the existing phase, life, distance, castle-HP and capacity conditions with `start_hunt()`. Rejected or repeated requests do not consume/spawn/pay anything. No confirmation popup, extra fee or combat-number change is added. The UI explains approach then tap and guards old movement/skill releases, stale targets and changed eligibility.

The profile identifier becomes `0.3.0-hard-v2-optin`; previous proximity-profile bytes are retained as `data/tempo_profile.hard_v2_proximity.json`. Schema4 remains, but the profile hash/version explicitly rejects old-profile checkpoints. Pre-opt-in incidental-hunt outcomes remain historical rather than being silently assigned to this interaction contract. New full matches must bind the new source.
