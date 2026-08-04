#!/usr/bin/env python3
# unread-decls.py — declarations in Sources/ that nothing in this repo reads.  (T-47)
#
# ─── WHY THIS EXISTS ─────────────────────────────────────────────────────────────
#
# On 2026-08-04 three separate defects turned out to be the same shape: an API that
# is PRESENT, CORRECT, and REFERENCED BY NOTHING.
#
#   · CalculatorCategory.subtitle — all four strings defined, ToolsScreen never
#     mentioned it.                                                        (T-01e)
#   · SteroidCatalog.canInject    — correct for all twelve compounds, consulted by
#     nothing, so the steroid calculator offered injectable inputs for oral-only
#     compounds and returned 0.75 mL / 75 units FOR A TABLET.              (T-44)
#   · .cyclePlotter               — isListed is true, but it is in no category's
#     member list, so Tools cannot reach it.                               (T-11)
#
# Two more were found the same day while building T-44: SteroidCompound.defaultConc(for:)
# and SteroidCompound.defaultTab are still unread by the UI, so vial strength stays at
# 200 and tablet strength at 10 whatever compound is picked. Anadrol ships 50 mg
# tablets, so its seeded 10 is wrong until the user notices and edits it.
#
# ALL FIVE WERE FOUND BY ACCIDENT, while doing something else. None of them fails a
# build, a unit test or a UI test, because **a declaration nobody reads is not a
# compile error, it is silence** — the same silence CLAUDE.md already records for a
# source file missing from an Xcode target. Five incidental finds in one day means the
# population is larger than five and nobody has ever looked on purpose.
#
# This is the code-facing half of one idea. The Windows side's doc-claim checker
# catches a SENTENCE that no longer matches the code; this catches a DECLARATION the
# code never consults. Same family: a thing that exists and is never read.
#
# ─── IT DOES NOT BUILD ANYTHING, ON PURPOSE ──────────────────────────────────────
#
# No xcodebuild, no xcodegen, no swift build, no SwiftSyntax, no toolchain at all —
# it is text analysis over the checked-out tree and takes well under a second. That is
# a deliberate constraint, for two reasons:
#
#   1. The rig is one resource. A concurrent build corrupts build.db, so a tool that
#      needed a build could only run when the device lock was free — i.e. rarely.
#   2. A check that costs 258 seconds gets run once, at the end, by whoever remembers.
#      A check that costs 0.4 seconds gets run whenever someone is curious. This
#      finding class is only ever found by curiosity, so cheapness IS the feature.
#
# The price of that constraint is stated honestly under "WHAT IT CANNOT DO" below.
#
# ─── USAGE ───────────────────────────────────────────────────────────────────────
#
#   scripts/unread-decls.py                  # the report
#   scripts/unread-decls.py --show-excluded  # also every declaration an exclusion
#                                            #   rule silenced, and WHICH rule
#   scripts/unread-decls.py --exclusions     # just the exclusion table + reasons
#   scripts/unread-decls.py --tsv            # one finding per line, for diffing runs
#   scripts/unread-decls.py --self-test      # prove the finder still finds things
#
# `docs/T47-UNREAD-DECLARATIONS.md` records the first run (2026-08-04), the reasoning
# behind each exclusion, and an honest per-finding verdict. It is a snapshot, not the
# truth — the truth is whatever this script prints today.
#
# RUN --self-test IF YOU CHANGE THE FINDER. It is a fixture with a matched pair of
# every case: one member that is read, one that is not, plus a comment and a string
# literal naming the dead ones. Verified on 2026-08-04 to FAIL when comment stripping
# is disabled (all three dead members go missing) and to FAIL when argument labels are
# counted as reads (the dead stored property goes missing — which is precisely how
# SteroidCompound.defaultTab hid for so long). A self-test that has never been seen red
# is decoration.
#
# Exit status is 0 whatever it finds. This is a LOOKING tool, not a gate: most
# survivors are judgement calls, and a check that fails the build on a judgement call
# gets its threshold tuned until it passes, which is the §5.32 shape — an exemption
# that exempts everything.
#
# ─── WHAT IT CANNOT DO — READ THIS BEFORE TRUSTING A ZERO ────────────────────────
#
#   · It matches by NAME, not by resolved symbol. Two members called `defaultConc` on
#     two different types are one name here. Reads of either count for both, so a name
#     shared with something live is a FALSE NEGATIVE — the sweep goes quiet about it.
#     (That is why the tool tags multi-declaration names in the report.)
#   · It cannot see reflection, KVC, #selector, or a name assembled from a string.
#   · It cannot see the web app or the database. A property that exists to be written
#     to Supabase and read by the PWA looks unread here and is not.
#   · Transitive death is invisible: a dead function that reads a property makes that
#     property look alive. Fix the top of a chain and re-run; more appears.
#   · It reads the tree as it is on disk, including uncommitted edits from other agents.
#
# It is biased toward OVER-COUNTING reads — when in doubt an occurrence is treated as
# a use. That trades misses (things it should have flagged and didn't) for precision
# (things it flags being real). A noisy sweep gets run once and ignored; that failure
# mode is worse than a quiet one.

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_ROOT = os.path.join(REPO, "Sources")
# Tests are NOT swept for declarations, but they ARE scanned for reads. A helper that
# only production-dead code calls is a different (and smaller) problem than a helper
# nothing calls at all, and conflating them buries the second under the first.
READ_ROOTS = [os.path.join(REPO, "Sources"), os.path.join(REPO, "Tests")]


