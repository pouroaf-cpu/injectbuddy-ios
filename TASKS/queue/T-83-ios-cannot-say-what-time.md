## T-83 — iOS cannot say what time a dose was taken; the web can
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** the web's `DashLogFlow` has a `<input type="time">` and passes it down to
`markDone(..., injectionTime)`; `DoseHistory`'s detail sheet can edit it afterwards. iOS has no such
control on either path.

**What it costs, now that T-51 is closed:** a dose logged on the day it happened carries the real
clock time. A dose logged for **any other day** — the log sheet lets you pick one — carries the web's
`12:00` default, because the app has not asked and will not invent a time. That is the honest answer
and it is the same answer the web gives when its own picker is untouched, but the web at least offers
to be corrected. A user catching up on three days of missed logs gets three noons and no way to fix
them from the phone.

**Done when:** the log sheet accepts a time, defaulted to now for today and to 12:00 otherwise, and a
dose logged with a changed time reads back with that time.
---
