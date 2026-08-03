# SPEC — Onboarding flow, as its own runnable app target

**Owner-directed, 2026-08-03.** Source of truth for this spec is three files the owner produced and
which live only on the Windows machine (`Downloads/newdashboard1.html` — interactive wireframe with
the branch logic, `newdashboard2.html` — the copy deck, `newdashboard3.csv` — the same copy as a flat
page table). **The Mac cannot read them.** Everything in them that matters is transcribed here; where
this file and a memory of those files disagree, this file wins.

Nothing in this spec is a ship-blocker for the current launch batch. It starts when the batch sweep
is done, per the MVP posture.

---

## 1. Why a separate target, and what "separate" means

> ### THIS FILE IS THE ROUTE AND THE COPY. IT IS NOT THE WRITE CONTRACT.
>
> **`docs/WELCOME-AND-ONBOARDING.md` §3** specs the five-step personalisation flow that writes
> `public.profiles`. It is open, unbuilt, and **not superseded by this file** — the two are
> different halves of one surface. **`docs/DATA-CONTRACT.md` is authoritative for what the database
> accepts**, and **RLS refuses a bad write silently**: no error, no row, and a call site that only
> checks "did not throw" cannot tell the difference.
>
> **Read both before implementing a real sink.** This pass ships a no-op sink, so nothing here can
> go wrong yet — the risk arrives the day someone writes a real one while holding only this file.
>
> ### ⚠️ THE TWO FLOWS BOTH ASKED FOR A NAME. SETTLED 2026-08-03 — READ THIS BEFORE BUILDING §3.
>
> `WELCOME-AND-ONBOARDING.md` §3 step 1 collects `nickname` — *"How should we greet you?" / "Make the
> dashboard yours"*. **Screen 1 of THIS flow now collects a name too, and both run immediately after
> signup.** Left alone, a new user is asked their name twice inside a minute, by two screens, in two
> voices. Nobody had noticed they were the same question: §3 predates the owner's instruction and the
> instruction does not mention §3.
>
> **Owner's call, via win: iOS asks for a name exactly ONCE, and screen 1 is that once.** It writes
> **`profiles.nickname` — the same column §3 step 1 owns, not a new one.** That is what dissolves the
> collision rather than managing it.
>
> **So if §3's five-step personalisation is ever built on iOS, its step 1 is SKIPPED when a nickname
> already exists.** Same column, so it is a prefill question rather than a second ask. The web has
> two surfaces because they grew at different times; we are not obliged to import that.
>
> The three constraints that are in neither this file nor the wireframes it was written from:
> - **A skipped step writes the DEFAULT, never a null.** Three `profiles` columns are NOT NULL and
>   `logging_interests` is a NOT NULL array; steps 2–5 are all skippable.
> - **`onboarding_completed_at` is set ONLY on completion.** It is the flag that stops the flow
>   reappearing, so setting it early strands the user and setting it never loops them.
> - **No rounding on the way in.** A user entering 180 lb must get 180 lb back. Store metric always;
>   the unit preference is display only. Conversion constants are in `WELCOME-AND-ONBOARDING.md` §3.

The owner's instruction: *"I think we make this as a separate app, its own folder inside the ios, and
then we can test it without a login. All we need is the onboarding screens."*

**Screen 1 assumes the user has already signed up.** That is a premise of the flow, not something
this target implements — there is no auth in it, no session, and no network. The flow begins where
it would begin in the real app: immediately after account creation.

**Finishing loops back to screen 1 with state cleared.** Both end states — `dashboard` and `locked`
— return to `welcome` and reset **`segment`, `exp`, `skipped`, `plan` and every collected field.**
This is what makes it a testing surface rather than a demo: an endless walk-through, so six paths
cost one build and no relaunches.

**Reset every field, not just the route.** A stale `segment` leaking across a loop shows the wrong
benefit copy on the next pass and reads as a copy bug — a defect in the thing being tested, blamed
on the thing that is correct.

**Do not add a "you have finished" interstitial.** The loop is the end state. Keep the wireframe's
back and restart affordances as specced.

**Build it as a second app target in the same repo and the same Xcode project — not a second repo.**

- `OnboardingPreview` is an app target whose root view is the onboarding flow itself. **No auth, no
  `RootView` gate, no Supabase, no network.** Launch it in the simulator and you are on screen 1.
  That is the whole point: the flow becomes testable in seconds without a sign-in, and sign-in is the
  measured bottleneck on this rig (~20–25 signed-in checks/hour against an 11s no-op rebuild).
