class_name InputHistoryPanelModel
extends RefCounted

## Pure view-model for TKT-P1-09 (input display / history). training-mode.md
## → Readout: input; criterion 8; Tenet 2 ("the single input representation
## surfaced directly ... input is never the hidden variable").
##
## Reads ONLY `PlayerView.input_current` / `PlayerView.input_history` (raw
## `InputFrame` ints, input.md) through InspectionView — decodes them into
## plain, display-ready data. No Node/Control API here, so the decode is
## headlessly testable.
##
## L/M/H LABELING (AD-018). BUTTON_0/1/2 are surfaced to players as Light/
## Medium/Heavy at the INPUT layer itself, slice-wide, for every character
## (input.md: "used by every character and every input source ... the L/M/H
## labels ... stay above the input layer" — i.e. they are a system-level input
## fact, not a per-character one). Decoding them here is therefore
## character-agnostic, not a character-specific branch.

## Decode one raw InputFrame into plain display data: which direction bits are
## held (as a compass-ish string) and which buttons (labeled L/M/H for the
## slice's three attack buttons, plus raw bit names for the reserved ones so a
## future button is still visible rather than silently dropped).
static func decode_frame(frame: int) -> Dictionary:
	return {
		"raw": frame,
		"direction": _decode_direction(frame),
		"buttons": _decode_buttons(frame),
	}


static func _decode_direction(frame: int) -> String:
	var up: bool = (frame & InputFrame.UP) != 0
	var down: bool = (frame & InputFrame.DOWN) != 0
	var left: bool = (frame & InputFrame.LEFT) != 0
	var right: bool = (frame & InputFrame.RIGHT) != 0
	var v: String = ""
	if up and not down:
		v = "U"
	elif down and not up:
		v = "D"
	elif up and down:
		v = "UD"   # raw, pre-SOCD (input.md: raw bits stay raw end-to-end for replay fidelity)
	var h: String = ""
	if left and not right:
		h = "L"
	elif right and not left:
		h = "R"
	elif left and right:
		h = "LR"   # raw, pre-SOCD
	if v == "" and h == "":
		return "N"   # neutral
	return v + h


## Button label order fixed slice-wide (L, M, H) then the reserved bits by raw
## index, so a reserved button set post-slice still shows up as "B3" etc.
## rather than being silently invisible (Tenet 2: input is never hidden).
const _BUTTON_BITS: Array = [
	InputFrame.BUTTON_0, InputFrame.BUTTON_1, InputFrame.BUTTON_2,
	InputFrame.BUTTON_3, InputFrame.BUTTON_4, InputFrame.BUTTON_5,
	InputFrame.BUTTON_6, InputFrame.BUTTON_7,
]
const _BUTTON_LABELS: PackedStringArray = ["L", "M", "H", "B3", "B4", "B5", "B6", "B7"]


