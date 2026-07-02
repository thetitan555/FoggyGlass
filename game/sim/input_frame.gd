class_name InputFrame
extends RefCounted

## The single per-frame input representation (Tenet 2, input.md, AD-002, AD-018).
##
## One value fully describes one player's RAW input for one tick: a fixed-width
## 16-bit unsigned bitfield. Per input.md this is *the* representation every
## producer emits and the sim consumes — directions plus generic buttons, with
## NO facing, NO move semantics, NO buffering at this layer.
##
## REPRESENTATION (latitude, logged JC-006). GDScript has no native u16 value
## type, so an `InputFrame` value is carried as a plain GDScript `int` masked to
## the low 16 bits. This class holds NO instances on the data path — it is a
## namespace of bit constants + pure static helpers over that int. A frame value
## is therefore trivially serializable (it IS an int), byte-identical on
## round-trip (input.md criterion 1), and drops straight into the sim's
## `input_history` and any recorded buffer. `RefCounted` (never instantiated) so
## the `class_name` gives us the `InputFrame.CONST` / `InputFrame.helper()` call
## site with zero state, mirroring the FP helper packaging (JC-001 pattern).
##
## Bit layout (input.md):
##   bit 0  Up (raw)
##   bit 1  Down (raw)
##   bit 2  Left (raw)
##   bit 3  Right (raw)
##   bits 4..11  BUTTON_0 .. BUTTON_7 (generic; un-named here — AD-002/AD-018)
##   bits 12..15 Reserved — MUST be 0 (any set reserved bit is an invalid frame)
##
## Directions are RAW physical Left/Right/Up/Down as pressed. The sim converts to
## forward/back per facing (AD-002); this layer never does. Buttons are
## semantically blank: the slice commits to three attack buttons (BUTTON_0/1/2 →
## L/M/H) but the L/M/H labels live above this layer in each character's
## button_map (AD-018). SOCD (opposing directions) is NOT cleaned here — it is a
## single sim-side function (AD-003), TKT-P0-06.

# --- Direction bits ---------------------------------------------------------
const UP: int = 1 << 0        # 0x0001
const DOWN: int = 1 << 1      # 0x0002
const LEFT: int = 1 << 2      # 0x0004
const RIGHT: int = 1 << 3     # 0x0008

# --- Button bits (generic; L/M/H mapping is character data, AD-018) ---------
const BUTTON_0: int = 1 << 4  # 0x0010
const BUTTON_1: int = 1 << 5  # 0x0020
const BUTTON_2: int = 1 << 6  # 0x0040
const BUTTON_3: int = 1 << 7  # 0x0080  (reserved for post-slice use)
const BUTTON_4: int = 1 << 8  # 0x0100  (reserved)
const BUTTON_5: int = 1 << 9  # 0x0200  (reserved)
const BUTTON_6: int = 1 << 10 # 0x0400  (reserved)
const BUTTON_7: int = 1 << 11 # 0x0800  (reserved)

# --- Masks ------------------------------------------------------------------

## The neutral frame: nothing pressed.
const NEUTRAL: int = 0

## All 16 bits — used to mask a value down to frame width.
const FRAME_MASK: int = 0xFFFF

## The directional bits (0..3).
const DIR_MASK: int = UP | DOWN | LEFT | RIGHT   # 0x000F

## The button bits (4..11).
const BUTTON_MASK: int = 0x0FF0

## Reserved bits (12..15) — must always be zero on a valid frame.
const RESERVED_MASK: int = 0xF000


# --- Construction / masking -------------------------------------------------

## Mask an arbitrary int down to the 16-bit frame width. Use when composing a
## frame from raw device reads to guarantee no stray high bits leak in.
static func mask(bits: int) -> int:
	return bits & FRAME_MASK


## Compose a frame from explicit direction/button bit ORs. Convenience for tests
## and authored sequences; the result is masked to frame width. Does NOT clean
## SOCD (that is sim-side, AD-003) and does NOT set reserved bits.
static func make(bits: int) -> int:
	return bits & (DIR_MASK | BUTTON_MASK)


# --- Validity (input.md criterion 6) ----------------------------------------

## True iff the frame is valid: no reserved bit (12..15) is set. Any set reserved
## bit is an invalid frame per input.md. This is the input-boundary check every
## source runs on values it produces (see InputSource.validate).
static func is_valid(frame: int) -> bool:
	return (frame & RESERVED_MASK) == 0 and frame == (frame & FRAME_MASK)


# --- Bit queries (pure reads; no facing, no semantics) ----------------------

static func is_up(frame: int) -> bool:
	return (frame & UP) != 0

static func is_down(frame: int) -> bool:
	return (frame & DOWN) != 0

static func is_left(frame: int) -> bool:
	return (frame & LEFT) != 0

static func is_right(frame: int) -> bool:
	return (frame & RIGHT) != 0

## Generic button query by index 0..7 (maps to bits 4..11). Semantically blank
## here — "is BUTTON_i held," never "is heavy attack held" (AD-002/AD-018).
static func is_button(frame: int, index: int) -> bool:
	assert(index >= 0 and index <= 7, "InputFrame.is_button: index out of range 0..7")
	return (frame & (1 << (4 + index))) != 0


# --- Debug / golden rendering (view only; never sim math) -------------------

## A stable human-readable rendering of a frame, for test failure messages and
## golden dumps. Fixed order (U D L R then B0..B7) so it is deterministic and
## diffable. Not consumed by the sim.
static func to_debug_string(frame: int) -> String:
	if frame == NEUTRAL:
		return "----------"
	var parts := PackedStringArray()
	if is_up(frame): parts.append("U")
	if is_down(frame): parts.append("D")
	if is_left(frame): parts.append("L")
	if is_right(frame): parts.append("R")
	for i in range(8):
		if is_button(frame, i):
			parts.append("B%d" % i)
	if (frame & RESERVED_MASK) != 0:
		parts.append("!RESERVED(0x%X)" % (frame & RESERVED_MASK))
	return "+".join(parts)
