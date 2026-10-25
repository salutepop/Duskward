class_name RngManager
extends RefCounted
## Helper for seeding independent RNG streams used by combat, spawn, and camp logic.

static func seed_all(rng: RandomNumberGenerator, spawn_rng: RandomNumberGenerator, camp_rng: RandomNumberGenerator, base_seed: int) -> void:
	rng.seed = base_seed ^ 0x434F4D424154
	spawn_rng.seed = base_seed ^ 0x535041574E
	camp_rng.seed = base_seed ^ 0x43414D50
