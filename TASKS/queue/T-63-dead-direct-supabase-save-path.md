## T-63 — A dead direct-to-Supabase save path in the reconstitution calculator
**Priority 2/10** · **Owner:** win · **Status:** open

**What:** `public/app.js` defines two things inside `ReconstitutionPage` that nothing uses:
`doSave` (`:8152`) and `nameCard` (`:8177`), a "Peptide name" input. Each is referenced exactly once
in the whole file — its own definition. The calculator's real save path, `handleSave` →
`/api/dosages`, is correct and unaffected.

**Why it is only a 2, stated so nobody re-raises it as urgent:** `nameCard` is never rendered, so
**there is no visible field for a user to type into and have discarded.** It is not the T-22 pattern;
it is leftover machinery from an earlier flow.

**The one thing that makes it worth writing down at all:** `doSave` posts **directly to
`IB_SUPA_URL + '/rest/v1/peptide_protocols'` from client JavaScript**, bypassing `/api/dosages` and
whatever validation lives there. Dead, so harmless today — but it is a wired-up-and-forgotten hazard
rather than an unused variable, and if anyone ever re-attaches it they inherit the bypass.

**Deliberately not fixed on sight:** `public/app.js` had uncommitted in-flight changes from other
work when this was found, and it is a very large file. Editing it mid-flight to delete dead code is a
poor trade. Do it when the tree is clean.

**Done when:** both are deleted, or `doSave` is repointed at `/api/dosages` if the peptide-name flow
is actually wanted.

---

### Sweep record — the "control that discards its value" class, 2026-08-04

**Recorded because a clean sweep is a result, and without this note the next person runs it again.**

After T-22 (the log sheet's `DOSE AMOUNT` accepted a typed dose and wrote the plan) and the dead
`currentPw` in the settings password panel, `components/`, `app/` and `public/app.js` were swept for
the same shape: **a control that appears functional but whose value never reaches the thing it claims
to affect.**

Every dose-, date-, site- and concentration-relevant control was traced from its set-site to its
send-site. Checked and clean: dashboard dose logging and editing, all six settings panels,
personalisation, the cycle planner's add/edit flows, blood-test review, calendar quick-add, and **all
~19 calculator save paths in `public/app.js`** — every visible input reaches its persisted payload.

**T-63 above is the only survivor, and it is dead code rather than a discarded value.** So the class
appears to be closed at two real instances, both already fixed.
