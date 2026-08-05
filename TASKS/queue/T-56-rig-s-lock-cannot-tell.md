## T-56 — The rig's lock cannot tell compiling from driving the device
**Priority 4/10** · **Owner:** mac · **Status:** open

**NARROWED 2026-08-04, and the original framing was wrong — recorded rather than rewritten, per
rule 7.** This was filed as "the lock does not survive a killed capture run", after a SIGKILLed
sweep left the rig held and it was released by hand.

**That is not a defect. The lease is TIME-based and self-clearing, and deliberately so.** Its own
header says a pid check "provided NO mutual exclusion while printing that it had", that expiry
"does not depend on any process still existing", and that an expired lease is reclaimed **loudly**
— `EXPIRED LEASE from '<holder>' … reclaiming` — precisely because "an expired lease may mean the
holder DIED MID-RUN". So the mechanism already handles the case the task was filed about. The
hand-release was impatience, not repair: the killed sweep would have self-cleared in 900s. **The
original "done when" — record the owning pid — would have made it worse**, reintroducing the exact
check the design rejected.

Confirmed in the wild the same day: the rig was held by a lease belonging to a GLP-1 agent that had
died on a session limit. It cleared itself. Mac waited it out rather than stealing it, which is
right — forcing a lock whose holder you *believe* is dead is the reasoning a time-based design
exists to make unnecessary, and `testmanagerd` being resident means no one can prove from outside
that nothing is mid-flight.

**The real gap, which both sides converged on independently:** the lock guards ONE resource while
two different ones are being contended. A `xcodebuild` compile contends for CPU; a test run contends
for the **simulator**. One lease over both means either agents block each other for no reason, or —
as observed — the lock warns that `xcodebuild` is already running while the lease is free, because a
worktree agent was compiling without taking it. It cannot currently distinguish the two, so it is
simultaneously too strict and too permissive.

**PROVEN 2026-08-04, and it is no longer a theory.** A T-05 run acquired the device lock after **99
retries** and then died:

> `error: unable to attach DB: … build.db: database is locked. Possibly there are two concurrent
> builds running in the same filesystem location.`

**The rig lock protected the simulator and nothing protected `DerivedData`.** The device was held
legitimately while an agent compiled into the same build directory. So the framing "one lock cannot
tell compiling from driving" is still too generous: **these are two different resources that need two
different locks, and only one of them exists.** A single lease can never be right — held for the
whole build it serialises work that need not be, held only for the run it leaves the build directory
unguarded, which is what happened.

**Done when:** a build and a device run are serialised against each other by **two** leases — one for
`DerivedData`, one for the simulator — with the device lease held only for the run; and the lease
records its holder's pid **as information**, so a waiter can tell a dead holder from a live one
without that pid ever becoming the exclusion mechanism. Demonstrated by a compile and a capture that
neither falsely block nor falsely pass, and by a waiter correctly identifying a dead holder.