- The flow's source lives in **`Sources/OnboardingKit/`**, a folder with **no dependency on
  `Core/Backend`, `Core/Auth`, or any view in `Features/`.** It may depend on `Core/Theme` and on
  plain models it defines itself. Both targets include the folder.
- The real app mounts the same root view later, between `DisclaimerGate` and `RootView`. **Do not
  wire that up in this pass** — the preview target is the deliverable.

If `OnboardingKit` needs anything from the app that would drag `Core/Backend` in with it, that is a
finding about the boundary — say so rather than importing it.

**Persistence contract.** The flow writes nothing. It fills an in-memory `OnboardingState` and hands
it to an `OnboardingSink` protocol at the end. The preview target's sink is a no-op that prints.
The real sink comes later and is out of scope here.

---

## 2. State

```
segment:  .trt | .glp | .aas | .other        // set on screen 2, mandatory
exp:      .first | .some | .adv              // set on screen 3, mandatory
skipped:  Set<Step>                          // reminders, inventory, firstDose
plan:     .trial | .paid | .declined | nil
units, compound, dose, frequency, extraCompounds[]
reminderTime, vialCount, vialSize
```

`segment` selects the benefit copy and the paywall headline. `exp` changes the route, the
benefit CTA and its Skip, and three
individual lines. Nothing else branches.

---

## 3. The route

Progress bar percentages are part of the design, not decoration — the bar **starts at 25%** on the
first screen (endowed progress) and the values below are exact.

| # | Screen | Bar | Notes |
|---|---|---|---|
| 1 | `welcome` | 25% | **REPLACED 2026-08-03** — congratulation **+ the name field**. See §3.1. |
| 2 | `pathway` | 35% | **Branch 1**, mandatory, sets `segment` |
| 3 | `experience` | 45% | **Branch 2**, mandatory, sets `exp` |
| 4a | `benefit1` | 55% | copy by `segment` |
| 4b | `benefit2` | 62% | **skipped entirely when `exp == .adv`** |
| 4c | `benefit3` | 69% | **skipped entirely when `exp == .adv`** |
| 5 | `setup` | 76% | required fields |
| 6 | `reminders` | 84% | optional, skippable |
| 7 | `inventory` | 90% | optional, skippable |
| 8 | `firstDose` | 97% | the aha moment — core value **before** the paywall |
| 9 | `paywall` | 100% | headline by `segment` |
| 10a | `dashboard` | — | end state, accepted |
| 10b | `locked` | — | end state, declined |

**Branch rules, complete:**

1. `exp == .adv` → **one** benefit screen, then straight to `setup`. Its CTA reads **"Set me up"**,
   not "Next", and it shows **no Skip**.
2. `exp != .adv` → all three benefit screens, each with a ghost **"Skip"** that jumps to `setup`.
3. `exp == .first` → `setup` shows the extra line: *"Not sure of your exact protocol? Start with what
   you know — you can change everything later."*
4. `exp == .adv` → `setup` shows **"＋ Add another compound"** up front. **No other experience
   level sees it at all** — not lower down, not behind a disclosure. Confirmed against the
   wireframe and the copy deck 2026-08-03: the row is rendered conditionally on the veteran
   branch with an empty string as the alternative, and the deck says *"Variant — years deep:
   shows '＋ Add another compound' up front."* **This sentence used to read only "up front",
   which did not say whether other levels saw it lower down — the implementer asked, and this
   is the answer rather than a judgement call.**
5. `exp == .adv` → `firstDose` body reads *"You know the drill. One tap, and it's on the record."*
   Otherwise *"One tap. That's the whole habit. Everything after this is momentum."*
6. Paywall opener varies on how much was skipped: fewer than two skips →
   *"— protocol set, reminders on"*; otherwise *"— your protocol, set up your way"*.
7. `dashboard` next-dose card reads *"reminder set ✓"* or *"set a reminder?"* depending on whether
   `reminders` was skipped.

Back must work from every screen. The wireframe also has a restart; the preview target should keep
one, as a debug affordance only.

### 3.1 Screen 1 — the congratulation and the name (owner-directed 2026-08-03)

Owner's words: *"the first screen should be Congratulations you have taken the first step, what
should we address you by? (e.g. get name input). All other screens are then addressed personally
after that."*