static func _decode_buttons(frame: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i in range(_BUTTON_BITS.size()):
		if (frame & _BUTTON_BITS[i]) != 0:
			out.append(_BUTTON_LABELS[i])
	return out


## Build the full per-player display model: the current frame decoded, plus
## the decoded scrolling history (oldest -> newest, matching
## PlayerView.input_history's own order) capped to `max_rows` most-recent
## entries for display (the seam's own ring buffer already bounds the
## underlying size; this is a display-only further cap so a long history
## doesn't have to fully render every tick).
static func build(view: InspectionView, max_rows: int = 16) -> Array:
	var out: Array = []
	for i in range(2):
		out.append(_for_player(view, i, max_rows))
	return out


static func _for_player(view: InspectionView, i: int, max_rows: int) -> Dictionary:
	var pv: PlayerView = view.player(i)
	var hist: PackedInt32Array = pv.input_history
	var start: int = max(0, hist.size() - max_rows)
	var rows: Array = []
	for k in range(start, hist.size()):
		rows.append(decode_frame(hist[k]))
	return {
		"player": i,
		"current": decode_frame(pv.input_current),
		"history": rows,
		"recognized": recognized_commands(pv),
	}


# ---------------------------------------------------------------------------
# Recognized commands (jump / throw / chord) — TKT-P1-09's "recognizer is a
# pure function of input_history (AD-032), so jump/throw/chord decode from
# the same frames." InputBuffer.entry_satisfied(hist, entry, facing) is the
# ONE recognizer the sim's own phase 2 and buffered-command executor call
# (input_buffer.gd) — this panel calls the SAME function, over the SAME raw
# frames the seam already exposes (PlayerView.input_history), reconstructed
# into an InputHistory via InputHistory.from_dict (its own documented
# to_dict/from_dict round-trip shape: {"frames": PackedInt32Array}). This is
# not a re-derivation of a NEW recognizer — it is the existing one, fed
# seam-legal data, so a jump/throw/chord reads exactly as "recognized" here
# as it would in the sim itself (single source of truth).
#
# CHARACTER-AGNOSTIC QUERY SHAPES, NOT CharacterA's DATA. The two
# ButtonMapEntry shapes below encode ONLY the schema AD-032 itself defines
# (a pure-direction command = UP held; a two-button chord = BUTTON_0 +
# BUTTON_2 on the same frame) — the same shapes input.md/move-format.md's
# command-recognition CONTRACT names generically ("jump," "throw" as the
# schema's own worked examples), not a lookup into any specific character's
# authored button_map. No CharacterA reference here.
# ---------------------------------------------------------------------------

static var _jump_query: ButtonMapEntry = null
static var _throw_query: ButtonMapEntry = null


static func _ensure_queries() -> void:
	if _jump_query == null:
		_jump_query = ButtonMapEntry.new()
		_jump_query.button_index = -1
		_jump_query.chord_button_index = -1
		_jump_query.required_direction = InputFrame.UP
		_jump_query.motion = InputBuffer.MOTION_NONE
	if _throw_query == null:
		_throw_query = ButtonMapEntry.new()
		_throw_query.button_index = 0   # BUTTON_0 (L)
		_throw_query.chord_button_index = 2   # BUTTON_2 (H)
		_throw_query.required_direction = 0
		_throw_query.motion = InputBuffer.MOTION_NONE


## Which of the schema-level jump/throw commands are currently recognized
## against this player's own input_history, via the sim's ONE recognizer
## (InputBuffer.entry_satisfied). Returns `{ "jump": bool, "throw": bool }`.
static func recognized_commands(pv: PlayerView) -> Dictionary:
	_ensure_queries()
	var hist: InputHistory = InputHistory.from_dict({"frames": pv.input_history})
	return {
		"jump": InputBuffer.entry_satisfied(hist, _jump_query, pv.facing),
		"throw": InputBuffer.entry_satisfied(hist, _throw_query, pv.facing),
	}


## One-line render of a decoded frame, e.g. "UR L+M" or "N" for neutral.
static func format_decoded(decoded: Dictionary) -> String:
	var dir: String = decoded["direction"]
	var buttons: PackedStringArray = decoded["buttons"]
	if buttons.is_empty():
		return dir
	return "%s %s" % [dir, "+".join(buttons)]


## One-line render of a player's current input, for the "current" half of the
## panel: "P0: UR L+M  [jump]". The recognized-command suffix only lists
## commands currently satisfied (empty when neither is), so a quiet frame
## renders with no clause at all.
static func format_current(row: Dictionary) -> String:
	var base: String = "P%d: %s" % [row["player"], format_decoded(row["current"])]
	var recognized: Dictionary = row["recognized"]
	var tags: PackedStringArray = PackedStringArray()
	if recognized["jump"]:
		tags.append("jump")
	if recognized["throw"]:
		tags.append("throw")
	if tags.is_empty():
		return base
	return "%s  [%s]" % [base, ", ".join(tags)]


## One-line render of a player's scrolling history, oldest -> newest, as a
## single space-separated string of decoded frames (each frame's decode is
## itself space-free except the L/H direction+button join, so entries stay
## unambiguous): e.g. "N N UR U+L N".
static func format_history(row: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for decoded in row["history"]:
		parts.append(format_decoded(decoded))
	return " ".join(parts)
