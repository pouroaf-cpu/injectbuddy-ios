## T-25 — The new DOSE AMOUNT field straddles the pinned CTA bar at rest
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** in the T-53 evidence frame (`docs/ui-audit/2026-08-04-logdose/01-logdose-sheet-t5352.png`)
the `DOSE AMOUNT` header is fully visible and the field under it is cut across the middle by the top
edge of the `Log dose` bar — `74.5` and its `mg` are both legible, the bottom of the field is not.
Default text size, unscrolled, five protocols in the list.

**Why it matters:** UX-UI-RULES §3 is explicit — "A CTA you can reach that commits a field you
cannot is a failure, not a partial pass." This is the field T-52 added, and it is the number the
user is being asked to confirm.

**Say what it is NOT.** Not clipping: the bar is a `safeAreaInset`, it reserves its height, and the
form scrolls clear of it. This is the at-rest position of a form whose protocol list already fills
the viewport — the same shape as T-20 on the calculator, and it gets worse with every protocol the
account holds. **And the site picker and the day row were already below the fold before this
change**, so the sheet as a whole has been failing §3 since T-03; the amount is the newest and the
most consequential of the three, not a new class of problem.

**The far worse half of this WAS fixed, in the same pass.** The second frame from that run
(`02-logdose-keypad-before.png`) shows the sheet with the keypad up and **the amount field entirely
off-screen** — the user typing a dose they cannot see, behind the keyboard and the pinned bar
together. That is not a straddle, it is a blind entry on the write path, and the round-trip test had
gone GREEN through it because `typeText` does not care whether a field is visible. The CTA is now
withdrawn while the keyboard is up (the treatment `MainShell` already gives the raised hero), the
keypad carries a `Done` (a `.decimalPad` has no return key, so without one the sheet would be a
one-way door), and the UI test asserts `isHittable` on the field WHILE it is focused.

**Not fixed by eye.** Re-ordering the sections so the amount leads would put "how much" above "of
what", and that trade needs measuring at default and AX5 rather than guessing.

**Done when:** measured against the amount field the way `PinnedBarReachabilityUITests` measures the
calculator's, and either shown reachable at default and AX5, or the sheet re-ordered with a frame
showing the field clear of the bar at both sizes.
