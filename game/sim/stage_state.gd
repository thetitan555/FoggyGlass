class_name StageState
extends RefCounted

## Stage state that affects the sim (simulation.md → SimState.stage).
##
## Minimal for P0: the horizontal play bounds (left/right walls) that pushbox /
## movement resolution will clamp against (TKT-P0-06), and the ground line.
## Everything here is fixed-point (AD-005/014) — NO floats (simulation.md
## criterion 8). Kept as its own plain-data object (not loose fields on SimState)
## so stage state can grow (corners, platforms) without reshaping SimState, and so
## it clones/serializes/hashes uniformly with the rest of the graph.
##
## VALUES ARE DATA, NOT FEEL. The concrete wall/ground numbers here are placeholder
## geometry so the sim has valid bounds to resolve against in P0; the authored stage
## dimensions are content (later ticket / stage resource). They are chosen as round
## fixed-point values and are trivially overridable via new_initial's arguments.

## Left / right wall x-positions, fixed-point. Movement clamps between these.
var wall_left: int = 0
var wall_right: int = 0

## Ground y-position, fixed-point. The floor characters stand on.
var ground_y: int = 0


## Build a stage with explicit fixed-point bounds. Defaults give a symmetric
## placeholder arena so P0 has valid geometry; real dimensions are authored later.
static func new_initial(
		p_wall_left: int = FP.from_int(-400),
		p_wall_right: int = FP.from_int(400),
		p_ground_y: int = 0) -> StageState:
	var s := StageState.new()
	s.wall_left = p_wall_left
	s.wall_right = p_wall_right
	s.ground_y = p_ground_y
	return s


## Deep copy for step's non-mutating clone (AD-004). All members are value ints,
## so a field copy is a full deep copy.
func clone() -> StageState:
	var s := StageState.new()
	s.wall_left = wall_left
	s.wall_right = wall_right
	s.ground_y = ground_y
	return s


## Serialize to plain-data dict. Field order fixed for canonical hashing. No floats.
func to_dict() -> Dictionary:
	return {
		"wall_left": wall_left,
		"wall_right": wall_right,
		"ground_y": ground_y,
	}


## Restore from plain-data dict. Exact inverse of to_dict.
static func from_dict(d: Dictionary) -> StageState:
	var s := StageState.new()
	s.wall_left = int(d["wall_left"])
	s.wall_right = int(d["wall_right"])
	s.ground_y = int(d["ground_y"])
	return s