**It REPLACES `welcome`, it does not precede it.** Both are congratulation beats and two in a row is
one too many. **The step case stays `.welcome`** — it is still screen 1, and the name is referenced
by the route arrays, the bar table, the accessibility identifiers and the tests; renaming is churn
with no user-visible effect.

**THE BAR STAYS AT 25% AND NO OTHER PERCENTAGE MOVES.** Deliberate — it keeps §3's measured table
valid.

| | |
|---|---|
| Congratulation line | ⚠️ **PLACEHOLDER.** The owner's line is not written yet. Build against a **visibly** fake string — not a plausible sentence someone will later mistake for his. |
| Prompt | **"What should we address you by?"** — **from his instruction**, not from the three source files. Different provenance from the rest of §4; noted so nobody hunts for it in a wireframe. |
| Field placeholder | **"What should InjectBuddy call you?"** — **his SHIPPED copy**, verbatim from `PersonalisationForm.tsx`. |
| Field label | `Nickname` · `optional` |
| Required? | **NO. Optional, with a Skip.** |
| Max length | **60**, enforced client-side. The server 400s above it — *"Nickname must be 60 characters or fewer"* — and the last possible moment is the worst place to find out. |
| Stored | `OnboardingState.name` → **`profiles.nickname`**. No-op sink this pass. |

**Why optional, against the first instinct that it should be required.** The shipped web screen is
optional and says so — *"Leave it blank and we'll use the name already on your account."* And the
live distribution decides it: across 89 profiles, **`display_name` is 89/89** (backfilled at signup
from metadata or the email local-part) while **`nickname` is 1/89**. Almost every real user already
has a usable name before we ask. A required field would be a wall in front of a question we mostly
know the answer to.

**The name resolves in three rungs, in this order:**

> ### `nickname` → `display_name` → nameless copy

**In the `OnboardingPreview` target there is no session, so it always falls to rung 3.** That is
correct behaviour and not a bug — say so in the file, because it will look like one.

### 3.2 Personalisation — a budget, not a garnish

A name on every screen reads as a mail-merge and does the opposite of what was asked for.

**FIVE screens carry a name. Eight do not.** Not screen 1 (it is where the name is given), not
`benefit2`, not `benefit3`, not `reminders`, not `inventory`, not the end states.

| # | Screen | Position |
|---|---|---|
| 1 | `pathway` | end of title |
| 2 | `experience` | mid-sentence, body |
| 3 | `setup` | late-sentence, body |
| 4 | `firstDose` | opening, body |
| 5 | `paywall` | mid-sentence, body |

**Never twice in the same position, and four distinct positions rather than two** — a strict
alternation is itself a pattern a reader can feel.

**THE NAMELESS FORM OF EVERY PERSONALISED STRING IS THE EXISTING OWNER COPY, BYTE-FOR-BYTE.** This is
the whole design:

- It satisfies "must read correctly with the name absent" **by construction** — the no-name path
  falls back to a sentence already written and already approved, not to a degraded version of a new
  one. **"Nice work, ." is not reachable, because the nameless string never had a slot in it.**
- The only new writing is the **six** named variants, each an **insertion into** a sentence rather
  than a rewrite of one.
- Both forms are declared as a pair in `OnboardingCopy`. **Nothing is computed at a call site**, and
  exactly one resolver decides — trimmed-empty is *absent*, not empty.

**`benefit1` was the original ask and was moved to `experience` deliberately.** `benefit1`'s copy is
entirely segment-varied, so personalising it costs **four** strings, each a rewrite of an owner
sentence on the screen where the copy *is* the product. Whereas *"So we talk to you like a mate —
not a manual"* is already a sentence **about how we address the user**, so putting the name in it is
the line doing what it says.

**The paywall HEADLINE is deliberately not personalised** — segment-varied, four more strings, and it
is the one line on that screen doing commercial work.

### 3.3 Motion and visual (owner-directed 2026-08-03)

Owner: *"The onboarding needs to look visually better and the text should feel animated and personal,
not another form or buttons to pick."* **This is the actual brief and it is where the work is.**

**Text arrives, it does not appear.** Per-line reveal: opacity 0→1 with a small upward offset,
staggered **~60ms** per line, **~350ms** ease-out, **headline → body → action**.

- **One pass on entry only. Never re-animate on a back-navigation.**
- **Never animate the progress bar's fill from zero on every screen.** It is endowed progress; a bar
  that refills each time is a bar that measures nothing.
