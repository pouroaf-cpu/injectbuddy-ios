# Board — UI audit & PWA parity

Single source of truth for what is done, what is open, and what is deliberately
not being done. Supersedes hunting through ten cycle READMEs.

**Mac owns this file.** Tick items as they land, in the same commit as the work.
Do not tick anything on inspection — every closed item below was closed by a
measurement or a screenshot, and that bar holds. If something can't be verified,
move it to §4 rather than ticking it.

Session of 2026-08-01. Branch `feature/tabview-shell`. Latest `0ac3c4d`.

---

## 1. Open — assigned

- [ ] **Input control inventory.** Every distinct data-input control: height (pt),
      corner radius, border, fill, label placement, unit inline vs caption.
      Measured at default **and** AX5. Then a one-line verdict: universal, or
      here is the list that isn't. Evidence for anything reported inconsistent.
      Suspicions to confirm or kill: (a) menu pickers are not floored at 44pt the
      way a field containing a 44×44 stepper is, so they likely differ;
      (b) the log-dose sheet is the least-reworked screen and its
      `Day / 31 Jul 2026` row reads as a stock chip. **Inventory only — no fixes
      until the scope is visible.**

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
- [ ] **Inter vs SF.** Deferred, not rejected. SF was chosen because bundled Inter
      costs the Dynamic Type metrics that protect against the truncation class of
      bug. Revisit only with that trade understood.
- [ ] **Tab bar glyphs** are accessible grey (~6:1) rather than brand-coloured.
      Logged, low value, nobody assigned.

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
