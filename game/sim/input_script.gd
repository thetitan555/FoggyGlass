class_name InputScript
extends RefCounted

## Contract 1 (trace-harness.md → "the input-string syntax"): a compiler from a
## human-readable input string to a raw `InputFrame` buffer, one entry per tick.
## `compile(text) -> PackedInt32Array` is a PURE function — identical text always
## compiles to an identical buffer — so the shareable artifact is the string and
## the replay is deterministic (Tenet 1). All-static namespace, never
## instantiated, sibling to `InputFrame` (RefCounted, mirrors the FP/InputFrame
## packaging, JC-001/JC-006 pattern).
##
## GRAMMAR (trace-harness.md, verbatim):
##   token   := frame [ '*' count ]
##   frame   := [ dir ] [ button... ] | '5'
##   dir     := '1'..'9'   (numpad, RAW/screen-relative — see _DIR_BITS)
##   button  := 'L' | 'M' | 'H'   (BUTTON_0 / BUTTON_1 / BUTTON_2, AD-018)
##   count   := integer >= 1 (repeat this exact frame `count` ticks, default 1)
## Whitespace/newline separates tokens; `#` begins a line comment. No motion
## shorthand — a fireball is three tokens `2 3 6H`, never one `236H` token (a
## second direction digit inside one token is a malformed token, not a motion).
##
## VALIDATION / HARD ERRORS (Contract 1, input.md criterion 6). Every malformed
## token (unknown character, more than one direction digit, a bad/zero repeat
## count, an empty frame) is a HARD ERROR — never a silently-dropped or altered
## frame. This mirrors the codebase's EXISTING hard-error-at-the-boundary
## convention (`InputSource.validate` / `InputFrame.is_valid`, input_source.gd):
## `assert(false, ...)`, not a return-coded error, since `compile`'s contract
## signature is the single pure `(text) -> PackedInt32Array` Contract 1 specifies
## (no error-tuple return). Every direction/button bit this compiler can ever
## emit already lies inside InputFrame's non-reserved range (see _DIR_BITS/
## _BUTTON_BITS below), so a reserved-bit frame is structurally unreachable via
## this grammar; `_parse_frame` still asserts `InputFrame.is_valid` on every
## emitted frame as a defense-in-depth boundary check, matching every other
## producer in this tree.
##
## TESTING THE HARD-ERROR BOUNDARY (Developer-latitude testing hook, logged).
## A tripped `assert` isn't reliably catchable/introspectable from a headless
## GDScript test (this codebase's own precedent: test_record_playback.gd's
## `_test_reproducibility_and_future_read_contract` note — "a direct assert-
## crash isn't introspectable from GDScript without a debug-build catch, so we
## assert the documented gate instead"). `is_well_formed_token` below exposes the
## SAME grammar check `_compile_token`/`_parse_frame` enforce via `assert`, as a
## plain non-asserting bool, so a test can verify malformed-input DETECTION
## without tripping the crash path itself. It is not part of Contract 1's
## `compile` signature — an additive helper only.

## RAW numpad direction -> InputFrame direction bits (screen-relative, never
## facing-relative — the sim applies SOCD + facing itself, AD-003). Because P1
## (the character under test) starts facing right, this reads as forward-
## relative for P1 without any translation (trace-harness.md).
const _DIR_BITS: Dictionary = {
	1: InputFrame.DOWN | InputFrame.LEFT,
	2: InputFrame.DOWN,
	3: InputFrame.DOWN | InputFrame.RIGHT,
	4: InputFrame.LEFT,
	5: InputFrame.NEUTRAL,
	6: InputFrame.RIGHT,
	7: InputFrame.UP | InputFrame.LEFT,
	8: InputFrame.UP,
	9: InputFrame.UP | InputFrame.RIGHT,
}

## Button letter -> InputFrame button bit (AD-018).
const _BUTTON_BITS: Dictionary = {
	"L": InputFrame.BUTTON_0,
	"M": InputFrame.BUTTON_1,
	"H": InputFrame.BUTTON_2,
}


