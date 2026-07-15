class_name InputBuffer
extends RefCounted

## Sim-side input buffering: motion recognition + command buffer, evaluated over a
## player's input_history (combat-resolution.md "Input buffer"; AD-003, AD-022). All
## static — no state. A PURE FUNCTION of (input_history, facing): identical for every
## input source, so replays/netcode reproduce buffering for free (Tenet 2, AD-003).
##
## TWO WINDOWS (AD-022, sim-wide, same for every character):
##   - Motion window = 9 frames. A motion's directional sequence (236, 623, …) is
##     recognized iff its directions occur IN ORDER within the last 9 frames.
##   - Command buffer = 6 frames. A recognized command (special / throw / special-
##     cancel) is HELD up to 6 frames; the caller (phase 2) executes it on the first
##     frame the character is actionable, or the first frame a cancel window opens.
##
## FACING (AD-002/AD-003). Motions are facing-relative — a 236 is "toward the
## opponent." The recognizer resolves each history frame's raw Left/Right to
## forward/back by `facing` before matching, so a mirrored player performs the same
## motion with mirrored raw inputs. Up/Down are absolute. Buttons are raw bits.
##
## No floats reach here: history frames are ints, windows are frame counts.

# --- Motion command ids (ButtonMapEntry.motion names one of these) -----------
# 0 = no motion (a plain button command). Values are stable ids; the direction
# sequence each expands to lives in _motion_tokens (facing-relative tokens).
const MOTION_NONE: int = 0
const MOTION_236: int = 236   # quarter-circle forward (fireball)
const MOTION_623: int = 623   # dragon-punch / reversal (forward, down, down-forward)

# --- Direction tokens (facing-relative; what a motion frame must satisfy) -----
# A motion is an ordered list of these tokens. Each token is a required direction
# state a history frame must match (after facing resolution) for the sequence to
# advance. DOWN/UP are absolute; FORWARD/BACK are facing-resolved from raw L/R.
const DIR_DOWN: int = 1
const DIR_FORWARD: int = 2
const DIR_DOWN_FORWARD: int = 3   # down AND forward both held
const DIR_BACK: int = 4
const DIR_UP: int = 5

# The window constants (AD-022). Named here so the one buffering definition owns them
# at the code level; the FEEL values live in AD-022 (sim-side, Architect's).
const MOTION_WINDOW: int = 9
const COMMAND_BUFFER: int = 6

# DOUBLE-TAP WINDOW (AD-046, TKT-P2-02; feel value, Strategist-tunable like the two
# windows above — placeholder ~12f per AD-046's own text, logged JC-074). A double-tap
# (press -> release -> press of the SAME direction) must complete within this many
# frames of history, oldest to newest, for the pattern to be recognized. Wider than
# COMMAND_BUFFER because a double-tap is a whole 3-edge gesture, not a single press.
const DOUBLE_TAP_WINDOW: int = 12


## The ordered facing-relative token sequence a motion id expands to. 236 = down,
## down-forward, forward (a quarter-circle toward the opponent). 623 = forward, down,
## down-forward (a "dragon punch"). Returns [] for an unknown / MOTION_NONE id.
static func _motion_tokens(motion: int) -> Array:
	match motion:
		MOTION_236:
			return [DIR_DOWN, DIR_DOWN_FORWARD, DIR_FORWARD]
		MOTION_623:
			return [DIR_FORWARD, DIR_DOWN, DIR_DOWN_FORWARD]
		_:
			return []


## True iff the history frame at `age` (0 = newest) satisfies the direction token,
## resolving raw L/R to forward/back by `facing`. SOCD is applied first so opposing
## directions can't spuriously satisfy a token (the same cleaning phase 1 does).
static func _frame_satisfies(hist: InputHistory, age: int, token: int, facing: int) -> bool:
	var raw: int = hist.at(age)
	var frame: int = StepPhases.socd_normalize(raw)
	var down: bool = (frame & InputFrame.DOWN) != 0
	var up: bool = (frame & InputFrame.UP) != 0
	var left: bool = (frame & InputFrame.LEFT) != 0
	var right: bool = (frame & InputFrame.RIGHT) != 0
	var forward: bool = right if facing >= 0 else left
	var back: bool = left if facing >= 0 else right
	match token:
		DIR_DOWN:
			return down
		DIR_FORWARD:
			return forward
		DIR_DOWN_FORWARD:
			return down and forward
		DIR_BACK:
			return back
		DIR_UP:
			return up
	return false


