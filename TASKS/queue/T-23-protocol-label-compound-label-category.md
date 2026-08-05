## T-23 — `protocol_label`, `compound_label` and `category` are NULL on every iOS-written dose
**Priority 3/10** · **Owner:** mac · **Status:** open

**What:** the web writes four display-snapshot columns on every pin (`/api/dose-log` POST).
T-52 filled `dose_label`, which is the one of the four that can differ from the plan. The other
three are still absent from `NewDoseLogPin`.

**Why nothing is visibly broken today:** `DoseHistory.tsx:85-90` falls back to the live protocol for
all three. **Why it is still a hole:** they exist to be a snapshot — the history is meant to keep
describing what was taken after the protocol is edited or deleted. Web-written rows survive that,
iOS-written rows do not.

**Done when:** the three columns are on the iOS write and a logged row carries them, or it is
recorded here that iOS deliberately relies on the fallback.
