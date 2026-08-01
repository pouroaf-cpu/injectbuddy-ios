# Board — UI audit & PWA parity

Single source of truth for what is done, what is open, and what is deliberately
not being done. Supersedes hunting through ten cycle READMEs.

**Mac owns this file.** Tick items as they land, in the same commit as the work.
Do not tick anything on inspection — every closed item below was closed by a
measurement or a screenshot, and that bar holds. If something can't be verified,
move it to §4 rather than ticking it.

Session of 2026-08-01. Branch `feature/tabview-shell`. Latest `edf59d2`.

---

## 1. Open — assigned

- [ ] **Measure Settings and the confirm-start-day screen.** The only two screens
      the control inventory did not reach (a drawer mis-tap landed on BMI). Both
      are stock `Form`/`List` and are *probably* the same 44 pt list-row treatment
      as the log sheet, but that is a guess and guesses do not get ticked.

## 2. Open — unassigned, needs a human decision

- [ ] **Dashboard information architecture.** The PWA dashboard is tabbed
      (`upcoming` / `history` / `inventory` / `saved` / `calculators` /
      `settings`); iOS is one scroll with next-dose plus all protocols. The iOS
      protocol grid corresponds to the PWA's `saved` tab. Adopt the tabbed IA, or
      keep the single scroll and match only the visual language? Out of scope for
      styling parity either way — see `pwa-reference/README.md`.
- [ ] **Three calculators exist on the web with no iOS screen at all:**
      `bioavailability`, `femalehrt`, `oilblend`. Feature gap, not a config bug.
- [ ] **Greeting shimmer.** Solid `#075E56` ships. SwiftUI desaturates *any*
      multi-stop gradient — measured, see §3 — and both fix routes failed. Filed
      approach if it's wanted back: solid text with a **single-colour**
      translucent band swept as a mask, since single-colour gradients measure
      exact. Not started.
      **Mac's read: feasible, with one constraint that decides it.** A translucent
      *white* band would lighten the ink where it passes and drop contrast below
      threshold mid-sweep — the same failure mode as `#5FE8DA`, arrived at from a
      different direction. The band must be `#0A9D90`, so the worst composite is
      3.37:1 and still legal for the 24 pt heavy greeting. Measurable before
      building. Worth one cycle only if the human actually wants the shimmer; the
      screen reads correct without it and every prior attempt cost a cycle.
- [ ] **Inter vs SF.** Deferred, not rejected. SF was chosen because bundled Inter
      costs the Dynamic Type metrics that protect against the truncation class of
      bug. Revisit only with that trade understood.
- [ ] **Tab bar glyphs** are accessible grey (~6:1) rather than brand-coloured.
      **Mac's read: leave it, it reads as deliberate.** iOS convention is a neutral
      unselected item; the brand is already present in the bar via the selected
      item (`#075E56` + bold). Colouring the unselected ones would weaken a
      selected/unselected distinction that was only just fixed from 2.77:1.

### From the control inventory (`2026-08-01-controls/`) — scope before building

The calculator family is universal: numeric ± fields and every menu picker,
including the barrel picker, are **44.0 pt** at default and **77.35 pt** at AX5.
Four things sit outside it.

- [~] **Log-dose date row — treatment done, TARGET NOT.** The row is now 44.0 pt
      (borders measured at pt 517.85 → 561.85) with the calculator's field
      chrome: r10, 1 pt `#8E8E93`, white. So it no longer reads as a stock grey
      chip.
      **But the effective tap target is still the system chip.** Tested: tapping
      the row on the label side, away from the chip, does **not** open the picker.
      A compact `DatePicker` owns its own hit area and a row cannot take it over —
      unlike the toggle, where the row could just flip a boolean without needing
      system UI.
      **Needs a decision, and it is the same trade §6 covers:** accept Apple's
      control at Apple's metric, or replace the chip with a custom 44 pt row that
      presents a graphical picker. I am not making that call silently.
- [ ] **Log-sheet rows are a different visual language.** Same 44 pt height as a
      calculator field, but separator-delimited list rows on white versus bordered
      boxes with a `#8E8E93` stroke and 10 pt radius. The "height matches, radius
      and border don't, still looks wrong" case.
