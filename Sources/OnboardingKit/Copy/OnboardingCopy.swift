import Foundation

// ─── THE COPY FILE ───────────────────────────────────────────────────────────
//
// SPEC §4: "Copy — verbatim. Do not paraphrase, do not 'improve'."
//
// **THIS IS THE ONLY PLACE ONBOARDING COPY LIVES. NO STRING LITERALS IN VIEWS.**
// A copy change must be one edit in one place — the same shared-control rule the
// calculators are under. If a screen needs a word, it asks this file for it; if
// this file does not have it, the word gets added HERE, not inlined there.
//
// Every string below is transcribed byte-for-byte from docs/SPEC-ONBOARDING.md
// §3–§4, including the em dashes (—), middots (·), the fullwidth plus (＋) in
// "＋ Add another compound", the checkmark in "Log my first dose ✓" and the 🎉.
// Do not normalise them to ASCII.
//
// Markdown emphasis (**bold**, *italic*) is PRESERVED in the stored strings
// because it is the owner's writing. Render it with `OnboardingCopy.attributed(_:)`
// rather than stripping it or hand-splitting the sentence.
//
// Anything below marked NOT-VERBATIM is a label this file needed and the spec
// does not supply. Those are the only strings here an owner has not written, and
// each says so.

enum OnboardingCopy {

    // MARK: - Rendering helper
    //
    // The stored copy carries markdown emphasis. This turns it into an
    // AttributedString so a view can render it without owning any of the text.