- `0.35s` is on the sanctioned scale — `ANIMATIONS.md` §8, "Transitions / reveals". Not invented.

**The choice screens stop being button stacks.** `pathway` and `experience` become full-width cards
with room to breathe — label, one supporting line where the copy gives one, generous vertical
padding, **selected state by FILL, not by a checkmark.** They should read as *choosing a lane*, not
as a form control.

**Every spacing value comes from `Theme.Spacing`** — `DESIGN-PARITY` §11, the `4 · 8 · 16 · 24 · 32`
grid. **If a value the design wants is not on the scale, that is a finding, not a licence to inline
a number.**

**Reduce Motion — not optional. A motion-heavy onboarding is exactly the surface that makes people
ill.** Everything lands in its final state: no offset, no stagger, **and no fade**.

> **Why the fade goes too, when `ANIMATIONS.md` §9.1 says to KEEP opacity under Reduce Motion.** §9.1
> keeps opacity *because it carries state* — a control that changes colour is telling you something.
> Here the opacity carries nothing; it is pure entrance decoration. So removing it is the rule
> **applied**, not broken. Recorded because a later reader comparing the two documents will otherwise
> file it as a conflict.

**The progress bar stays.** Make it quieter, not absent.

**Verification: motion is JUDGED, not asserted.** One no-login session, six paths, judgment pass
first — *would I ship this frame?* — then the same bar measurement to prove nothing drifted.
**Two frames per screen, early and settled, and confirm the settled frame is the composed one.**

---

## 4. Copy — verbatim. Do not paraphrase, do not "improve".

Copy lives in **one data file** (`OnboardingCopy.swift` or a bundled JSON), keyed by screen and
segment. **No string literals in views.** A copy change must be one edit in one place — this is the
same shared-control rule the calculators are under.

### Shared

**1 · welcome** — ⚠️ **REPLACED 2026-08-03. See §3.1.**

The congratulation line is **the owner's to write and is not written yet.** Build against a visibly
fake placeholder. Prompt — **from his instruction** — `What should we address you by?`; field
placeholder — **his shipped copy** — `What should InjectBuddy call you?`; label `Nickname` ·
`optional`; `maxLength 60`; optional, with a Skip.

> **The old screen-1 copy, retired. It is NOT the new screen and must not be reinstated as one** —
> it is recorded because two congratulation beats in a row was the reason for the replacement, and a
> later reader finding it deleted outright would not know that.
>
> `You made it. 🎉`
> Most people wing it and hope for the best. You showed up because you want to **know**. That's the
> hard part — and look, you're already a quarter of the way there.
> CTA: `Keep going`

### The six personalised pairs

**Nameless = today's copy, unchanged. Named = the only new writing.** ⚠️ **The named forms below are
PROPOSED and are not yet owner-approved.**

| Screen | Form | String |
|---|---|---|
| `pathway` | nameless | `What brings you here?` |
| | **named** | `What brings you here, {name}?` |
| `experience` | nameless | `So we talk to you like a mate — not a manual.` |
| | **named** | `So we talk to you like a mate, {name} — not a manual.` |
| `setup` | nameless | `Two minutes here, and every chart, reminder and forecast is built around **you** — not some average person who doesn't exist.` |
| | **named** | `Two minutes here, and every chart, reminder and forecast is built around **you**, {name} — not some average person who doesn't exist.` |
| `firstDose` (default) | nameless | `One tap. That's the whole habit. Everything after this is momentum.` |
| | **named** | `{name}, one tap. That's the whole habit. Everything after this is momentum.` |
| `firstDose` (`.adv`) | nameless | `You know the drill. One tap, and it's on the record.` |
| | **named** | `You know the drill, {name}. One tap, and it's on the record.` |
| `paywall` | nameless | `Look what you just did{opener}. Here's the honest deal:` |
| | **named** | `Look what you just did, {name}{opener}. Here's the honest deal:` |

The paywall's two rule-6 openers are **reused unmodified** — the variant logic is untouched.

**2 · pathway** — `What brings you here?`
> Everyone's on their own journey. Tell us yours, and everything from here is built around it.

Options: `TRT / HRT` · `Peptides / GLP-1` · `Performance / AAS` · `Other / a mix`

**3 · experience** — `Where are you on the road?`
> So we talk to you like a mate — not a manual.

Options: `Just starting out` · `Found my feet` · `Been doing this for years`