## Whether the motion `motion` was completed within the last MOTION_WINDOW frames of
## history (AD-022). The tokens must appear IN ORDER (oldest→newest) inside the window;
## intermediate frames between tokens are allowed (leniency). We scan the window from
## oldest (age = MOTION_WINDOW-1) toward newest (age 0), advancing through the token
## list each time a frame satisfies the next expected token; recognized iff all tokens
## are consumed AND the final token lands (so the motion COMPLETES within the window).
static func motion_recognized(hist: InputHistory, motion: int, facing: int) -> bool:
	var tokens: Array = _motion_tokens(motion)
	if tokens.is_empty():
		return false
	# Scan oldest→newest across the window; greedily advance the token cursor.
	var cursor: int = 0
	# ages: MOTION_WINDOW-1 (oldest in window) .. 0 (newest). Clamp to history capacity.
	var oldest_age: int = MOTION_WINDOW - 1
	for age in range(oldest_age, -1, -1):
		if _frame_satisfies(hist, age, tokens[cursor], facing):
			cursor += 1
			if cursor >= tokens.size():
				return true
	return false


## Whether a plain (non-motion) button command is HELD/pressed within the command
## buffer window (COMMAND_BUFFER frames). Returns true iff the button bit appears on
## any of the last COMMAND_BUFFER frames — a leniency: a special pressed up to 6 frames
## early still counts. `button_index` 0..7. Direction-gated commands additionally check
## `required_direction` (raw bits) is held on the SAME frame the button is.
static func button_buffered(hist: InputHistory, button_index: int, required_direction: int,
		facing: int) -> bool:
	if button_index < 0:
		return false
	var bit: int = 1 << (4 + button_index)
	for age in range(COMMAND_BUFFER):
		var raw: int = hist.at(age)
		if (raw & bit) == 0:
			continue
		if required_direction == 0:
			return true
		# Direction gate: the required raw direction must be held on this same frame.
		var frame: int = StepPhases.socd_normalize(raw)
		if _required_direction_held(frame, required_direction, facing):
			return true
	return false


## True iff the (SOCD-normalized) frame holds the required direction. required_direction
## is raw InputFrame direction bits; DOWN/UP are absolute, LEFT/RIGHT are matched by
## MEANING via facing (a back-charge command specifies "back" as its raw home direction
## but we match forward/back semantics). At P0 the test commands use DOWN only; the
## forward/back mapping is here so a directional special extends without a rewrite.
static func _required_direction_held(frame: int, required_direction: int, facing: int) -> bool:
	if (required_direction & InputFrame.DOWN) != 0 and (frame & InputFrame.DOWN) == 0:
		return false
	if (required_direction & InputFrame.UP) != 0 and (frame & InputFrame.UP) == 0:
		return false
	var left: bool = (frame & InputFrame.LEFT) != 0
	var right: bool = (frame & InputFrame.RIGHT) != 0
	var forward: bool = right if facing >= 0 else left
	var back: bool = left if facing >= 0 else right
	# RIGHT in required_direction means "forward"; LEFT means "back" (facing-resolved).
	if (required_direction & InputFrame.RIGHT) != 0 and not forward:
		return false
	if (required_direction & InputFrame.LEFT) != 0 and not back:
		return false
	return true


## Whether a pure-direction command (AD-032: no button, no motion — e.g. jump,
## `UP`) is held within the command buffer window. True iff `required_direction`
## is satisfied on ANY of the last COMMAND_BUFFER frames (the same leniency
## `button_buffered` gives a button press). Reuses `_required_direction_held`
## (facing-resolved forward/back, absolute up/down) over each SOCD-normalized
## history frame.
static func direction_buffered(hist: InputHistory, required_direction: int, facing: int) -> bool:
	if required_direction == 0:
		return false
	for age in range(COMMAND_BUFFER):
		var frame: int = StepPhases.socd_normalize(hist.at(age))
		if _required_direction_held(frame, required_direction, facing):
			return true
	return false


