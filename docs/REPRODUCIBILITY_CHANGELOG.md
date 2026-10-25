# Controlled reproducibility change: 0.2.0

The Android renderer diagnosis remains pinned to commit 5aa3c3b258a25a0e2be26bae0e4524f218c8bb27 (0.1.0). Its APKs, native outcomes and source snapshots are unchanged.

The 0.2.0 development iteration separates random-number streams:

- Spawn stream: wave-order shuffling, spawn-position jitter and initial enemy attack-timer offsets.
- Combat stream: critical rolls.
- Both streams derive deterministic, distinct seeds from the visible match seed.
- Both states are serialized and restored. Checkpoint schema is explicitly 3. The intermediate, unexported stream-split iteration used schema 2.

Old schema 1 and 2 prototype checkpoints are intentionally rejected, including their backup, rather than inventing missing random/resource state and pretending the old match continues identically. Start a new game after upgrading from 0.1.0. This is a prototype checkpoint-format break, not lost server/cloud data; all saves are local.

No hero, enemy, item, wave, reward or skill numeric balance value changes in this iteration. However, new seeded combat outcomes can change because the random streams changed. Previous 0.1.0 win rates and timings must not be attributed to 0.2.0. Fresh source-bound runtime and full-match tests are required before promoting this branch to an Android delivery candidate.

`tests/rng_streams.gd` checks actual scheduler order/position/initial-attack-offset invariance after 1000 unrelated combat RNG draws, both-stream checkpoint continuation and explicit rejection of legacy checkpoints. It is a controlled deterministic test, not a new balance study.

This stream split does not make action-divergent encounters identical or prove a causal skill-ablation result. Player decisions still change movement, kill timing, attack counts, boss phases and subsequent combat outcomes. It isolates initial spawning randomness from unrelated combat draws; stronger causal claims would need a separately designed experiment.

## Geometry correction in the same controlled iteration

Independent intended-situation QA found that a hero exactly overlapping the boss could avoid its smash because normalizing a zero-distance vector produced no valid facing direction or cone inclusion. The 0.2.0 branch defines a deterministic left-facing lock fallback and includes the hero's 0.6 m body radius at the cone apex. Damage 180, 1.2-second warning, 7 m radius and normal dodge windows remain unchanged. Fresh contextual regression and full-match checks are required; old outcomes are not reused as validation.


A related chained-state case also preserves the player's existing facing when a basic attack hits a coincident target. This prevents a later ranger backstep from receiving a zero direction. An explicit deterministic right-facing fallback covers a missing direction; ordinary damage and movement distances are unchanged.

## Corrupted checkpoint recovery

A nested malformed metric could previously pass shape-only checkpoint validation and cause a script error on the next basic hit. The validator now checks finite, nonnegative counter values, integral count/state fields, wave-history records and the four known cooldown slots. It restores only known metric fields. A damaged primary checkpoint can still recover from a valid backup; when both are invalid, loading rejects them without mutating the current run. `tests/checkpoint_validation.gd` exercises rejection, backup recovery and actual combat after recovery. This is defensive file validation, not a change to the economy or player progression.

A follow-on recovery → save → primary-corruption regression also verified backup retention. Saving now copies only a validated prior primary into the backup, so a successful recovery cannot overwrite the known-good backup with the damaged file it recovered from.


## Exact preparation resources (schema 3)

A lawful max-HP equipment purchase raises maximum HP without healing current HP, as required by the design. Previously, loading that preparation checkpoint refilled resources and could grant extra health. Schema 3 persists exact current HP and energy. Validation computes maximum resources using the same derived-stat helper as live play, rejects out-of-range resources before mutating the current run, and preserves exact values through backup recovery. Buying, selling and reloading cannot create healing. Schema 1 and the intermediate, unexported schema 2 are explicitly incompatible; start a new game. No item price/stat or ordinary combat value changed.