**5 · setup** — `Make it yours`
> Required · why we ask: powers your charts + reminders
>
> Two minutes here, and every chart, reminder and forecast is built around **you** — not some average
> person who doesn't exist.

Fields: units preference (mg · mL · IU · units) · first compound · dose · frequency.
CTA: `This is my protocol`

**6 · reminders** — `Set it and forget it.`
> Optional
>
> Receive a quiet nudge exactly when it's time to log, so staying on schedule takes zero mental
> space. *(Triggers the OS notification permission ask.)*

Field: remind me at [time]. CTAs: `Yes — watch my back` · `Skip for now`
**The OS permission ask happens here and nowhere earlier** — never on app open.

**7 · inventory** — `Never run dry mid-protocol`
> Optional
>
> Nothing worse than reaching for a vial that isn't there. Tell us what's on hand and we'll flag it
> before you run out — not after.

Fields: vials on hand · size. CTAs: `Track my stock` · `Skip for now`

**8 · firstDose** — `This is where it gets real`
CTAs: `Log my first dose ✓` · `I'll do it later`

**9 · paywall** — headline by segment (below). Body:
> Look what you just did[opener variant]. Here's the honest deal:

Founder note, with a photo of Pou:
> "I'm one person building InjectBuddy because I needed it myself. No investors, no data-selling.
> Going paid is what keeps it alive — and keeps it yours." — Pou

Two-row split:
> **THIS APP:** the full tracker — logging · dashboard · reminders · your saved doses loaded straight
> into the plotter & calcs
>
> **ALWAYS FREE:** all calculators + cycle plotter in our free InjectBuddy Calculator app · your data
> is always yours — export or delete anytime

Timeline: `TODAY no charge` → `DAY 5 we remind you` → `DAY 7 billed · cancel anytime`
CTAs: `Start my 7-day free trial · $X/mo` · `Skip the trial — 10% off first 3 months` · ghost `Not now`

**10a · dashboard** — `Welcome home`
Trial: *"Trial day 1 of 7. Everything unlocked. This is yours now."*
Paid: *"Everything unlocked. 10% off applied for your first 3 months — thanks for backing this early."*
Shows: active levels chart (alive with their first dose) · next dose card · cycle plotter pre-loaded.

**10b · locked** — `Your setup is saved`
> Your protocol and first dose are safely stored — they'll be right here when you're ready. In the
> meantime, our calculators are free forever in the **InjectBuddy Calculator** app.

CTA: `See plans again`

### Benefits and paywall headline, by segment

**TRT / HRT** — paywall headline: *You just protected your protocol.*
1. **Keep your edge. Every single day.** — TRT is all about consistency. Simple tracking keeps your
   levels flat and your energy right where you want it — no dips, no guessing.
2. **Own your protocol.** — Walk into your doctor review with your full history in hand. Clear data
   makes it easy to fine-tune your dose and get optimal results.
3. **Proof of progress.** — Your levels chart gives you absolute clarity on your consistency and how
   well your protocol is working over time.

**Peptides / GLP-1** — paywall headline: *You just protected your investment.*
1. **We do the math. You get the results.** — Reconstitution doesn't need to be complicated. Plug in
   your vial details and InjectBuddy gives you the exact syringe line to hit every time.
2. **Peptides aren't cheap.** — They might break the bank, but InjectBuddy won't let you break your
   schedule. Stay consistent and protect every bit of progress you paid for.
3. **Consistency is the whole game.** — Results come from weeks strung together seamlessly.
   Effortless logging keeps the streak alive.

**Performance / AAS** — paywall headline: *You just protected your cycle.*
1. **Unstable levels waste cycles** — A missed pin mid-cycle sends your levels bouncing — and
   bouncing levels is how you collect sides without the gains. Logging keeps the curve where you
   planned it.
2. **You've spent real money on this cycle** — Running it on memory and guesswork is how expensive
   compounds get wasted. Plot it, pin it on schedule, get everything you paid for.
3. **Yours. Private. Untouchable.** — No selling, no sharing, no judgement. Export it or torch it —
   your call, always.

**Other / a mix** — paywall headline: *You just protected your results.*
1. **Built for complex stacks.** — Whether you're combining HRT with peptides or running custom
   schedules, InjectBuddy adapts to your exact setup.
2. **Know exactly what's in your system** — Doubling up or running low without realising — both undo
   weeks of work. Live levels from your real doses end the guesswork.