    static func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }

    // MARK: - The price token
    //
    // SPEC §6: "the `$X/mo` price — leave the token literally as `$X/mo` until
    // the owner sets it."
    //
    // ***DO NOT INVENT A NUMBER.*** The owner sets this. It is a separate
    // constant, not inlined into the CTA, so that setting it is one edit.

    static let priceToken = "$X/mo"

    // MARK: - 1 · welcome

    enum Welcome {
        static let title = "You made it. 🎉"
        static let body = "Most people wing it and hope for the best. You showed up because you want to **know**. That's the hard part — and look, you're already a quarter of the way there."
        static let cta = "Keep going"
    }

    // MARK: - 2 · pathway

    enum Pathway {
        static let title = "What brings you here?"
        static let body = "Everyone's on their own journey. Tell us yours, and everything from here is built around it."

        /// The four options, enumerated against the segment they set. Screens
        /// render `OnboardingSegment.allCases` through this — there is no
        /// parallel array to fall out of step with the enum.
        static func option(_ segment: OnboardingSegment) -> String {
            switch segment {
            case .trt:   return "TRT / HRT"
            case .glp:   return "Peptides / GLP-1"
            case .aas:   return "Performance / AAS"
            case .other: return "Other / a mix"
            }
        }
    }

    // MARK: - 3 · experience

    enum Experience {
        static let title = "Where are you on the road?"
        static let body = "So we talk to you like a mate — not a manual."

        static func option(_ exp: OnboardingExperience) -> String {
            switch exp {
            case .first: return "Just starting out"
            case .some:  return "Found my feet"
            case .adv:   return "Been doing this for years"
            }
        }
    }

    // MARK: - 4a/4b/4c · benefits (copy by segment — branch dimension 1)

    struct Benefit: Equatable {
        let title: String
        let body: String
    }

    enum Benefits {
        /// SPEC §3 rule 1: `.adv` sees ONE benefit screen and its CTA reads
        /// "Set me up", not "Next".
        static let ctaNext = "Next"
        static let ctaSetMeUp = "Set me up"
        /// SPEC §3 rule 2: the ghost skip on a benefit screen jumps to `setup`.
        /// It is NOT an `OnboardingSkippableStep`.
        static let ctaSkip = "Skip"

        /// Always three, in spec order. `.adv` is shown only the first — that is
        /// the ROUTE's business (`OnboardingRoute`), not this file's.
        static func all(for segment: OnboardingSegment) -> [Benefit] {
            switch segment {
            case .trt:   return trt
            case .glp:   return glp
            case .aas:   return aas
            case .other: return other
            }
        }

        private static let trt = [
            Benefit(
                title: "Keep your edge. Every single day.",
                body: "TRT is all about consistency. Simple tracking keeps your levels flat and your energy right where you want it — no dips, no guessing."),
            Benefit(
                title: "Own your protocol.",
                body: "Walk into your doctor review with your full history in hand. Clear data makes it easy to fine-tune your dose and get optimal results."),
            Benefit(
                title: "Proof of progress.",
                body: "Your levels chart gives you absolute clarity on your consistency and how well your protocol is working over time."),
        ]

        private static let glp = [
            Benefit(
                title: "We do the math. You get the results.",
                body: "Reconstitution doesn't need to be complicated. Plug in your vial details and InjectBuddy gives you the exact syringe line to hit every time."),
            Benefit(
                title: "Peptides aren't cheap.",
                body: "They might break the bank, but InjectBuddy won't let you break your schedule. Stay consistent and protect every bit of progress you paid for."),
            Benefit(
                title: "Consistency is the whole game.",
                body: "Results come from weeks strung together seamlessly. Effortless logging keeps the streak alive."),
        ]

        private static let aas = [
            // No trailing full stop on this title in the spec. Deliberate — left as written.
            Benefit(
                title: "Unstable levels waste cycles",
                body: "A missed pin mid-cycle sends your levels bouncing — and bouncing levels is how you collect sides without the gains. Logging keeps the curve where you planned it."),
            Benefit(
                title: "You've spent real money on this cycle",
                body: "Running it on memory and guesswork is how expensive compounds get wasted. Plot it, pin it on schedule, get everything you paid for."),
            Benefit(
                title: "Yours. Private. Untouchable.",
                body: "No selling, no sharing, no judgement. Export it or torch it — your call, always."),
        ]

        private static let other = [
            Benefit(
                title: "Built for complex stacks.",
                body: "Whether you're combining HRT with peptides or running custom schedules, InjectBuddy adapts to your exact setup."),
            Benefit(
                title: "Know exactly what's in your system",
                body: "Doubling up or running low without realising — both undo weeks of work. Live levels from your real doses end the guesswork."),
            Benefit(
                title: "Protect your sites",
                body: "Scar tissue from bad rotation is permanent. The tracker rotates for you before it becomes a problem."),
        ]
    }

    // MARK: - 5 · setup

    enum Setup {
        static let title = "Make it yours"
        static let note = "Required · why we ask: powers your charts + reminders"
        static let body = "Two minutes here, and every chart, reminder and forecast is built around **you** — not some average person who doesn't exist."
        static let cta = "This is my protocol"

        /// SPEC §3 rule 3 — shown only when `exp == .first`.
        static let startWithWhatYouKnow = "Not sure of your exact protocol? Start with what you know — you can change everything later."

        /// SPEC §3 rule 4 — shown up front only when `exp == .adv`.
        /// Fullwidth plus (U+FF0B), exactly as the spec writes it.
        static let addAnotherCompound = "＋ Add another compound"

        /// NOT-VERBATIM. SPEC §4 gives the fields as a prose list — "units
        /// preference (mg · mL · IU · units) · first compound · dose ·
        /// frequency" — not as on-screen labels. These four are this file's
        /// wording of that list and want an owner's eye before ship.
        static let unitsLabel = "Units preference"
        static let compoundLabel = "First compound"
        static let doseLabel = "Dose"
        static let frequencyLabel = "Frequency"

        /// Verbatim tokens from the spec's units list.
        static func unit(_ unit: OnboardingUnitPreference) -> String {
            switch unit {
            case .mg:    return "mg"
            case .mL:    return "mL"
            case .iu:    return "IU"
            case .units: return "units"
            }
        }
    }

    // MARK: - 6 · reminders

    enum Reminders {
        static let title = "Set it and forget it."
        static let note = "Optional"
        static let body = "Receive a quiet nudge exactly when it's time to log, so staying on schedule takes zero mental space."
        // The spec's body ends with an italic parenthetical — "*(Triggers the OS
        // notification permission ask.)*". That is an instruction to the
        // implementer, not a line shown to a user, and SPEC §6 puts the actual
        // permission request OUT of this pass. It is therefore recorded here and
        // not in `body`. If the owner meant it as user-facing copy, move it in —
        // this is the one place a judgement call was made about §4's text.
        //
        // SPEC §4: "The OS permission ask happens here and nowhere earlier —
        // never on app open."

        /// NOT-VERBATIM as a standalone label. SPEC §4 writes the field as
        /// "remind me at [time]".
        static let fieldLabel = "remind me at"

        static let ctaAccept = "Yes — watch my back"
        static let ctaSkip = "Skip for now"
    }

    // MARK: - 7 · inventory

    enum Inventory {
        static let title = "Never run dry mid-protocol"
        static let note = "Optional"
        static let body = "Nothing worse than reaching for a vial that isn't there. Tell us what's on hand and we'll flag it before you run out — not after."

        /// NOT-VERBATIM as labels. SPEC §4: "Fields: vials on hand · size."
        static let vialCountLabel = "Vials on hand"
        static let vialSizeLabel = "Size"

        static let ctaAccept = "Track my stock"
        static let ctaSkip = "Skip for now"
    }

    // MARK: - 8 · firstDose

    enum FirstDose {
        static let title = "This is where it gets real"
        static let ctaAccept = "Log my first dose ✓"
        static let ctaSkip = "I'll do it later"

        /// SPEC §3 rule 5. Which one is chosen is `OnboardingBranch`'s business.
        static let bodyAdvanced = "You know the drill. One tap, and it's on the record."
        static let bodyDefault = "One tap. That's the whole habit. Everything after this is momentum."
    }

    // MARK: - 9 · paywall

    struct TimelineEntry: Equatable {
        let label: String
        let detail: String
    }

    enum Paywall {
        /// Headline by segment — branch dimension 1.
        static func headline(_ segment: OnboardingSegment) -> String {
            switch segment {
            case .trt:   return "You just protected your protocol."
            case .glp:   return "You just protected your investment."
            case .aas:   return "You just protected your cycle."
            case .other: return "You just protected your results."
            }
        }

        /// SPEC §4 body: "Look what you just did[opener variant]. Here's the
        /// honest deal:" — the two variants are SPEC §3 rule 6. Composed here so
        /// the sentence exists in one piece and a view never concatenates copy.
        static func body(opener: String) -> String {
            "Look what you just did" + opener + ". Here's the honest deal:"
        }

        /// SPEC §3 rule 6 — fewer than two skips.
        static let openerFewSkips = " — protocol set, reminders on"
        /// SPEC §3 rule 6 — otherwise.
        static let openerManySkips = " — your protocol, set up your way"

        static let founderQuote = "\"I'm one person building InjectBuddy because I needed it myself. No investors, no data-selling. Going paid is what keeps it alive — and keeps it yours.\""
        static let founderAttribution = "— Pou"
        // The founder note carries a photo of Pou — `OnboardingIllustration.photoOfPou`.

        static let thisAppLabel = "THIS APP:"
        static let thisAppBody = "the full tracker — logging · dashboard · reminders · your saved doses loaded straight into the plotter & calcs"
        static let alwaysFreeLabel = "ALWAYS FREE:"
        static let alwaysFreeBody = "all calculators + cycle plotter in our free InjectBuddy Calculator app · your data is always yours — export or delete anytime"

        /// SPEC §4: `TODAY no charge` → `DAY 5 we remind you` → `DAY 7 billed ·
        /// cancel anytime`. The arrows are the separator the screens pass draws,
        /// not part of the text.
        static let timeline = [
            TimelineEntry(label: "TODAY", detail: "no charge"),
            TimelineEntry(label: "DAY 5", detail: "we remind you"),
            TimelineEntry(label: "DAY 7", detail: "billed · cancel anytime"),
        ]

        /// `Start my 7-day free trial · $X/mo` — composed from `priceToken` so
        /// the owner's price lands in exactly one place. Sets `plan = .trial`.
        static var ctaTrial: String { "Start my 7-day free trial · " + priceToken }
        /// Sets `plan = .paid`.
        static let ctaPaid = "Skip the trial — 10% off first 3 months"
        /// Ghost. Sets `plan = .declined`.
        static let ctaDecline = "Not now"
    }

    // MARK: - 10a · dashboard (end state, accepted)

    enum Dashboard {
        static let title = "Welcome home"
        static let trialMessage = "Trial day 1 of 7. Everything unlocked. This is yours now."
        static let paidMessage = "Everything unlocked. 10% off applied for your first 3 months — thanks for backing this early."

        /// SPEC §3 rule 7 — by whether `reminders` was skipped.
        static let nextDoseReminderSet = "reminder set ✓"
        static let nextDoseReminderPrompt = "set a reminder?"

        // SPEC §4 also specifies what this screen SHOWS — "active levels chart
        // (alive with their first dose) · next dose card · cycle plotter
        // pre-loaded". That is composition, not copy, and belongs to the screens
        // pass — which is where the three labels below come from.
        //
        // NOT-VERBATIM as labels. They are §4's own words for the three things
        // this screen shows, capitalised as headings.
        //
        // ***THESE THREE ARE MOCKS OF REAL UI AND ARE NOT ILLUSTRATIONS.***
        // SPEC §5: they "are NOT part of the fifteen and must never reach the art
        // list." They are drawn with `OnboardingUIMock`, never with
        // `OnboardingIllustrationPlaceholder`, and that difference is deliberate.
        static let mockActiveLevelsChart = "Active levels chart"
        static let mockActiveLevelsDetail = "alive with their first dose"
        static let mockNextDoseCard = "Next dose"
        static let mockCyclePlotter = "Cycle plotter"
        static let mockCyclePlotterDetail = "pre-loaded"
    }

    // MARK: - 10b · locked (end state, declined)

    enum Locked {
        static let title = "Your setup is saved"
        static let body = "Your protocol and first dose are safely stored — they'll be right here when you're ready. In the meantime, our calculators are free forever in the **InjectBuddy Calculator** app."
        /// Returns to the paywall. It does NOT loop the flow — the loop is
        /// separate. SPEC §1: "Do not add a 'you have finished' interstitial."
        static let cta = "See plans again"
    }

    // MARK: - Debug affordances
    //
    // ***NONE OF THIS IS OWNER COPY.*** These strings exist because the preview
    // target is a testing surface (SPEC §1: "the wireframe also has a restart;
    // the preview target should keep one, as a debug affordance only"). They
    // must not appear in the real app and they are not subject to §4's verbatim
    // rule.

    enum Debug {
        static let restart = "Restart"
        static let finishAndLoop = "Finish → back to screen 1"
        /// Marks a mock of real UI on the `dashboard` end state. See the note on
        /// `Dashboard.mock…` — a mock is NOT an illustration and must never join
        /// the art list.
        static let uiMock = "MOCK OF REAL UI — NOT ART"
    }

    // MARK: - Navigation
    //
    // NOT-VERBATIM. SPEC §3 requires the affordance ("Back must work from every
    // screen") without giving it a word. This is the word.

    enum Navigation {
        static let back = "Back"
    }

    // MARK: - Accessibility
    //
    // ***NOT-VERBATIM, AND STILL COPY.*** A VoiceOver label is text a user
    // receives, so it lives here under the same rule as everything else — no
    // string literals in views, including the ones only some users hear.

    enum Accessibility {
        static let progressLabel = "Setup progress"
        static func progressValue(_ percent: Int) -> String { "\(percent)%" }
        /// The paywall's founder note carries a photo of Pou — the placeholder
        /// announces itself as one.
        static let founderNote = "Founder note"
        /// The timeline's separator is a drawn glyph, not copy; it is hidden
        /// from the accessibility tree rather than read as an arrow (D3).
        static let timeline = "Trial timeline"
    }
}
