# T-47 · Declarations nothing reads — the sweep, and what it found

Run on **2026-08-04** against `feature/tabview-shell` by `t47-deadcode`.

> This file records the FIRST run and the reasoning behind the exclusion list.
> It is not the source of truth for the current population — the script is.
> Re-run it; do not read this and assume.

```
scripts/unread-decls.py                  # the report
scripts/unread-decls.py --show-excluded  # every declaration a rule silenced, and why
scripts/unread-decls.py --exclusions     # just the exclusion table
scripts/unread-decls.py --tsv            # one finding per line, for diffing two runs
```

It takes about two seconds, needs no toolchain, and **never builds anything** — no
`xcodebuild`, no `xcodegen`, no `swift build`. That is deliberate: the rig is one
resource, and a check that has to queue behind the device lock is a check nobody runs.

---

## 1 · Counts

| | |
|---|---|
| Swift files swept (`Sources/`) | 66 |
| Declarations found (`var` / `let` / `func` / `case` / type) | 1945 |
| **Zero read sites, before exclusions** | **52** |
| Silenced by an exclusion rule | 23 |
| **UNREAD — survivors** | **29** |
| Read only by `Tests/` | 12 |
| Underdetermined name groups | 2 |

Reads are counted across `Sources/` **and** `Tests/`, but declarations are only
swept in `Sources/`. Comments and string literals are stripped first — `canInject`
appears eight times in prose in this tree explaining why it was unread, and a raw
grep would have counted the explanation of the bug as evidence the bug was fixed.

**Honest precision: 25 of the 29 survivors are genuine, ~86%.** The four that are
not are named in §4. That is good enough to act on and not good enough to automate:
the script exits 0 whatever it finds, on purpose.

---

## 2 · The exclusion list

Every entry says **who reads the declaration instead of your code**. If you add one
and cannot name the reader, it is not an exclusion — it is a finding you did not want.

### By name (any type) — framework and protocol requirements

| Name | Who reads it |
|---|---|
| `body` | SwiftUI View / App / Scene / ViewModifier requirement. SwiftUI calls it through the protocol. |
| `previews` | `PreviewProvider` requirement. Xcode's canvas calls it; it has no runtime caller by design. |
| `id` | `Identifiable` requirement. `ForEach` and `List` read it through the protocol witness, never by name. |
| `rawValue` | `RawRepresentable` requirement, usually synthesised. |
| `allCases` | `CaseIterable` requirement, usually synthesised. |
| `hashValue`, `hash` | `Hashable` requirements. The hasher calls them. |
| `encode` | `Encodable` requirement (`encode(to:)`). `JSONEncoder` calls it. |
| `description`, `debugDescription` | `CustomStringConvertible` / `CustomDebugStringConvertible`; string interpolation and the debugger. |
| `errorDescription` | `LocalizedError` requirement, read by error presentation. |
| `wrappedValue`, `projectedValue` | Property-wrapper requirements. The compiler rewrites accesses into them. |
| `defaultValue` | `EnvironmentKey` requirement, read when no value is set. |
| `path`, `animatableData` | `Shape` / `Animatable` requirements, driven by the render and animation systems. |
| `makeUIView`, `updateUIView`, `makeCoordinator`, `makeUIViewController`, `updateUIViewController` | `UIViewRepresentable` / `UIViewControllerRepresentable` requirements. |
| `makeBody` | `ButtonStyle` / `LabelStyle` / `ProgressViewStyle` requirement. |
| `sizeThatFits`, `placeSubviews` | `Layout` requirements. |
| `main` | `@main` entry point. The runtime calls it. |
| `CodingKeys` | Codable's synthesised key type. The synthesised coder is its only reader. |

### By rule

