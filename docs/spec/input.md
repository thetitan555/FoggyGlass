# Spec — Input-Source Contract (P0)

> Owned by the **Architect**. The contract for Tenet 2: the single per-frame
> input representation and the one interface every producer implements. The
> Developer builds against this and *raises* problems; it does not redefine it.
> See decisions AD-002, AD-003.

## Scope

This contract defines *how a frame of input is represented* and *how the sim
obtains it*. It does **not** define buffering, motion recognition, or facing —
those are sim-side (AD-003) and specified in `move-format.md` / `combat-resolution.md`.

## `InputFrame` — the per-frame representation

A single fixed-width unsigned bitfield (16 bits). One value fully describes one
player's raw input for one tick.

| Bits | Meaning |
|---|---|
| 0 | Up (raw) |
| 1 | Down (raw) |
| 2 | Left (raw) |
| 3 | Right (raw) |
| 4–11 | Buttons `BUTTON_0` … `BUTTON_7` (generic; un-named at this layer) |
| 12–15 | Reserved — must be 0 |

**Slice button set (AD-018).** The slice commits to **three attack buttons** —
`BUTTON_0`, `BUTTON_1`, `BUTTON_2`, surfaced to players as **Light / Medium /
Heavy** — used by *every* character and *every* input source. What this contract
pins is the **count** (three attack buttons, slice-wide); the **L/M/H labels and
the button→move meaning stay above the input layer** in each character's
`button_map` (`move-format.md`), so the input layer remains semantically blank per
AD-002. `BUTTON_3`…`BUTTON_7` stay reserved for post-slice (system buttons, more
attacks). This satisfies the Strategist's character-A routing: the three-button
layout is a system-level input fact, not a character-A-local one — and it does not
conflict with the input spec, so nothing routes back.

Rules:

- **Raw, not facing-relative.** Bits 2/3 are physical Left/Right as pressed. The
  sim converts to forward/back per facing; the input layer never does (AD-002).
- **Buttons are semantically blank here.** The input layer knows "BUTTON_3 is
  held," not "that's a heavy attack." Mapping button → move is sim/character data.
- **Reserved bits are zero.** Any non-zero reserved bit is an invalid frame.
- `InputFrame` is a plain value: it serializes/restores byte-identically and is
  part of the sim's serialized input history.

## `InputSource` — the one interface

Every producer implements exactly this:

```
InputSource:
    get_input(frame: int) -> InputFrame
```

Contract:

- **Frame-indexed and reproducible.** For any `frame` the source has already
  produced, `get_input(frame)` returns the *identical* `InputFrame` on every
  call. This is what lets rollback re-simulation re-request past frames.
- **No future reads.** Querying a frame the source has not yet produced is a
  contract violation (the sim only ever requests the current frame as it advances,
  or a past frame during re-sim).
- **Stateless to the sim.** The sim holds two sources (P1, P2), calls each once
  per tick for the current frame, and advances. Nothing in the sim knows which
  concrete source it holds.

### The producers (all the same interface)

| Source | Behavior |
|---|---|
| Local device | Samples the device each tick, **records into a buffer** so past frames stay answerable. |
| Replay | Reads a recorded buffer/file frame by frame. |
| Network peer | Yields the peer's frames (rollback predicts/corrects around this later). |
| Scripted (tutorial/CPU) | Yields frames from an authored sequence. |
| Record/playback dummy | A source that **writes a buffer while recording, then replays it** — Tenet 2, not an AI. |

A "replay" is just a Local-device recording fed back through the Replay source —
they must produce identical streams for the same session.

## SOCD normalization (sim-side, one function)

Raw frames may contain opposing directions (Left+Right, Up+Down). Cleaning
happens at **one** deterministic normalization point inside the sim, applied
identically to every source, so raw bits stay raw end-to-end for replay fidelity
(AD-003).

Default rule (tunable in that one place):

- **Left + Right → neutral horizontal** (both cancel).
- **Up + Down → Up priority.**

The default is a gameplay-flavored choice the Strategist may revisit; the
*mechanism* (single sim-side function, source-agnostic) is the architectural
commitment.

## Acceptance criteria (QA-checkable)

1. **Round-trip.** An `InputFrame` serialized and restored is bit-identical.
2. **Reproducibility.** For a source that has produced frame N, repeated
   `get_input(N)` calls return identical values across the run.
3. **Source equivalence.** A Local-device recording, replayed through the Replay
   source, yields a frame stream identical to the original for the whole session.
4. **Dumb layer.** No `InputSource` implementation reads facing, character state,
   or sim state; sources depend only on their own device/buffer/sequence.
5. **SOCD determinism.** Given a raw frame with Left+Right (or Up+Down) set, the
   normalized result matches the specified rule regardless of which source
   produced it, and is produced by exactly one function.
6. **Reserved-bit validity.** A frame with any of bits 12–15 set is rejected as
   invalid by the input boundary.