# ═════════════════════════════════════════════════════════════════════════════════
# 1 · STRIP COMMENTS AND STRING LITERALS
#
# This is not a nicety. `canInject` appears 8 times in prose in this tree explaining
# why it is unread — a raw grep would count the explanation of the bug as evidence the
# bug is fixed. Comments are blanked to spaces rather than deleted so that byte offsets
# and line numbers survive untouched.
#
# String INTERPOLATION is kept: Text("\(vm.dose) mg") is a real read of `dose`, and
# throwing away the whole literal would lose it.
# ═════════════════════════════════════════════════════════════════════════════════

def strip_noise(src):
    out = []
    i, n = 0, len(src)
    ctx = [["code", 0]]  # kind, paren-depth (only meaningful for "interp")

    def blank(seg):
        out.append("".join(c if c == "\n" else " " for c in seg))

    while i < n:
        kind = ctx[-1][0]
        c = src[i]

        if kind in ("str", "mstr"):
            if kind == "mstr" and src.startswith('"""', i):
                out.append("   "); i += 3; ctx.pop(); continue
            if kind == "str" and c == '"':
                out.append(" "); i += 1; ctx.pop(); continue
            if kind == "str" and c == "\n":          # unterminated; bail out of it
                out.append("\n"); i += 1; ctx.pop(); continue
            if src.startswith("\\(", i):             # interpolation: keep the code
                out.append("  "); i += 2; ctx.append(["interp", 0]); continue
            if c == "\\" and i + 1 < n:              # escape
                blank(src[i:i + 2]); i += 2; continue
            blank(c); i += 1; continue

        # "code" and "interp" behave the same except for how ')' is treated
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j == -1 else j
            blank(src[i:j]); i = j; continue

        if src.startswith("/*", i):
            depth, j = 0, i
            while j < n:
                if src.startswith("/*", j):
                    depth += 1; j += 2; continue
                if src.startswith("*/", j):
                    depth -= 1; j += 2
                    if depth == 0:
                        break
                    continue
                j += 1
            blank(src[i:j]); i = j; continue

        if src.startswith('#"', i):                  # raw string, treat as plain
            j = src.find('"#', i + 2)
            j = n if j == -1 else j + 2
            blank(src[i:j]); i = j; continue

        if src.startswith('"""', i):
            out.append("   "); i += 3; ctx.append(["mstr", 0]); continue

        if c == '"':
            out.append(" "); i += 1; ctx.append(["str", 0]); continue

        if kind == "interp":
            if c == "(":
                ctx[-1][1] += 1
            elif c == ")":
                if ctx[-1][1] == 0:
                    out.append(" "); i += 1; ctx.pop(); continue
                ctx[-1][1] -= 1

        out.append(c); i += 1

    return "".join(out)


# ═════════════════════════════════════════════════════════════════════════════════
# 2 · FIND DECLARATIONS
# ═════════════════════════════════════════════════════════════════════════════════

MODIFIERS = (r"(?:@[A-Za-z_]\w*(?:\([^)]*\))?\s+|"
             r"(?:public|private|fileprivate|internal|open|final|static|class|"
             r"mutating|nonmutating|override|convenience|required|lazy|weak|unowned|"
             r"indirect|dynamic|optional|nonisolated|distributed)\s+)*")

TYPE_RE = re.compile(r"^\s*" + MODIFIERS + r"\b(struct|class|enum|extension|protocol|actor)\s+"
                     r"([A-Za-z_]\w*)([^{]*)")
FUNC_RE = re.compile(r"^\s*" + MODIFIERS + r"\bfunc\s+(`[^`]+`|[A-Za-z_]\w*)\s*(?:<[^>{]*>)?\s*\(")
PROP_RE = re.compile(r"^\s*" + MODIFIERS + r"\b(?:var|let)\s+(`[^`]+`|[A-Za-z_]\w*)\s*[:={\n]")
CASE_RE = re.compile(r"^\s*(?:indirect\s+)?case\s+(.+)$")
PRIVATE_RE = re.compile(r"^\s*(?:@[A-Za-z_]\w*(?:\([^)]*\))?\s+)*(private|fileprivate)\b")


class Decl:
    __slots__ = ("name", "kind", "owner", "owner_kind", "file", "line",
                 "visibility", "conformances", "in_preview", "attrs")

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)

    @property
    def qualified(self):
        return f"{self.owner}.{self.name}" if self.owner else self.name