## Whether `required_direction` was DOUBLE-TAPPED (AD-046: pressed -> released ->
## pressed) within the last DOUBLE_TAP_WINDOW frames of history. Scans oldest
## (age = DOUBLE_TAP_WINDOW-1) toward newest (age 0) through a tiny 3-state
## machine — looking for the first press, then a release, then a second press —
## mirroring `motion_recognized`'s scan shape but over PRESS/RELEASE edges of one
## direction rather than an ordered token sequence. A direction held continuously
## through the whole window never reaches the "seen a release" state, so a plain
## sustained hold (e.g. walking) never falsely satisfies a double-tap. Pure
## function of (input_history, facing) — no new input path (Tenet 2).
static func double_tap_recognized(hist: InputHistory, required_direction: int, facing: int) -> bool:
	if required_direction == 0:
		return false
	const STATE_AWAIT_FIRST_PRESS: int = 0
	const STATE_AWAIT_RELEASE: int = 1
	const STATE_AWAIT_SECOND_PRESS: int = 2
	var state: int = STATE_AWAIT_FIRST_PRESS
	var oldest_age: int = DOUBLE_TAP_WINDOW - 1
	for age in range(oldest_age, -1, -1):
		var frame: int = StepPhases.socd_normalize(hist.at(age))
		var held: bool = _required_direction_held(frame, required_direction, facing)
		match state:
			STATE_AWAIT_FIRST_PRESS:
				if held:
					state = STATE_AWAIT_RELEASE
			STATE_AWAIT_RELEASE:
				if not held:
					state = STATE_AWAIT_SECOND_PRESS
			STATE_AWAIT_SECOND_PRESS:
				if held:
					return true
	return false


## True iff `required_direction` is held THIS TICK (age 0) and was NOT held the
## tick immediately before (age 1) — a strict, UN-BUFFERED rising edge (no
## COMMAND_BUFFER leniency window). Needed for AD-046's double jump: a player
## holding UP continuously from the INITIAL jump takeoff must press UP AGAIN once
## airborne to double-jump. A BUFFERED edge (scanning back COMMAND_BUFFER frames
## for any transition) would falsely fire the moment airborne becomes true, because
## the jump's OWN initiating UP-press is itself a transition that stays inside a
## multi-frame lookback window for several ticks afterward — exactly the takeoff
## tick, when the air action must NOT fire. Requiring the edge on the EXACT current
## tick (no lookback) means a stale, already-in-progress hold from before takeoff
## can never re-trigger; only a genuine fresh press, happening while the caller has
## already confirmed the player is physically airborne, satisfies it. Pure function
## of (input_history, facing) — no new input path (Tenet 2).
static func direction_pressed_edge(hist: InputHistory, required_direction: int, facing: int) -> bool:
	if required_direction == 0:
		return false
	var frame: int = StepPhases.socd_normalize(hist.at(0))
	if not _required_direction_held(frame, required_direction, facing):
		return false
	var prev_frame: int = StepPhases.socd_normalize(hist.at(1))
	return not _required_direction_held(prev_frame, required_direction, facing)


## Whether a two-button CHORD (AD-032: `button_index` + `chord_button_index`, e.g.
## throw `L+H`) is satisfied within the command buffer window. "Same frame" is
## load-bearing (move-format.md): both bits must be held on ONE buffered frame,
## not merely each appearing somewhere in the window (which would falsely fire on
## an `L` then a separate `H` six frames apart). Optional `required_direction`
## additionally gates that same frame.
static func chord_buffered(hist: InputHistory, button_index: int, chord_button_index: int,
		required_direction: int, facing: int) -> bool:
	if button_index < 0 or chord_button_index < 0:
		return false
	var bit_a: int = 1 << (4 + button_index)
	var bit_b: int = 1 << (4 + chord_button_index)
	var both_bits: int = bit_a | bit_b
	for age in range(COMMAND_BUFFER):
		var raw: int = hist.at(age)
		if (raw & both_bits) != both_bits:
			continue
		if required_direction == 0:
			return true
		var frame: int = StepPhases.socd_normalize(raw)
		if _required_direction_held(frame, required_direction, facing):
			return true
	return false