- [ ] **The log sheet never received the type scale at all.** Raised by the human
      as "that log a dose screen looks stupid, is that font right?" — and it is
      not. `grep -c "Theme.Typeface" LogDoseSheet.swift` returns **0**: it is the
      only screen still rendering stock system typography.
      - `WHICH PROTOCOL?` is stock grey `#85858B` (3.29:1) where every other
        section eyebrow is navy `#001D5C` semibold 13.5.
      - Rows are plain 17 pt regular and **dose-first** — "85mg/wk ·
        Testosterone Enanthate" — the exact single-line dose-first pattern that
        caused the dashboard truncation bug, still shipping here.
      - **`Cancel` is `#0FBCAD` at 2.13:1** — a live contrast failure, the same
        teal-as-text pairing removed everywhere else in the app.
      This is a bug, not a preference: the human read it as wrong from a
      screenshot without knowing any of the above.
- [x] **Toggle target FIXED — verified behaviourally.** The row is now a 44 pt
      `Button` with a `contentShape`, the system switch drawn inside it with
      `allowsHitTesting(false)` so the row is the single tap handler. Retested at
      the *same* coordinate that previously did nothing: tapping x=250 pt now
      flips BMI metric → imperial (24.69 Normal → 25.82 Overweight). Native
      `UISwitch` kept; `DESIGN-PARITY §6` intact.
      <details><summary>original finding</summary>
- [x] **Toggle: only the ~51×31 pt switch is tappable — CONFIRMED BEHAVIOURALLY,
      and it is a real touch-target violation.** The "isn't the whole row the
      target?" hypothesis assumed a `Form` row; this is not one. It is a bare
      `Toggle(...).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)`
      in the calculator's own `VStack` (`CalculatorScreen.swift:374`), and
      `maxWidth: .infinity` widens the *layout* frame without extending the hit
      area — there is no `contentShape`.
      Tested on BMI "Imperial units": tapping the row at x=250 pt, same y as the
      switch, did **nothing**; tapping the switch at x=30 pt flipped it (metric →
      imperial, BMI 24.69 → 25.82). So 31 pt tall is genuinely all a user can hit.
      **Fix is NOT to replace the `UISwitch`** — that would be off-platform and
      lose the system's accessibility behaviour, and `DESIGN-PARITY §6` keeps
      native controls native. Give the row a 44 pt `contentShape` that toggles the
      binding, and keep the system switch inside it.
- [ ] **`PrimaryButton` renders two heights at AX5** — 91.3 pt on the calculator,
      71.7 pt in the log sheet, from the same component. The log sheet places it
      in a `List` row with `.listRowInsets(EdgeInsets())`, which constrains it, so
      it stops scaling with Dynamic Type while the calculator's grows.

## 3. Closed — with the evidence that closed it

Safety and accessibility
- [x] **AX5 unit truncation.** `Draw… 0.25…` → `Draw per injection / 0.250 mL`.
      Primary rows stack label-above-value; no value+unit pair carries a
      `lineLimit`. cycle1/04.
- [x] **Hero blanking the primary CTA** while the keypad is up. cycle2/03.
- [x] **Result card clipping the field being edited.** cycle2/03.
- [x] **Result bar ate ~64% at AX5** → 32.6%, collapses to primary + CTA.
- [x] **Input borders 1.3:1** → `#8E8E93` at 3.26:1. Mac reopened this against
      its own prematurely-closed finding.
- [x] **Every failing contrast surface.** Dose readout and CTAs 2.38 → 15.79:1;
      hero glyph 2.38 → 6.43:1 (the last one, on the most prominent control);
      empty-state action and error-banner Retry, both found unprompted;
      danger `#FF5757` 3.11 → `#A31313` 7.90:1.
- [x] **Over-capacity barrel warning** uses icon **and** text, never colour alone.

Data integrity
- [x] **iOS protocol saving never worked** — every insert refused by RLS because
      `user_id` was omitted. The read path omits it deliberately (RLS scopes
      SELECTs) and that assumption was carried into the write path, where the
      `WITH CHECK` made it fatal. Sourced from the session inside the data layer.
