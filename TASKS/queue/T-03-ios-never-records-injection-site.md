## T-03 — iOS never records the injection site
**Priority 6/10** · **Owner:** mac · **Status:** open

$ git log -S'~~T-03' --format='%h %ad %s' --date=format:'%Y-%m-%d %H:%M' -- TASKS.md
29a8ede 2026-08-03 22:51 T-01a: nine of the twelve TRT calculator differences, built
```

`0727e83` is the tip this session started from; the strike-through first appears in `29a8ede`, which
is **mac's own commit from today** and carries the subagent's work. What happened is the reverse of
what was recorded: win cloned at `29a8ede`, which already contained the closure, and read a
same-session strike-through as a pre-existing one. The subagent produced `InjectionSite.swift`, the
picker, 14 unit tests, a device round-trip proving `R Delt` on row `92c3af8f`, and T-06/T-07/T-08.
None of it was wasted.

**Left standing deliberately:** everything else in this entry, and the rule it produced. The stale
tree was real and the clone was the right fix. This correction narrows what it cost; it does not
excuse it — and per rule 7 the wrong version stays visible above rather than being deleted.

**Resolved:** cloned to `C:\Users\PFrew\Projects\injectbuddy-ios-repo`, branch
`feature/tabview-shell` at `29a8ede`. Windows can now cite a SHA, so rule 7 is satisfiable from both
sides.

**Still open, and it is the dangerous half:** `Projects\injectbuddy-ios` still exists as an untracked
copy holding an older `TASKS.md`. **Two files named TASKS.md, one of them a decoy.** It must be
deleted or made a symlink to the checkout — owner's call, since it also holds `mac-docs/` and some
Windows-only notes. Tracked as **T-50**.