def split_top_level_commas(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([<":
            depth += 1
        elif ch in ")]>":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def preview_ranges(lines):
    """Line ranges belonging to #Preview blocks or *_Previews types.

    A read that only happens in a preview is not a read by the shipping app — the
    canvas is the only thing that ever executes it. Kept as its own bucket rather
    than counted, because a preview-only reference is exactly the state
    CalculatorCategory.subtitle was in: demonstrably rendered somewhere, and not
    where a user could see it."""
    ranges = []
    for idx, line in enumerate(lines):
        if re.match(r"^\s*#Preview\b", line) or re.match(r"^\s*(?:\w+\s+)*struct\s+\w*_Previews\b", line):
            depth, started, end = 0, False, idx
            for j in range(idx, len(lines)):
                depth += lines[j].count("{") - lines[j].count("}")
                if "{" in lines[j]:
                    started = True
                end = j
                if started and depth <= 0:
                    break
            ranges.append((idx + 1, end + 1))
    return ranges


def scan_declarations(path, text):
    lines = text.split("\n")
    previews = preview_ranges(lines)

    def in_preview(ln):
        return any(a <= ln <= b for a, b in previews)

    decls = []
    conformance_map = {}   # type name -> set of conformances / inherited names
    protocol_members = set()

    stack = []             # frames: (kind, name) for types, None for anything else
    pending = None
    # Attributes are often on their own line above the declaration — @main is always
    # written that way. Missing it made the app's own entry point the top finding of
    # the first run, which is the sort of result that gets a tool closed unread.
    pending_attrs = set()

    for ln, raw in enumerate(lines, 1):
        line = raw
        attr_only = re.match(r"^\s*(@[A-Za-z_]\w*(?:\([^)]*\))?\s*)+$", line)
        if attr_only:
            pending_attrs.update(re.findall(r"@([A-Za-z_]\w*)", line))
            continue
        attrs = pending_attrs | set(re.findall(r"@([A-Za-z_]\w*)", line))
        pending_attrs = set()

        top = stack[-1] if stack else None
        inside_type = top is not None and top[0] != "__brace__"
        owner_kind = top[0] if inside_type else ""
        owner = top[1] if inside_type else ""

        m = TYPE_RE.match(line)
        if m and "{" in line[m.end(2):]:
            kind, name, tail = m.group(1), m.group(2), m.group(3)
            confs = set()
            if ":" in tail:
                for part in split_top_level_commas(tail.split(":", 1)[1]):
                    part = part.strip().split("<")[0].strip()
                    if part and part != "where":
                        confs.add(part)
            conformance_map.setdefault(name, set()).update(confs)
            pending = (kind, name)
            if kind != "extension":
                decls.append(Decl(name=name, kind="type", owner="", owner_kind="",
                                  file=path, line=ln,
                                  visibility="private" if PRIVATE_RE.match(line) else "internal",
                                  conformances=confs, in_preview=in_preview(ln), attrs=attrs))
        elif inside_type:
            vis = "private" if PRIVATE_RE.match(line) else "internal"
            fm = FUNC_RE.match(line)
            pm = PROP_RE.match(line)
            cm = CASE_RE.match(line) if owner_kind == "enum" else None
            if fm:
                nm = fm.group(1).strip("`")
                decls.append(Decl(name=nm, kind="func", owner=owner, owner_kind=owner_kind,
                                  file=path, line=ln, visibility=vis,
                                  conformances=set(), in_preview=in_preview(ln), attrs=attrs))
                if owner_kind == "protocol":
                    protocol_members.add(nm)
            elif pm:
                nm = pm.group(1).strip("`")
                decls.append(Decl(name=nm, kind="prop", owner=owner, owner_kind=owner_kind,
                                  file=path, line=ln, visibility=vis,
                                  conformances=set(), in_preview=in_preview(ln), attrs=attrs))
                if owner_kind == "protocol":
                    protocol_members.add(nm)
            elif cm:
                for chunk in split_top_level_commas(cm.group(1)):
                    cn = re.match(r"\s*([A-Za-z_]\w*)", chunk)
                    if cn:
                        decls.append(Decl(name=cn.group(1), kind="case", owner=owner,
                                          owner_kind=owner_kind, file=path, line=ln,
                                          visibility=vis, conformances=set(),
                                          in_preview=in_preview(ln), attrs=attrs))

        # Brace bookkeeping last, so a decl on a line is attributed to the scope it
        # sits IN, not the scope it opens.
        for ch in line:
            if ch == "{":
                if pending:
                    stack.append(pending); pending = None
                else:
                    stack.append(("__brace__", ""))
            elif ch == "}":
                if stack:
                    stack.pop()

    return decls, conformance_map, protocol_members


# ═════════════════════════════════════════════════════════════════════════════════
# 3 · INDEX EVERY IDENTIFIER OCCURRENCE
#
# One tokenising pass over the whole corpus, then every question is a dict lookup.
# For each occurrence we record what came immediately before it (`.` = member access,
# `$` = SwiftUI binding) and what came immediately after (`(` = call, `:` = argument
# label / type annotation / dictionary key).
#
# The `:` distinction is what makes this tool see the two live examples at all.
# `SteroidCompound.defaultTab` occurs THIRTEEN times in SteroidCatalog.swift — once as
# its declaration and twelve times as `defaultTab: 10` inside a memberwise init. Every
# one of those twelve is a WRITE. A plain "appears more than once" test calls this
# property alive; it is not, and it is why Anadrol seeds a 10 mg tablet when the web
# seeds 50.
# ═════════════════════════════════════════════════════════════════════════════════

IDENT_RE = re.compile(r"[A-Za-z_]\w*")


def index_file(path, text, index):
    for ln, line in enumerate(text.split("\n"), 1):
        for m in IDENT_RE.finditer(line):
            s, e = m.span()
            prev = line[s - 1] if s > 0 else ""
            rest = line[e:]
            stripped = rest.lstrip(" ")
            nxt = stripped[0] if stripped else ""
            index.setdefault(m.group(0), []).append(
                (path, ln, prev, nxt == "(", nxt == ":")
            )


# ═════════════════════════════════════════════════════════════════════════════════
# 4 · THE EXCLUSION LIST
#
# THIS IS THE PART THAT MATTERS. "Referenced exactly once" is a trivial query; the
# work is in knowing which of those references are fine. Protocol conformances,
# CaseIterable members, anything reached by reflection, SwiftUI's `body`, Codable's
# synthesised members and preview-only code all look unreferenced and all are correct.
#
# EVERY ENTRY CARRIES A REASON, and that is not decoration. Without it a later reader
# cannot tell a considered exemption from an oversight — which is the one thing the
# author of the doc-claim checker said they would have done differently. An exemption
# nobody can audit is an exemption that eventually exempts everything.
#
# If you add an entry, say WHO reads it instead of your code. If you cannot name the
# reader, it is not an exclusion, it is a finding you did not want.
# ═════════════════════════════════════════════════════════════════════════════════

# name -> reason.  Matched on the member's own name, any type.
NAME_EXCLUSIONS = {
    "body":            "SwiftUI View / App / Scene / ViewModifier requirement. SwiftUI calls it through the protocol; nothing in the app ever names it.",
    "previews":        "PreviewProvider requirement. Xcode's canvas calls it; it has no runtime caller by design.",
    "id":              "Identifiable requirement. ForEach and List read it through the protocol witness, never by name.",
    "rawValue":        "RawRepresentable requirement. Synthesised for a raw-valued enum and read by the compiler's own conformance.",
    "allCases":        "CaseIterable requirement, usually synthesised. Read through the protocol.",
    "hashValue":       "Hashable requirement, superseded by hash(into:) but still declarable.",
    "hash":            "Hashable requirement (hash(into:)). The hasher calls it, your code does not.",
    "encode":          "Encodable requirement (encode(to:)). JSONEncoder calls it.",
    "description":     "CustomStringConvertible requirement. String interpolation and print() reach it through the protocol.",
    "debugDescription": "CustomDebugStringConvertible requirement, read by the debugger.",
    "errorDescription": "LocalizedError requirement, read by the error-presentation machinery.",
    "wrappedValue":    "Property-wrapper / DynamicProperty requirement. The compiler rewrites accesses into it.",
    "projectedValue":  "Property-wrapper requirement backing the `$` form. The compiler generates the access.",
    "defaultValue":    "EnvironmentKey requirement, read by the environment when no value is set.",
    "path":            "Shape requirement. SwiftUI calls it to rasterise; nothing names it.",
    "animatableData":  "Animatable requirement, driven by the animation system.",
    "makeUIView":      "UIViewRepresentable requirement.",
    "updateUIView":    "UIViewRepresentable requirement.",
    "makeUIViewController": "UIViewControllerRepresentable requirement.",
    "updateUIViewController": "UIViewControllerRepresentable requirement.",
    "makeCoordinator": "UIViewRepresentable requirement, called by SwiftUI before makeUIView.",
    "makeBody":        "ButtonStyle / LabelStyle / ProgressViewStyle requirement.",
    "sizeThatFits":    "Layout requirement.",
    "placeSubviews":   "Layout requirement.",
    "main":            "@main entry point. The runtime calls it; there is no call site to find.",
    "CodingKeys":      "Codable's synthesised key type. The synthesised coder is its only reader.",
}

# Rule-based exclusions. Each returns a reason string, or None.
# NOTE — there is deliberately NO rule excluding a declaration made ON a protocol.
# The first draft had one ("its call sites are on the conformers") alongside the
# conformer rule below ("calls go through the protocol"). Together those two reasons
# form a closed loop that silences a genuinely dead API completely: BackendClient
# .deleteDosage and .profile have no caller anywhere, and the pair of rules hid all
# six declarations of them. The protocol declaration is the ONE place where "nothing
# calls this" is a meaningful statement about the whole API, so it stays reportable.
# An exclusion whose justification points at another exclusion is not a justification.

def rule_satisfies_protocol_requirement(d, ctx):
    if d.owner_kind == "protocol":
        return None
    if d.kind in ("func", "prop") and d.name in ctx["protocol_members"]:
        return ("Satisfies a requirement of a protocol declared in this repo. Calls go "
                "through the existential/generic, so the conformer's own copy has no "
                "direct call site. (If the REQUIREMENT is dead, the protocol declaration "
                "will say so — this rule only silences the conformers.)")
    return None


def rule_codable_stored_property(d, ctx):
    if d.kind != "prop":
        return None
    confs = ctx["conformances"].get(d.owner, set())
    if confs & {"Codable", "Encodable", "Decodable"}:
        return ("Stored property of a %s type. The synthesised coder reads it by "
                "reflection to build the JSON body iOS PostgRESTs to Supabase, so the "
                "absence of a call site is the expected state, not a defect. NOTE this "
                "is the widest rule here: it also hides 'decoded and never displayed', "
                "which IS a real category. Re-run with --show-excluded before trusting "
                "silence about a model type." % ",".join(sorted(confs & {"Codable", "Encodable", "Decodable"})))
    return None


def rule_operator_or_subscript(d, ctx):
    if d.name in ("subscript", "init", "deinit") or not re.match(r"^[A-Za-z_]", d.name):
        return "Initialiser, deinitialiser, subscript or operator — resolved by shape rather than by name, so a name search cannot answer the question at all."
    return None


def rule_declared_in_preview(d, ctx):
    if d.in_preview:
        return "Declared inside a #Preview / _Previews block. Preview scaffolding has no shipping caller by construction."
    return None


def rule_underscore_prefixed(d, ctx):
    if d.name.startswith("_"):
        return "Leading underscore is the project's own 'deliberately unused' marker, and also how property-wrapper storage is spelled."
    return None


def rule_coding_keys_case(d, ctx):
    if d.kind == "case" and d.owner == "CodingKeys":
        return ("A case of a CodingKeys enum. The synthesised encoder/decoder is its only "
                "reader, and the compiler already enforces the one thing that could go "
                "wrong here — a key with no matching property does not compile.")
    return None


def rule_entry_point(d, ctx):
    if "main" in getattr(d, "attrs", set()) or "UIApplicationMain" in getattr(d, "attrs", set()):
        return "@main entry point. The runtime instantiates it; there is no call site to find, ever."
    return None


RULES = [
    ("satisfies-protocol",     rule_satisfies_protocol_requirement),
    ("coding-keys-case",       rule_coding_keys_case),
    ("entry-point",            rule_entry_point),
    ("codable-stored-prop",    rule_codable_stored_property),
    ("init-or-operator",       rule_operator_or_subscript),
    ("declared-in-preview",    rule_declared_in_preview),
    ("underscore-prefixed",    rule_underscore_prefixed),
]


def excluded_reason(d, ctx):
    if d.name in NAME_EXCLUSIONS:
        return "well-known-requirement", NAME_EXCLUSIONS[d.name]
    for rule_name, fn in RULES:
        r = fn(d, ctx)
        if r:
            return rule_name, r
    return None, None


# ═════════════════════════════════════════════════════════════════════════════════
# 5 · CLASSIFY READS
# ═════════════════════════════════════════════════════════════════════════════════

def read_sites(d, index, decl_lines, decl_lines_any, member_names):
    """Occurrences of this name that plausibly READ it.

    Deliberately generous. Everything ambiguous is scored as a read, because a false
    negative costs a missed finding while a false positive costs the tool's
    credibility — and a sweep nobody believes gets run once."""
    hits = index.get(d.name, [])
    own = decl_lines.get((d.name, d.kind), set())
    out = []
    for (path, ln, prev, is_call, is_label) in hits:
        if d.kind == "func":
            if (path, ln) in own:
                continue
            if is_call:
                out.append((path, ln))
            elif prev == "." and d.name not in member_names:
                # A dotted mention with no parentheses is an unapplied method
                # reference (`onTap: vm.reload`) — but ONLY if no property or case
                # shares the name. SteroidCompound.defaultConc(for:) is uncalled while
                # SteroidEster.defaultConc is read on the very next line; treating the
                # property read as a method reference hid one of the two findings this
                # tool was written to catch.
                out.append((path, ln))
        elif d.kind == "type":
            if (path, ln) in own:
                continue
            # `.Foo` counts. Nested namespaces are the dominant style here —
            # Theme.Typeface, Theme.Spacing, OnboardingCopy.Welcome — and skipping
            # dotted mentions declared all fifteen of them dead in the first run.
            out.append((path, ln))
        else:                          # prop / case
            if prev in (".", "$"):
                # `case .foo:` and `self.foo` and `$binding` — always a read, even on
                # a declaration line (a forwarding computed property reads the thing
                # it forwards to).
                if prev == "." and (path, ln) in own and is_label:
                    continue
                out.append((path, ln))
                continue
            # Any declaration OF THIS NAME, of any kind, disqualifies a bare mention on
            # that line — it is the name being declared, not read. Using only the
            # same-kind declarations let `func defaultConc(for:)` on line 51 count as a
            # bare read of the property `defaultConc`, which pushed the read tally up
            # to exactly the number of declarations and made the whole family look
            # accounted for. That one off-by-one hid a live finding.
            if (path, ln) in decl_lines_any.get(d.name, ()):
                continue
            if is_label:
                # `foo: 1` is an argument label, a type annotation or a dictionary
                # key. None of those read the member. THIS IS THE RULE THAT MAKES
                # SteroidCompound.defaultTab visible.
                continue
            if path != d.file:
                # A bare identifier in another file is a different symbol unless it
                # is a global; members are reached with a dot.
                continue
            out.append((path, ln))
    return out


# ═════════════════════════════════════════════════════════════════════════════════
# 6 · SELF-TEST
#
# CLAUDE.md: show a check FAILING against a deliberately wrong input before trusting
# it. Four instruments in one day reported success while doing nothing, and a sweep
# that finds nothing looks exactly like a sweep that is broken.
#
# The fixture below contains a matched pair of every case: one member that is read and
# one that is not, plus a comment and a string literal that mention the dead names. If
# stripping regressed, the comment would rescue `deadProp` and the test would say so.
#
#   scripts/unread-decls.py --self-test
# ═════════════════════════════════════════════════════════════════════════════════

SELF_TEST_FIXTURE = r'''
struct Thing {
    let liveProp: Int
    let deadProp: Int
    func liveFunc() -> Int { liveProp }
    func deadFunc() -> Int { 1 }
}

enum Place: CaseIterable {
    case shown
    case hidden
}

// A comment naming deadProp, deadFunc and hidden. Stripping must ignore all three.
enum Caller {
    static let thing = Thing(liveProp: 1, deadProp: 2)
    static let note = "deadFunc() and deadProp and .hidden, as text"
    static func go() -> Int {
        let p = Place.shown
        _ = p
        return thing.liveFunc() + thing.liveProp
    }
}
'''

SELF_TEST_EXPECT_UNREAD = {("deadProp", "prop"), ("deadFunc", "func"), ("hidden", "case")}
SELF_TEST_EXPECT_READ = {("liveProp", "prop"), ("liveFunc", "func"), ("shown", "case"),
                         ("Thing", "type"), ("Place", "type")}


def self_test():
    path = "<fixture>.swift"
    text = strip_noise(SELF_TEST_FIXTURE)
    index = {}
    index_file(path, text, index)
    decls, cmap, pmem = scan_declarations(path, text)
    ctx = {"conformances": cmap, "protocol_members": pmem}

    decl_lines, decl_lines_any = {}, {}
    for d in decls:
        decl_lines.setdefault((d.name, d.kind), set()).add((d.file, d.line))
        decl_lines_any.setdefault(d.name, set()).add((d.file, d.line))
    member_names = {d.name for d in decls if d.kind in ("prop", "case")}

    unread = set()
    for d in decls:
        if read_sites(d, index, decl_lines, decl_lines_any, member_names):
            continue
        if excluded_reason(d, ctx)[0]:
            continue
        unread.add((d.name, d.kind))

    failures = []
    for want in SELF_TEST_EXPECT_UNREAD:
        if want not in unread:
            failures.append("MISSED  %s %s — it is unread in the fixture and was not "
                            "reported. The finder is blind to this shape." % (want[1], want[0]))
    for want in SELF_TEST_EXPECT_READ:
        if want in unread:
            failures.append("FALSE   %s %s — it IS read in the fixture and was reported "
                            "anyway. The reader is under-counting." % (want[1], want[0]))

    print("self-test: %d declarations parsed from the fixture" % len(decls))
    print("           reported unread: %s"
          % ", ".join(sorted("%s %s" % (k, n) for n, k in unread)) or "(none)")
    if failures:
        print("\nSELF-TEST FAILED:")
        for f in failures:
            print("  " + f)
        return 1
    print("           expected unread: deadProp, deadFunc, hidden — all three found,")
    print("           and none of liveProp / liveFunc / shown / Thing / Place reported.")
    print("           The comment and the string literal naming the dead members did")
    print("           not rescue them, so comment stripping is intact.")
    print("SELF-TEST PASSED")
    return 0


def main():
    args = sys.argv[1:]
    want_excluded = "--show-excluded" in args
    only_exclusions = "--exclusions" in args
    as_tsv = "--tsv" in args

    if "--self-test" in args:
        return self_test()

    if only_exclusions:
        print("EXCLUSION LIST — every entry names who reads the declaration instead of your code.\n")
        print("BY NAME (any type):")
        for k in sorted(NAME_EXCLUSIONS):
            print("  %-24s %s" % (k, NAME_EXCLUSIONS[k]))
        print("\nBY RULE:")
        for rule_name, fn in RULES:
            doc = (fn.__doc__ or "").strip()
            print("  %-24s see rule_%s in this file" % (rule_name, fn.__name__.replace("rule_", "")))
        print("\n  (rule reasons are printed alongside each silenced declaration under --show-excluded)")
        return 0

    swift_files = []
    for root, _dirs, files in os.walk(SOURCE_ROOT):
        for f in files:
            if f.endswith(".swift"):
                swift_files.append(os.path.join(root, f))
    swift_files.sort()

    read_files = []
    for r in READ_ROOTS:
        for root, _dirs, files in os.walk(r):
            for f in files:
                if f.endswith(".swift"):
                    read_files.append(os.path.join(root, f))

    # Index every identifier in Sources/ + Tests/
    index = {}
    stripped_cache = {}
    for p in read_files:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            t = strip_noise(fh.read())
        stripped_cache[p] = t
        index_file(p, t, index)

    # Declarations, from Sources/ only
    all_decls = []
    conformances = {}
    protocol_members = set()
    for p in swift_files:
        d, cmap, pmem = scan_declarations(p, stripped_cache[p])
        all_decls.extend(d)
        for k, v in cmap.items():
            conformances.setdefault(k, set()).update(v)
        protocol_members |= pmem

    ctx = {"conformances": conformances, "protocol_members": protocol_members}

    decl_lines = {}
    for d in all_decls:
        decl_lines.setdefault((d.name, d.kind), set()).add((d.file, d.line))
    # A type's `extension Foo` line is not a use of Foo either.
    for p in swift_files:
        for ln, line in enumerate(stripped_cache[p].split("\n"), 1):
            m = re.match(r"^\s*(?:\w+\s+)*extension\s+([A-Za-z_]\w*)", line)
            if m:
                decl_lines.setdefault((m.group(1), "type"), set()).add((p, ln))

    decl_lines_any = {}
    for d in all_decls:
        decl_lines_any.setdefault(d.name, set()).add((d.file, d.line))

    name_counts = {}
    for d in all_decls:
        name_counts[(d.name, d.kind)] = name_counts.get((d.name, d.kind), 0) + 1

    # Names that exist as a property or enum case anywhere. Used to disambiguate a
    # dotted mention of a function name from a dotted read of a same-named property.
    member_names = {d.name for d in all_decls if d.kind in ("prop", "case")}

    raw_unread, excluded, unread, test_only = [], [], [], []
    sites_by_key = {}

    for d in all_decls:
        sites = read_sites(d, index, decl_lines, decl_lines_any, member_names)
        sites_by_key.setdefault((d.name, d.kind), set()).update(sites)
        if sites:
            prod = [s for s in sites if "/Tests/" not in s[0]]
            if not prod:
                test_only.append((d, sites))
            continue
        raw_unread.append(d)
        rule, reason = excluded_reason(d, ctx)
        if rule:
            excluded.append((d, rule, reason))
        else:
            unread.append(d)

    # ── UNDERDETERMINED ──────────────────────────────────────────────────────────
    # The by-name blind spot, made visible instead of left silent.
    #
    # Three different types here declare a member called `defaultConc`. Only two read
    # sites exist for that name in the whole tree, so at least one of the three is
    # dead — but every one of them individually "has reads", because the reads of the
    # others count for it. SteroidCompound.defaultConc(for:) is exactly that case: it
    # is called once, by SteroidPick.defaultConc, which nothing calls at all. A chain
    # of two, invisible to a per-declaration check.
    #
    # Pigeonhole: N declarations sharing a name, with fewer than N distinct read
    # sites, means at least one of them is unread. Which one it is needs a human.
    #
    # A protocol requirement and its conformers are ONE logical declaration for this
    # purpose — BackendClient has two conformers, so every method on it is declared
    # three times and called once, and the raw pigeonhole flagged all eleven of them.
    # Eleven structurally-guaranteed hits is how a sweep gets closed unread, so
    # conformer copies do not count toward N.
    underdetermined = []
    for (name, kind), count in sorted(name_counts.items()):
        if kind == "type":
            continue
        group = [d for d in all_decls if d.name == name and d.kind == kind]
        group = [d for d in group if excluded_reason(d, ctx)[0] != "satisfies-protocol"]
        if len(group) < 2:
            continue
        if all(excluded_reason(d, ctx)[0] for d in group):
            continue
        nsites = len(sites_by_key.get((name, kind), ()))
        if 0 < nsites < len(group):
            underdetermined.append((name, kind, len(group), nsites, group))

    def rel(p):
        return os.path.relpath(p, REPO)

    def sig(d):
        owner = (d.owner + ".") if d.owner else ""
        return "%s %s%s" % (d.kind, owner, d.name)

    if as_tsv:
        for d in sorted(unread, key=lambda x: (x.file, x.line)):
            print("UNREAD\t%s:%d\t%s\t%s" % (rel(d.file), d.line, sig(d), d.visibility))
        for d, sites in sorted(test_only, key=lambda x: (x[0].file, x[0].line)):
            print("TEST-ONLY\t%s:%d\t%s\t%d test reads" % (rel(d.file), d.line, sig(d), len(sites)))
        for name, kind, count, nsites, group in underdetermined:
            for d in sorted(group, key=lambda x: (x.file, x.line)):
                print("UNDERDETERMINED\t%s:%d\t%s\t%d decls / %d reads"
                      % (rel(d.file), d.line, sig(d), count, nsites))
        return 0

    print("unread-decls — declarations in Sources/ that nothing in Sources/ or Tests/ reads")
    print("=" * 86)
    print("%d Swift files swept, %d declarations found (var / let / func / case / type)."
          % (len(swift_files), len(all_decls)))
    print("%d had ZERO read sites before exclusions." % len(raw_unread))
    print("%d of those were silenced by an exclusion rule  (--show-excluded to see them)."
          % len(excluded))
    print()

    print("── UNREAD (%d) ─── no hand-written code reads these ──" % len(unread))
    print("   'Read' means read by code someone wrote. A stored property of an")
    print("   Equatable / Hashable / Codable type is always read by the SYNTHESISED")
    print("   conformance, so it is never literally unused — but nothing consults its")
    print("   VALUE, which is the question this sweep asks and the one SteroidCatalog")
    print("   .defaultTab answers wrongly for Anadrol.")
    print()
    print("   Tags:  [private] file-local, so this verdict is reliable.")
    print("          [ambiguous-name xN] the name is declared N times — reads of one")
    print("                           count for all, so a zero here is unusually strong.")
    print()
    for d in sorted(unread, key=lambda x: (x.file, x.line)):
        tags = []
        if d.visibility == "private":
            tags.append("private")
        if name_counts[(d.name, d.kind)] > 1:
            tags.append("ambiguous-name x%d" % name_counts[(d.name, d.kind)])
        confs = conformances.get(d.owner, set())
        if "CaseIterable" in confs and d.kind == "case":
            tags.append("CaseIterable — may be reached via allCases")
        t = ("  [" + "] [".join(tags) + "]") if tags else ""
        print("  %-52s %s%s" % ("%s:%d" % (rel(d.file), d.line), sig(d), t))
    print()

    print("── READ ONLY BY TESTS (%d) ─── alive in the suite, dead in the app ──" % len(test_only))
    print("   Not automatically wrong: a testing seam is a legitimate reason to exist.")
    print("   Worth a look anyway — a helper only the tests call is a helper the app")
    print("   was supposed to call and doesn't.")
    print()
    for d, sites in sorted(test_only, key=lambda x: (x[0].file, x[0].line)):
        print("  %-52s %s   (%d test read%s)"
              % ("%s:%d" % (rel(d.file), d.line), sig(d), len(sites), "" if len(sites) == 1 else "s"))
    print()

    print("── UNDERDETERMINED NAMES (%d) ─── at least one of each group is dead ──"
          % len(underdetermined))
    print("   N declarations share a name; the tree holds fewer than N read sites for")
    print("   it, so by pigeonhole at least one is unread — but reads of the others")
    print("   mask which. This is the tool's by-name limit made visible rather than")
    print("   left silent. Resolving one needs a person; there is no cheap way round it.")
    print()
    for name, kind, count, nsites, group in underdetermined:
        print("  %s `%s` — %d declarations, %d read site%s in the whole tree:"
              % (kind, name, count, nsites, "" if nsites == 1 else "s"))
        for d in sorted(group, key=lambda x: (x.file, x.line)):
            print("      %-48s %s" % ("%s:%d" % (rel(d.file), d.line), sig(d)))
    print()

    if want_excluded:
        print("── EXCLUDED (%d) ─── unread, and expected to be ──" % len(excluded))
        by_rule = {}
        for d, rule, reason in excluded:
            by_rule.setdefault(rule, []).append((d, reason))
        for rule in sorted(by_rule):
            items = by_rule[rule]
            print("\n  %s  (%d)" % (rule, len(items)))
            reasons = {r for _, r in items}
            if len(reasons) == 1:
                print("  reason: %s" % items[0][1])
                for d, _ in sorted(items, key=lambda x: (x[0].file, x[0].line)):
                    print("      %-48s %s" % ("%s:%d" % (rel(d.file), d.line), sig(d)))
            else:
                # NAME_EXCLUSIONS carries a different reason per name; printing only
                # the first one would attribute six declarations to one entry's
                # justification, which is the auditability failure this whole exercise
                # is about.
                for d, r in sorted(items, key=lambda x: (x[0].file, x[0].line)):
                    print("      %-48s %s" % ("%s:%d" % (rel(d.file), d.line), sig(d)))
                    print("          reason: %s" % r)
        print()

    print("SUMMARY  %d declarations · %d unread raw · %d excluded · %d unread · "
          "%d test-only · %d underdetermined"
          % (len(all_decls), len(raw_unread), len(excluded), len(unread),
             len(test_only), len(underdetermined)))
    print("Read the CANNOT-DO list at the top of this file before treating a zero as proof.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
