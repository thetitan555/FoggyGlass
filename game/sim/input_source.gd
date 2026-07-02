class_name InputSource
extends RefCounted

## The ONE input-source interface (Tenet 2, input.md, AD-002).
##
## Every input producer — local device, replay file, network peer, CPU, scripted
## tutorial, record/playback dummy — is just another implementation of this one
## interface. The sim holds two of them (P1, P2), calls each once per tick for the
## current frame, and advances. NOTHING in the sim knows which concrete source it
## holds (input.md "Stateless to the sim").
##
## THE CONTRACT (input.md → "InputSource — the one interface"):
##   get_input(frame: int) -> int   (returns an InputFrame value, see input_frame.gd)
##
##   - Frame-indexed and reproducible: for any `frame` the source has ALREADY
##     produced, get_input(frame) returns the identical value on every call. This
##     is what lets rollback re-simulation re-request past frames.
##   - No future reads: querying a frame the source has not yet produced is a
##     contract violation.
##   - Dumb: a source depends ONLY on its own device/buffer/sequence — never on
##     facing, character state, or sim state (input.md criterion 4).
##
## This base class defines the interface and provides shared validity enforcement
## (input.md criterion 6). Concrete sources override `get_input`. It is not
## abstract-enforced by the engine (GDScript has no abstract keyword in 4.3 stable
## for methods), so the base `get_input` asserts if called — a subclass MUST
## override it.

## Return the InputFrame value for `frame`. Subclasses override this. The returned
## value is always validated (reserved bits clear, 16-bit width) before it leaves
## the source; see `validate`. Base implementation is a hard error — a concrete
## source must be used.
func get_input(frame: int) -> int:
	assert(false, "InputSource.get_input must be overridden by a concrete source")
	return InputFrame.NEUTRAL


## Shared input-boundary validity check (input.md criterion 6). Every concrete
## source routes produced values through this so an invalid frame (any reserved
## bit set, or a value wider than 16 bits) is rejected at the boundary rather than
## flowing into the sim. Returns the frame unchanged if valid; asserts (debug) /
## returns a masked-neutral fallback (release) if not, so an invalid device read
## can never silently corrupt determinism.
func validate(frame: int) -> int:
	if InputFrame.is_valid(frame):
		return frame
	assert(false, "InputSource: invalid InputFrame produced (0x%X) — reserved bit set or >16 bits" % frame)
	# Release fallback: strip to a safe, valid value rather than propagate garbage.
	return InputFrame.mask(frame) & ~InputFrame.RESERVED_MASK