## CURRENT-TICK-ONLY recognition for one ButtonMapEntry (AD-038 correction, 2026-07-10):
## true iff the entry's command is satisfied by the NEWEST history frame alone (age 0) —
## no COMMAND_BUFFER/MOTION_WINDOW carry-over. Used ONLY by phase 2's loop-state stance
## re-derivation (walk/crouch): a released direction must stop being "satisfied" the very
## tick it is released, which the buffered `entry_satisfied` below cannot express (it is
## deliberately lenient for DISCRETE commands, AD-022). A motion entry can never be
## satisfied by a single frame (its tokens are an ordered multi-frame sequence) and
## correctly returns false here — no authored loop-state target uses a motion command in
## this slice, so this is a completeness guarantee, not a reachability path. Still a pure
## function of (input_history, facing) — deterministic (Tenet 2).
static func entry_satisfied_now(hist: InputHistory, entry: ButtonMapEntry, facing: int) -> bool:
	if entry.motion != MOTION_NONE:
		return false
	var raw: int = hist.at(0)
	var frame: int = StepPhases.socd_normalize(raw)
	if entry.chord_button_index >= 0:
		var bit_a: int = 1 << (4 + entry.button_index)
		var bit_b: int = 1 << (4 + entry.chord_button_index)
		var both_bits: int = bit_a | bit_b
		if (raw & both_bits) != both_bits:
			return false
		if entry.required_direction != 0 and not _required_direction_held(frame, entry.required_direction, facing):
			return false
		return true
	if entry.button_index < 0:
		# Pure-direction command (AD-032): no button at all, held direction only.
		if entry.required_direction == 0:
			return false
		return _required_direction_held(frame, entry.required_direction, facing)
	# Plain button command (+ optional required direction), THIS frame only.
	var bit: int = 1 << (4 + entry.button_index)
	if (raw & bit) == 0:
		return false
	if entry.required_direction != 0 and not _required_direction_held(frame, entry.required_direction, facing):
		return false
	return true


## The full recognition for one ButtonMapEntry against a player's history: true iff the
## entry's command is satisfied within its buffer window. A DOUBLE-TAP entry
## (double_tap == true, AD-046) requires `required_direction` pressed -> released ->
## pressed within DOUBLE_TAP_WINDOW — checked FIRST and exclusively (it never falls
## through to the plain-direction path below, even though it shares that path's
## button_index/motion shape). A motion entry (motion != 0) requires the motion
## recognized within MOTION_WINDOW AND (if it also names a button) the button pressed
## within COMMAND_BUFFER. A CHORD entry (chord_button_index set) requires both buttons
## held on the SAME buffered frame (AD-032). A PURE-DIRECTION entry (button_index == -1,
## no motion, no chord, no double_tap) requires only `required_direction` held within
## COMMAND_BUFFER (AD-032; e.g. jump). A plain button entry requires the button (+
## optional direction) within COMMAND_BUFFER. This is the ONE recognizer phase 2 and the
## buffered-command executor both call, so there is a single buffering definition.
static func entry_satisfied(hist: InputHistory, entry: ButtonMapEntry, facing: int) -> bool:
	if entry.double_tap:
		# Double-tap (AD-046) is its OWN recognition shape — a distinct scan, never
		# folded into the plain-direction/motion/chord branches below.
		return double_tap_recognized(hist, entry.required_direction, facing)
	if entry.motion != MOTION_NONE:
		if not motion_recognized(hist, entry.motion, facing):
			return false
		# A motion command may also require a button (e.g. 236 + BUTTON_0). If it names
		# no button (button_index < 0) the motion alone triggers it.
		if entry.button_index < 0:
			return true
		return button_buffered(hist, entry.button_index, 0, facing)
	if entry.chord_button_index >= 0:
		# Two-button chord (AD-032): both bits required on the same frame.
		return chord_buffered(hist, entry.button_index, entry.chord_button_index,
			entry.required_direction, facing)
	if entry.button_index < 0:
		# Pure-direction command (AD-032): no button at all, held direction only.
		return direction_buffered(hist, entry.required_direction, facing)
	# Plain button command (+ optional required direction).
	return button_buffered(hist, entry.button_index, entry.required_direction, facing)