| Rule | Reason |
|---|---|
| `satisfies-protocol` | The member satisfies a requirement of a protocol declared in this repo. Calls dispatch through the existential/generic, so the conformer's own copy has no direct call site. |
| `coding-keys-case` | A case of a `CodingKeys` enum. The synthesised coder is its only reader, and the compiler already catches the one thing that can go wrong — a key with no matching property does not compile. |
| `entry-point` | `@main`. The runtime instantiates it; there is no call site to find, ever. |
| `codable-stored-prop` | Stored property of a `Codable`/`Encodable`/`Decodable` type. The synthesised coder reads it reflectively to build the PostgREST body. **Widest rule here** — it also hides "decoded and never displayed", which is a real category. It currently silences nothing; check `--show-excluded` before trusting silence about a model type. |
| `init-or-operator` | `init` / `deinit` / `subscript` / operators are resolved by shape rather than by name, so a name search cannot answer the question at all. |
| `declared-in-preview` | Declared inside a `#Preview` / `_Previews` block. Preview scaffolding has no shipping caller by construction. |
| `underscore-prefixed` | Leading underscore is both the deliberate-unused marker and property-wrapper storage. |

### Two exclusions that were written and then DELETED

Worth recording, because the mistake is the interesting part.

1. **`protocol-declaration`** — "a requirement on a protocol is a contract, its call
   sites are on the conformers". Paired with `satisfies-protocol` ("calls go through
   the protocol") it formed a **closed loop**: between them the two rules silenced all
   six declarations of `BackendClient.deleteDosage` and `.profile`, which no shipping
   code calls at all. An exclusion whose justification points at another exclusion is
   not a justification. The protocol requirement is now the one reportable site.

2. **Equatable / Hashable stored properties.** Tempting, and wrong. `SteroidCompound`
   is `Hashable`, so the synthesised `==` reads `defaultTab` — the rule would have
   silenced the single finding this whole task was filed for. The sweep's question is
   "does any hand-written code consult this value", not "is this byte ever touched".

---

## 3 · Findings — the 29 survivors

Verdict key: **REAL** = nothing hand-written reads it · **WEAK** = defensible reason
it might be reached · **FALSE** = the tool is wrong.

### User-visible, same shape as the ones already tracked

| file:line | declaration | verdict |
|---|---|---|
| `Sources/InjectBuddy/Core/Calculator/SteroidCatalog.swift:33` | `SteroidCompound.canOral` | **REAL.** The sibling of `canInject` (T-44), still unread. Winstrol is the only compound with `canInject: true, canOral: true`, and `CalculatorCatalog.swift:359` records that the web shows a form toggle exactly when `(canInject && canOral)`. iOS never reads `canOral`, so that toggle does not exist. |
| `Sources/InjectBuddy/Core/Calculator/SteroidCatalog.swift:39` | `SteroidCompound.defaultTab` | **REAL.** Already known. Twelve writes, zero reads; tablet strength stays 10 whatever is picked, and Anadrol ships 50 mg. |
| `Sources/InjectBuddy/Core/Calculator/CalculatorCatalog.swift:109` | `PlotterCompound.defaultDose` | **REAL, and new.** Twenty-eight compounds each carry a per-compound default dose. `.defaultDose` is read **nowhere**. Identical shape to `defaultTab`, on the cycle plotter instead of the steroid calculator. |
| `Sources/InjectBuddy/Core/Settings/SettingsStore.swift:6` | `UnitSystem.imperial` | **REAL, and new.** `SettingsScreen.swift:92` shows a live `Picker("Units", selection: $settings.units)` and the choice persists to `UserDefaults`. Nothing anywhere branches on `.imperial` except the label string that spells it. A setting the user can change that changes nothing. |

### Dead code, no user consequence

