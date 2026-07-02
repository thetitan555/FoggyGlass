class_name RngState
extends RefCounted

## Deterministic, seeded RNG that lives INSIDE serialized sim state (Tenet 1,
## simulation.md → SimState.rng, criterion 4).
##
## Any randomness the sim ever draws comes from here, and its full state (seed +
## current internal state) is part of the SimState snapshot — so a restored
## snapshot re-draws the identical sequence, and no unseeded / wall-clock
## randomness ever enters gameplay (simulation.md criterion 4).
##
## ALGORITHM. SplitMix64 — a tiny, well-distributed 64-bit generator with pure
## integer ops (add / xor / shift / multiply), fully specified and identical on
## every platform for a given seed. No Godot RandomNumberGenerator (its internal
## state and advancement are not part of our serialized graph and not guaranteed
## stable across engine versions), no floats. GDScript ints are 64-bit and wrap on
## overflow, which is exactly SplitMix64's intended behavior.
##
## SCOPE. P0's `step` draws no randomness yet, but the RNG is part of state from
## the start (simulation.md lists it as a top-level field) so that (a) determinism
## is provable end-to-end now and (b) later systems that need randomness draw from
## an already-serialized, already-round-tripping source rather than bolting one on.

## The immutable seed this generator was created with (kept for the record /
## reproducibility; the live sequence advances `_state`, not this).
var seed: int = 0

## The current internal 64-bit state. Advances on every draw. Part of the snapshot.
var _state: int = 0

# SplitMix64 constants (the canonical values).
const _GOLDEN: int = -7046029254386353131   # 0x9E3779B97F4A7C15 as signed 64-bit
const _MIX_A: int = -4658895280553007687     # 0xBF58476D1CE4E5B9
const _MIX_B: int = -7723592293110705685     # 0x94D049BB133111EB


func _init(initial_seed: int = 0) -> void:
	seed = initial_seed
	_state = initial_seed


## Advance the generator and return the next 64-bit value (signed; the full 64-bit
## pattern is the random value). Pure integer SplitMix64. Deterministic: identical
## `_state` in always yields the identical value and next `_state`.
func next_u64() -> int:
	_state = _state + _GOLDEN            # wraps at 64 bits (GDScript int semantics)
	var z: int = _state
	z = (z ^ (_unsigned_shift_right(z, 30))) * _MIX_A
	z = (z ^ (_unsigned_shift_right(z, 27))) * _MIX_B
	z = z ^ _unsigned_shift_right(z, 31)
	return z


## Logical (unsigned) right shift on a 64-bit int. GDScript `>>` on a negative int
## is arithmetic (sign-extends), so mask after shifting when we need the unsigned
## behavior SplitMix64 specifies. For shift n in 1..63 this clears the top n bits.
static func _unsigned_shift_right(v: int, n: int) -> int:
	# Shift, then clear the sign-extended high bits by masking to (64-n) low bits.
	return (v >> n) & ((1 << (64 - n)) - 1)


## Serialize to a plain-data dict (for the SimState snapshot). No floats.
func to_dict() -> Dictionary:
	return {"seed": seed, "state": _state}


## Restore from a plain-data dict. Inverse of to_dict; bit-exact round-trip.
static func from_dict(d: Dictionary) -> RngState:
	var r := RngState.new(int(d["seed"]))
	r._state = int(d["state"])
	return r


## Deep copy (for step's non-mutating deep-copy of state).
func clone() -> RngState:
	var r := RngState.new(seed)
	r._state = _state
	return r
