# Handover — 2026-08-02, evening

Written at a deliberate stop, not a drift. The next item (**F-E**) is a control change
across 12 call sites in a dosing app, and doing it at the end of a very long session is
the rushed pass this session already argued against. Its shape is written out below so
whoever picks it up starts cutting instead of re-deriving.

Branch `feature/tabview-shell`, tip `c0f69f3`. Everything below is committed and pushed.
`BOARD.md` is authoritative; `TASKLIST` on the cross-claude bus is the live queue.

---

## 1. What shipped

| | |
|---|---|
| **T20** | The pinned result bar stands down on a **measured share** of the content area, not a Dynamic Type category. Five candidates laid out hidden at their own ideal heights; the tallest fitting 40% wins. Default: 52.40% → 35.40%. `369fbc5` |
| **T21** | Plate → `.regularMaterial` + hairline; card gains a stroke. **Closed as NOT DELIVERED** — the tone changed, the blur did not, because nothing renders behind the bar. `369fbc5` |
| **T19** | The renderer publishes whether a value truncated. Found that **result rows had no truncation check at all**. `98743bc` |
| **Frames** | `IB2245749`–`IB2245753`, serialised and logged. `0d97f31`, `56dd1fe`, `23f102a` |

Three new suites, **each shown red before being trusted**:

- `PinnedBarReachabilityUITests` — D5 as geometry. Red at `BAR_SHARE_CAP=0.55` on
  `control_injPerWeek`, the control the T20 finding names.
- `AuditFolderConsistencyTests` — frame tables against folder contents, both directions.
  Went red **eleven times** on its first run against real data.
- `LeafOverlapUITests` — no two content leaves share pixels. Red on
  `Compound` × `Oxandrolone (Anavar)`, 148.6 × 49.3pt.

## 2. F-E — the next item, and its shape

**WHY THIS WAS DEFERRED, and it is not "it was late".** That reading invites the next
session to skip the care, so here is the actual reason. Four things ride on this control
and one of them — `unique(_:type:)` — **fails at RESOLUTION**. If the swap makes
`control_<key>` match two elements, the failure does not present as a wrong number on a
screen; it presents as an assertion that has quietly stopped meaning anything, in a suite
that still reports green. That is the exact failure class this entire day was spent
removing: six checks were found reporting success while observing nothing. A session that
knows this re-asserts all four invariants. A session that reads "it was late" will not.

**The finding.** Every menu picker draws OUTSIDE its own control at large text once its
selected string is long enough, landing on the label above and the field below. Evidence
`IB2245752` (Steroid Dosage · Compound) and `IB2245753` (TRT · Ester).

**It is a CONTROL change, not a screen change.** `FieldRow.content` is the only call
site; `.picker` and `.stringPicker` both render
`Picker(...).pickerStyle(.menu).fieldChrome()`. **12 picker fields across 8 calculators**:
TRT Dose (Frequency, Ester) · TRT & EOD (Ester) · Peptide (Dose unit) · Semaglutide /
Tirzepatide / Retatrutide (Concentration, Dose) · Free T Index (TT unit) · Steroid
Dosage (Compound).

**Ruled out, do not retry:** `.fixedSize(horizontal: false, vertical: true)` on the
picker. Measured after the change — the same 193.0 × 183.3 text in the same
371.3 × 78.3 button, **identical to the byte**. `.pickerStyle(.menu)` does not let its
label's multiline height reach the control's frame. Recorded at the call site.

**Ruled out, settled:** a character-length threshold. SF is proportional so a count is a
bad proxy for rendered width, and a threshold builds two layout paths where the rare one
is the untested one and correctness depends on a constant measured on one font, one
device width and one type size.

**The direction:** replace the style with a `Menu` whose label is laid out here, so the
chrome grows to its content and every string in the catalog is correct by construction —
the 34-character worst case (`Equipoise (Boldenone Undecylenate)`,
`Primobolan (Methenolone Enanthate)`), the 20 that produced the frame, and the compound
nobody has added yet.

**Four things ride on that control. Each is a way to ship a regression quietly, and each
must be asserted AFTER the swap, on a screen measured before it:**

1. the 44pt tap target (`Theme.minTarget`),
2. the accessibility label,
3. the `control_<key>` identifier — the reachability and overlap suites both address it,
4. the `unique(_:type:)` helper — an identifier that starts matching two elements fails
   at resolution before any assertion runs.

**Pass condition, and it existed before the fix, which is the right order:**
`LeafOverlapUITests` carries the picker overflow as **named AX5 debts** — the pairs from
`IB2245752` and `IB2245753`:

    Steroid Dosage  Compound × Oxandrolone (Anavar)
    Steroid Dosage  Oxandrolone (Anavar) × Vial strength
    TRT Dose        Ester × Testosterone Enanthate

None of the three is marked `isIntermittent`, so **each is asserted to still occur**.
When the fix lands they stop occurring and the suite goes RED telling you to delete
them — that is the pass condition firing. Delete those three entries; leave them and the
suite stays red. The other five AX5 entries are the tab-bar and hero collisions and are
NOT yours to remove.

