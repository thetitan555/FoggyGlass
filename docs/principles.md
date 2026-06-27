# Design Principles

> The "how." The Architect enforces these in the spec and QA audits against
> them. The charter (**charter.md**) says what we believe; these say how that
> belief shows up in the build.

### Clarity is craft, not data

"-9" under the combo counter is good; a distinct block-reaction sprite that
*shows* the punish window is better. Information lives in the game's visual
language wherever it can, and in the HUD only when it must. The art teaches
before the HUD does.

### Depth and clarity are distinct axes; keep both high

Richer decisions and clearer reads are not the same goal, and a mechanic that
delivers one does not automatically deliver the other. We pursue both at once
and assume neither comes free with the other — including the possibility that a
new system, even a UI-tied one, turns out to be the right clarity instrument.
Nothing is ruled out in advance.

### No knowledge checks; the answer is discoverable in the moment

Strong, character-defining tools are good design, and a character may carry a
whole library of options that each demand a different response. But the correct
response must be readable *as it happens* — never gated behind prior metagame
knowledge. The friction we want is *I can see what to do and have to read or
execute it live*; never *I lose because I didn't already know*. High-level
matchup strategy is emergent and metagame-dependent, so we neither design nor
test against it. We design for the in-the-moment legibility of every option
instead.