| file:line | declaration | verdict |
|---|---|---|
| `Sources/InjectBuddy/App/RootView.swift:100` | `type LaunchView` | **REAL.** A whole `View` struct, one occurrence in the tree — its own declaration. |
| `Sources/InjectBuddy/Core/Calculator/CalculatorCatalog.swift:94` | `CalcConst.doseOptions(_:)` | **REAL.** |
| `Sources/InjectBuddy/Core/Calculator/CalculatorCatalog.swift:222` | `CalculatorCatalog.barrelField(for:)` | **REAL, and it falsifies a comment.** `CalculatorCatalog.swift:289` says the EOD barrel default is "now carried by `barrelField`'s default rather than hardcoded here". `barrelField` is never called; the eleven real sites build `.segmented("syringeMl", …)` inline and call `defaultBarrel(for:)` directly. `barrelField` also builds a `.picker`, not a `.segmented` — a divergent control nobody would ever see. **This is the exact intersection with win's doc-claim checker: a dead declaration and a stale sentence about it, in one file.** |
| `Sources/InjectBuddy/Core/Calculator/CalculatorEngine.swift:19` | `CalculatorEngine.mcgToMg(_:)` | **REAL.** |
| `Sources/InjectBuddy/Core/Calculator/CalculatorEngine.swift:21` | `CalculatorEngine.mgToMcg(_:)` | **REAL.** |
| `Sources/InjectBuddy/Core/Calculator/CalculatorEngine.swift:24` | `CalculatorEngine.freqPerWeek(everyNDays:)` | **REAL.** The `freqPerWeek` seen at the result-row sites is a *property* on the result structs, not this function. |
| `Sources/InjectBuddy/Core/Calculator/CalculatorEngine.swift:28` | `CalculatorEngine.units(forMl:unitsPerML:)` | **REAL.** An mL→insulin-units conversion, uncalled, in the app whose headline number is insulin units. |
| `Sources/InjectBuddy/Core/Calculator/SteroidCatalog.swift:45` | `SteroidCompound.defaultEster` | **REAL, deliberately abandoned.** `CalculatorEvaluate.swift:236` records that the evaluator "used to be `compound.defaultEster`" — T-44 removed the last reader and left the declaration. |
| `Sources/InjectBuddy/Core/Models/Models.swift:173` | `CycleWithItems.items` | **REAL.** `SupabaseBackendClient` fetches cycle items, groups them by cycle and assembles `CycleWithItems`. `.items` is then read nowhere. |
| `Sources/InjectBuddy/Core/Nav/NavItems.swift:188` | `CalculatorSlug.unlistedCases` | **REAL.** Ties to T-55: a ready-made list of exactly the calculators the capture harness cannot reach, unread. |
| `Sources/InjectBuddy/Features/Shell/ShellNavigator.swift:90` | `ShellNavigator.toggleDrawer()` | **REAL.** |
| `Sources/OnboardingKit/Flow/OnboardingFlow.swift:148` | `OnboardingFlow.skipCurrent()` | **REAL.** |
| `Sources/OnboardingKit/Model/OnboardingRoute.swift:185` | `OnboardingBranch.paywallBody(skipped:)` | **REAL.** `OnboardingFlow.paywallBody` (a property of the same name) calls `paywallOpener`, not this. |
| `Sources/OnboardingKit/Model/OnboardingStep.swift:57` | `OnboardingStep.isEndState` | **REAL.** |

### Design tokens defined and never applied

All **REAL**, all in `Sources/InjectBuddy/Core/Theme/Theme.swift`:

| line | token |
|---|---|
| `30` | `Theme.accentSoft2` |
| `44` | `Theme.tealText` — note `Theme.tealTextStrong` *is* used. Relevant to T-54, which is about a teal/navy inversion against the web. |
| `188` | `Theme.Typeface.tabLabel` |
| `189` | `Theme.Typeface.tabLabelActive` |
| `193` | `Theme.Typeface.resultValue` — the token named for the number a user acts on, unused by the screen that shows it. |
| `210` | `Theme.Radius.pill` |
| `263` | `Theme.greetingStops` |

Low severity individually. Collectively they are why "it looks slightly different from
the web" keeps recurring: the tokens that encode the intent exist and are not applied.

---

## 4 · The four that are not genuine — stated plainly