- [x] **No dedup on protocol saves.** iOS bypasses `/api/dosages` entirely
      (direct PostgREST). Fixed at the database: `UNIQUE (user_id,
      calculator_type, config)` on jsonb. Verified by count — 99 rows, two
      identical saves, 100 rows, 0 duplicate groups.
- [x] **`.upsert` rejected** in favour of insert-then-recover-on-23505.
      PostgREST resolves upsert to `ON CONFLICT DO UPDATE`, which would overwrite
      `start_date` with today and shift every calendar occurrence.
- [x] **Config shapes vs ground truth.** 9 web-backed slugs verified against the
      real rows. Three bugs fixed: the GLP-1 family was grouped in one
      `configExtras` case but the web writes semaglutide differently from
      tirzepatide/retatrutide; `hcg` had inherited the injectable mode pair.
- [x] **Five stale `/api/dosages` comments** corrected — they described a write
      path iOS has never used.

Parity and chrome
- [x] **Input control inventory** — every distinct control measured at default and
      AX5. Verdict: not universal; the calculator family is, four things outside
      it are not (now itemised in §2). Killed the suspicion that pickers differ
      from ± fields — both are exactly 44.0 / 77.35 pt, because cycle 2 floored
      pickers with the same `Theme.minTarget`. Confirmed the log sheet as the
      off-family screen. `2026-08-01-controls/`.
- [x] Palette + type scale into `Theme.swift` (it had neither).
- [x] Dark mode removed; `UIUserInterfaceStyle` via `project.yml` (not the
      generated plist), verified surviving `xcodegen generate`. Docs swept,
      including the `SCREENS.md:15` toggle that specified it.
- [x] Protocol cards no longer truncate the compound name — seven were, two were
      indistinguishable.
- [x] Navy header squares, centred teal wordmark, density, per-compound spine.
- [x] **Colour roles settled** — navy = actions, teal keeps the FAB. Taken from
      the PWA's real usage, not a hierarchy principle. `DESIGN-PARITY.md §8`.
- [x] **Centre tab slot drew its own syringe glyph** under the hero circle —
      removed the glyph rather than covering it. cycle8/02.
- [x] **Hero overlap**, all eight screens scrolled to content end, plus the AX5
      collision check. cycle9.
- [x] **Calculator's pinned CTA** −12.7pt → +3.3pt. `heroOverhang` was *not* the
      fix and 22→38 moved it zero pixels: an outer `safeAreaInset` reaches
      scrolled content but cannot lift a sibling inset pinned further in.

## 4. Known and not knowable

- **Which screens already reserved room for the hero before the fix.** Overlap
  was only ever demonstrated on the dashboard and calculator; the other six were
  never shown either way. Reconstructing it means rebuilding the old binary to
  answer a question that changes nothing.
- **`eod`, `reconstitution`, `bpc157blend` config shapes.** No web rows exist, so
  there is no ground truth to compare against. Internally consistent; that is all
  anyone can say.
- **No PWA capture for the calculator or log-dose screens.** Parity on those two
  is structural-only. Do not invent a target.
- **PII** — the drawer and Settings captures contain a real email and avatar.
  Repo is private. Blocker on ever making it public.

## 5. Rules earned the hard way

1. **Internally consistent code is not evidence.** Three times this session code
   that was correct by inspection was wrong against reality: the RLS refusal, the
   `/api/dosages` assumption, the GLP-1 grouping. Each took minutes to settle by
   looking at the running system instead of the source describing it.
2. **Measure before changing a constant.** `heroOverhang` 22→38 was rebuilt and
   re-measured to *identical pixels* before being reverted. Shipped on suspicion
   it would have looked fixed on the dashboard while costing every screen 16pt.
3. **Contrast is symmetric.** Swapping foreground and background changes nothing.
4. **An outer `safeAreaInset` cannot lift a sibling inset pinned further in.**
   Anything pinned needs clearance where it is pinned.
5. **A montage is a survey instrument, not a measuring one.** A 12.7pt overlap
   read as "grazing" off a downscaled 4272px image.
6. **If taps die but `simctl` still screenshots, check the login session** before
   touching the Simulator — CoreSimulator is a daemon with no display dependency,
   so the symptom points the wrong way.