## Compile an authored input string to a raw InputFrame buffer, one entry per
## tick (Contract 1). Pure and total over well-formed input: identical text
## compiles to an identical buffer on every call (acceptance criterion 1).
static func compile(text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for token in _tokenize(text):
		var compiled: Dictionary = _compile_token(token)
		var frame: int = compiled["frame"]
		var count: int = compiled["count"]
		for _k in range(count):
			out.append(frame)
	return out


## Strip `#`-line-comments and split into whitespace/newline-separated tokens,
## in order (Contract 1: "Whitespace/newline-separated tokens; # begins a line
## comment").
static func _tokenize(text: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	for raw_line in text.split("\n"):
		var line: String = raw_line.replace("\t", " ").replace("\r", "")
		var hash_idx: int = line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		for tok in line.split(" ", false):
			var trimmed: String = tok.strip_edges()
			if trimmed != "":
				tokens.append(trimmed)
	return tokens


## Parse one token (`frame['*'count]`) to {"frame": int, "count": int}. HARD
## ERROR (assert) on any malformed token — see the class doc comment.
static func _compile_token(token: String) -> Dictionary:
	var star_parts: PackedStringArray = token.split("*")
	assert(star_parts.size() <= 2,
		"InputScript.compile: malformed token '%s' — more than one '*'" % token)
	var frame_str: String = star_parts[0]
	var count: int = 1
	if star_parts.size() == 2:
		count = _parse_count(star_parts[1], token)
	var frame: int = _parse_frame(frame_str, token)
	return {"frame": frame, "count": count}


static func _parse_count(count_str: String, token: String) -> int:
	assert(count_str.length() > 0 and count_str.is_valid_int(),
		"InputScript.compile: malformed repeat count in token '%s'" % token)
	var n: int = count_str.to_int()
	assert(n >= 1,
		"InputScript.compile: repeat count must be >= 1 in token '%s'" % token)
	return n


## Parse the frame portion (before any '*'): an optional single leading numpad
## digit (1-9, RAW), then zero or more L/M/H button letters. A second digit, or
## any character outside 1-9/L/M/H, is a malformed token (no motion shorthand —
## motions are authored per-tick, across separate tokens).
static func _parse_frame(frame_str: String, token: String) -> int:
	assert(frame_str.length() > 0,
		"InputScript.compile: empty frame in token '%s'" % token)
	var idx: int = 0
	var bits: int = InputFrame.NEUTRAL
	var first: String = frame_str[0]
	if first.is_valid_int() and _DIR_BITS.has(int(first)):
		bits |= _DIR_BITS[int(first)]
		idx = 1
	for i in range(idx, frame_str.length()):
		var ch: String = frame_str[i]
		assert(_BUTTON_BITS.has(ch),
			("InputScript.compile: unknown character '%s' in token '%s' " +
			"(expected a single leading numpad digit 1-9, then L/M/H buttons only)")
			% [ch, token])
		bits |= _BUTTON_BITS[ch]
	assert(InputFrame.is_valid(bits),
		"InputScript.compile: token '%s' produced an invalid InputFrame — should be unreachable via this grammar" % token)
	return bits


## Non-asserting well-formedness check for one token — the identical grammar
## `_compile_token`/`_parse_frame` enforce via `assert`, exposed as a plain bool
## (see the class doc comment "Testing the hard-error boundary"). Not part of
## Contract 1's `compile` signature.
static func is_well_formed_token(token: String) -> bool:
	if token.is_empty():
		return false
	var star_parts: PackedStringArray = token.split("*")
	if star_parts.size() > 2:
		return false
	if star_parts.size() == 2:
		var count_str: String = star_parts[1]
		if count_str.length() == 0 or not count_str.is_valid_int():
			return false
		if count_str.to_int() < 1:
			return false
	var frame_str: String = star_parts[0]
	if frame_str.length() == 0:
		return false
	var idx: int = 0
	var first: String = frame_str[0]
	if first.is_valid_int() and _DIR_BITS.has(int(first)):
		idx = 1
	for i in range(idx, frame_str.length()):
		if not _BUTTON_BITS.has(frame_str[i]):
			return false
	return true