| file:line | declaration | why the tool is wrong / weak |
|---|---|---|
| `Sources/InjectBuddy/Core/Settings/SettingsStore.swift:13` | `SyringeScale.u40` | **FALSE POSITIVE.** A two-case enum where `label` and `unitsPerML` both branch on `self == .u100` and handle U-40 in the `else`. The case name genuinely never appears, and the behaviour is entirely correct. Structural: any two-case enum tested one way will do this. |
| `Sources/InjectBuddy/Core/Models/Models.swift:90` | `ProtocolStatus.draft` | **WEAK.** `Codable`, so a `saved_dosages` row carrying `"draft"` decodes into it. The tool cannot see the database. The finding underneath is still real — iOS only ever writes `.active` and never distinguishes the other two — but it is a product question, not dead code. |
| `Sources/InjectBuddy/Core/Models/Models.swift:92` | `ProtocolStatus.archived` | **WEAK.** Same. |
| `Sources/InjectBuddy/Core/Calculator/PlotterSeed.swift:63` | `PlotterSeed.sourceSlug` | **WEAK.** Written by the initialiser at `PlotterSeed.swift:185` and read by `PlotterSeed`'s synthesised `Hashable`, which the tests exercise. Nothing consults its value. |

**25 / 29 genuine ≈ 86% precision.** The residue is structural, not a tuning problem:
two-case enums and `Codable` cases reachable from data will always land here. Widening
the exclusion list to remove them would cost `UnitSystem.imperial`, which is a real
finding of exactly the same syntactic shape.

---

## 5 · Read only by `Tests/` (12) — alive in the suite, dead in the app

Not automatically wrong; a testing seam is a legitimate reason to exist. But a helper
only the tests call is often a helper the app was supposed to call and doesn't.

**An entire backend API is in this bucket:**

| file:line | declaration |
|---|---|
| `Sources/InjectBuddy/Core/Backend/BackendClient.swift:16` | `BackendClient.deleteDosage` |
| `Sources/InjectBuddy/Core/Backend/BackendClient.swift:27` | `BackendClient.profile` |
| `Sources/InjectBuddy/Core/Backend/MockBackendClient.swift:29`, `:39` | both conformer copies |
| `Sources/InjectBuddy/Core/Backend/SupabaseBackendClient.swift:221`, `:395` | both conformer copies |

Two protocol methods, three implementations each, and the only callers are unit tests.
No shipping screen deletes a protocol, and no shipping screen fetches the user's
profile. Six of the twelve entries in this bucket are those two methods.

The rest:

| file:line | declaration |
|---|---|
| `Sources/InjectBuddy/Core/Calculator/ProtocolSummary.swift:220` | `ProtocolSummary.describe` |
| `Sources/InjectBuddy/Core/Calendar/DoseProjection.swift:197` | `DoseVolume.perInjectionMl` |
| `Sources/InjectBuddy/Core/Models/InjectionSite.swift:50` | `InjectionSite.allKnown` |
| `Sources/InjectBuddy/Core/Nav/NavItems.swift:180` | `CalculatorSlug.withdrawnCases` |
| `Sources/InjectBuddy/Core/Nav/NavItems.swift:183` | `CalculatorSlug.collapsedCases` |
| `Sources/InjectBuddy/Features/Calendar/CalendarViewModel.swift:232` | `CalendarData.hasAnySchedule` |

---

## 6 · Underdetermined names (2) — the by-name blind spot, made visible

The tool matches names, not resolved symbols, so reads of one member count for every
member sharing its name. Rather than leave that silent, it applies the pigeonhole:
*N declarations of a name, fewer than N read sites in the whole tree, therefore at
least one is dead.* Which one needs a person.

**`prop defaultConc` — 3 declarations, 2 read sites**
`SteroidCatalog.swift:24` (`SteroidEster`), `:37` (`SteroidCompound`), `:167` (`SteroidPick`).

Resolved by hand: `SteroidPick.defaultConc` is the dead one. It calls
`SteroidCompound.defaultConc(for:)`, which nothing else calls, which reads
`SteroidCompound.defaultConc`, which nothing else reads. **A dead chain three deep** —
the whole per-compound / per-ester vial-strength seeding path, ending in the UI's
strength field staying at 200 for every compound. Only the pigeonhole surfaced it;
every individual declaration in the chain "has a reader".

**`prop barFraction` — 2 declarations, 1 read site**
`OnboardingFlow.swift:46`, `OnboardingStep.swift:52`. Not resolved here.

---

## 7 · If you change something and re-run

`--tsv` output is stable and sorted; diff two runs to see what a change added or
removed. Expect the count to **rise** after deleting dead code: transitive death is
invisible to a single pass, so removing the top of a chain exposes the rest.
