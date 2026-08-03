# AUDIT — the procedure

**Mac side. Only the owner calls an audit.** Neither Claude starts one on its own initiative — it is
expensive and it competes with shipping. If a sweep looks warranted, say so in a line with what it
would cost, and wait.

An audit is the one time device screenshots are the deliverable. Everything else visual is a
snapshot test (`UX-UI-RULES.md` §1).

---

## The sequence

### 1 · Mac captures every screen

One XCUITest run, `content_size` at default, set and reset in the same command.

**Every screen means every screen:**

- Shell — Dashboard, Calendar, Log-dose sheet, Tools, Add
- All fifteen calculators
- The Add funnel and its confirm-start step
- Settings, and the drawer
- Onboarding — thirteen screens, six paths, from the preview target (no login needed)
- Both onboarding end states

**Before every shutter, assert you are on the screen you are about to name.** Not a wait, not a
sleep — assert something only that screen renders. Three frames in the old archive were photographs
of the previous screen for two capture cycles because nothing checked, and each was a good
photograph of a real screen under the wrong name. Nothing about the image looked wrong.

**Screens that render the account's email or avatar** — Settings, the drawer — are captured with the
identity scrolled off or cropped, and the crop rect stated. Assert the email is absent before the
shutter; a scroll that did not move looks identical to one that worked.

### 2 · Label and save

`docs/ui-audit/<YYYY-MM-DD>-audit/`, one file per screen:

```
02-dashboard.png
06-calculator-trt.png
onboarding-05-setup.png
```

Name it for what it is. The folder gets a `README.md` with the commit the app was built from, the
run's start and end, and how many frames were taken against how many were expected.

### 3 · Mac checks it got everything

**Count both ways.** The list of screens expected against the list of files written. Anything not
captured is **named with the reason** — never silently absent. A missing frame and a frame nobody
asked for look the same in a folder.

### 4 · Mac audits against the rules

Walk `UX-UI-RULES.md` over every frame. Report findings as: the frame, the rule, what is wrong, and
**what you looked at** — a finding covers only the sample it was drawn from. "Sheared on BPC-157" and
"sheared on BPC-157, of fifteen calculators checked" are different claims and only the second is
useful.

Judge before measuring. Ask "would I ship this frame?" first; numbers come second, and only for what
judgment flags.

### 5 · Tell Windows

Post that the audit is captured, with the folder, the commit, and the count both ways. **Push the
frames** — an audit whose evidence exists on one machine is not an audit.

### 6 · Windows audits the same frames, independently

Windows walks the frames against `UX-UI-RULES.md` **without reading the Mac's findings first**. Two
readings that share an author are one reading. Then the two lists are compared:

- **Both found it** — it is real.
- **One found it** — worth a second look, not a dismissal.
- **Neither found it** — the rule was not checkable from a frame. Say so; that is a finding about
  the audit, not about the app.

---

## What closes and what does not

- **Nothing is ticked on inspection.** A finding closes on a measurement or a photograph.
- **A frame is evidence only about the screen it proves it is.**
- **Anything unverifiable goes to "not knowable"**, not to a tick.
- The audit produces a list. **Fixing is a separate decision** — under the MVP posture most findings
  are filed, not worked.