3. **Protect your sites** — Scar tissue from bad rotation is permanent. The tracker rotates for you
   before it becomes a problem.

---

## 5. Images

Every benefit screen and several others carry an illustration. **None of them exist.**

**Shape — confirmed against the wireframe 2026-08-03, read by the Windows side.** The placeholder is
**full content width with a 90pt minimum height, and it may grow** — a wide banner, roughly 4:1 at
the wireframe's own dimensions. **Provisional until the art is commissioned**, but it is the one
dimension the source actually gives, and it beats a guess.

**Which illustration goes on which screen — confirmed against the wireframe 2026-08-03, read by the
Windows side. This was previously reconstructed by inference; it is now stated, and an art brief can
be built on it.**

| Screen | Illustration |
|---|---|
| `welcome` | logo / small celebration |
| **TRT** benefits | flat levels chart · chart + share icon · levels-over-time chart |
| **GLP-1** benefits | reconstitution calc · $ + trend line · streak calendar |
| **AAS** benefits | multi-compound curve · cycle plotter · lock |
| **Other** benefits | multi-protocol view · half-life curve · body map |
| `firstDose` | big log button / syringe icon |
| `paywall` | photo of Pou |

Twelve benefits plus three. **Fifteen, and that is the whole list.**

> **The `dashboard` end state's three placeholders are NOT part of the fifteen and must never reach
> the art list.** *Active levels chart*, *next dose card* and *cycle plotter pre-loaded* are **mocks
> of real UI**, not illustrations to commission.

**Do not let placeholder art block the flow landing.** Do not let a placeholder ship to the store.

---

## 6. What this pass delivers, and what it does not

**Delivers:** the `OnboardingPreview` target, `Sources/OnboardingKit/`, all thirteen screen types,
both branch dimensions, the copy file, the progress bar, working back, placeholder art, and a
build that runs to `dashboard` and to `locked` without a login — **and loops from both back to
screen 1 with all state cleared**, so the six paths are walkable in one session without relaunching.

**Auth is assumed complete, not absent.** Screen 1's premise is a user who has just signed up. The
target contains no auth because it does not need any, not because the flow happens before sign-up.

**Explicitly not in this pass:** StoreKit or any real purchase, the notification permission actually
being requested, writing anything to Supabase, mounting the flow in the real app, the win-back email
sequence, the separate free calculator app, and the `$X/mo` price — leave the token literally as
`$X/mo` until the owner sets it.

> **If you are here because you are about to change "writing anything to Supabase" from out-of-scope
> to in-scope — stop and read `docs/WELCOME-AND-ONBOARDING.md` §3 and `docs/DATA-CONTRACT.md`
> first.** The write contract is not in this file. A skipped step writes the default and never a
> null; `onboarding_completed_at` is set only on completion; nothing is rounded on the way in. RLS
> refuses a bad write **silently**, so a sink built from this file alone will look like it works.

---

## 7. Verification — one build, one sweep, no login

> **KNOWN AND FILED, 2026-08-03 — `setup` fails D5's second half at AX5.** The CTA is reachable;
> **the four inputs it commits are not.** This spec named `setup` as the risk and it is the risk.
> It does **not** block: onboarding is off the launch path and Dynamic Type is the owner's deferred
> axis. **But it is the FIRST thing to fix when that axis reopens** — recorded here rather than in a
> list so whoever reopens Dynamic Type finds it standing next to the screen it is about.
>
> **Sample, stated because "onboarding passes" would otherwise read as thirteen screens at both
> sizes:** only `setup` and `paywall` were measured at AX5. The other eleven were judged at default
> size only.


This is the first thing in this project that can be swept without signing in. Use that.

Under the batch-first mode: code all of it, build once, then walk **six paths** in one session —
`.trt/.adv` (the fast lane, one benefit screen), `.trt/.first` (all three plus the reassurance line),
`.glp/.some`, `.aas/.some`, `.other/.some`, and one path that skips reminders **and** inventory so
the paywall opener variant and the dashboard's "set a reminder?" card both render.

Judgment pass before measuring (P2). The bar percentages are the one thing worth asserting rather
than eyeballing, because they are exact and they are easy to get wrong in a refactor.

D5 applies to every screen in this flow: **the primary action must be reachable without scrolling at
every text size, and so must the input it commits.** The setup screen is the risk — four fields plus
a CTA plus a variant line.