**NOT covered, and do not assume otherwise (C8):** `CyclePlotterScreen` renders two
`.menu` pickers of its own **without** `fieldChrome`. Different chrome, separate call
sites. Say so in the commit rather than leaving it to the reader.

**§5.33:** state what surface the fix is aimed at when closing it. This is the first
finding where that column would have mattered from the start.

## 3. Open, in queue order

1. **F-E** — the picker overflow, above.
2. **F-C** — `Frequency` sheared with the keypad up (`IB2245751`). Same class; the
   keypad-up state is where F11 and T3 both lived.
3. **T26** — result panel / barrel-fit strip. Spec on origin, branch
   `docs/result-panel-spec` (`bd43542`). **Read the PNG first.** In-scroll card only.
   Mac owes win two reads: whether the 14pt track reads as furniture at default and
   survives AX5 (**measure, do not eyeball**), and the accessibility question below.
   The duplicated headline figure (F-B) rides with this.
4. **T27** — 3 mL barrel still shows `Units (U-100)`, a units figure for a barrel with no
   units scale. Filed unbundled deliberately.
5. **T25** — nothing renders behind the pinned bar.
6. **T11**, **T8**, then T12/T13/T15/T16.

**Blocking T26 §5:** `.accessibilityHidden(true)` **does not remove the hero glyph** —
measured with the flag on the composed hero and again with it applied directly to the
`Image`, byte-identical frame both times. The spec relies on that modifier to keep a
decorative duplicate of the dose figures out of the tree. It must not ship on that
assumption: assert the absence on the strip itself, red first with the modifier removed.
**No working mechanism has been identified.**

## 4. Needs the human — three items, none of them ours to decide

1. **QA password rotation is outstanding.** It was relayed over the cross-claude bus on
   2026-08-02 at the human's instruction and now sits in the bridge's message database on
   **both** machines. Nothing else carries it — not a doc, not a commit, not a failure
   message — but that is one copy too many and rotating it is a decision only they can
   take.
2. **Auto-login is not configured on the Mac.** The recurring "GUI session dropped, taps
   are dead" failure is a shell in the `Background` launchd domain, not a login screen
   (`/dev/console` is owned by the user; `launchctl managername` returns `Background`).
   FileVault is **off**. The permanent fix is auto-login plus sleep/lock off plus
   `caffeinate`, and `launchctl asuser` needs root. None of it is needed for the current
   pipeline — CoreSimulator is a daemon and XCUITest drives inside the app runtime — so
   this is a convenience decision, not a blocker.
3. **Database CHECK constraints** on `profiles.preferred_*` and `logging_interests`, so
   neither client can write a bad enum — the same shape as the dedup unique index. Schema
   change (C4).

## 5. Rig state

iPhone 16 Pro / iOS 18.3, booted, signed in as `devtools`, **content size reset to
`large`**. Not erased, so first-boot paths (`addUIInterruptionMonitor`,
`dismissDisclaimerIfPresent`) still have **no coverage** — do not read a green suite as
evidence that first run works.

Full suite green at default: 30 unit tests, 4 wiring, 1 truncation sweep, 3 reachability,
3 folder-consistency. `LeafOverlapUITests` is **GREEN AT BOTH SIZES with its debts named** — 8 at AX5, 4 at
default. Green with named debts rather than red, because **a red suite cannot report a new
failure**: a third overlap appearing tomorrow would land in an already-red run and change
nothing anyone could see, which defeats the check on the day it was built. Naming them is
not closing them — every one is still open in `BOARD §1`.

The four default-size entries are marked `isIntermittent`, which is a **real weakening,
measured rather than assumed**: both pairs involve content near the bottom of a scrolling
form, so whether they collide depends on where the form is sitting, and each was observed
present in one run and absent in the next on the same screen at the same size. What is
given up is the assertion that those specific pairs must still occur. What is kept is the
suppression when they appear, and the failure on any UNNAMED overlap — so the suite can
still speak.

**THE INTERMITTENCY IS A PROPERTY OF UNCONTROLLED TEST STATE, NOT OF THE DEFECT.** The
defects do not come and go; the OBSERVATION does, because the frames are read at whatever
scroll offset the run happens to leave the form at. Pin the scroll position before
reading and the intermittency disappears — and the moment it is deterministic,
`isIntermittent` comes off and the both-ends assertion goes back on, restoring the
mechanism to full strength.

**Until that is done these four entries CAN NEVER BE PAID OFF AUTOMATICALLY.** A fix will
not make the suite go red asking for their deletion, the way the three picker entries
will. **They must be deleted by hand** when the hero/disclaimer collision and the
`Units (U-100)`-into-the-tab-bar finding are closed. Four entries that cannot self-retire
are a small debt tonight and an invisible one in a month; whoever holds this should know
they are holding it.
