## T-54 — Every shell screen's header says the brand where the web says the screen
**Priority 5/10** · **Owner:** mac · **Agent:** `t54-headers` · **Status:** doing

**What:** on the web, the top bar names the screen you are on — `Dashboard`, `Injection Calendar`,
`Add a protocol` — often with a breadcrumb back to where you came from (`‹ Dashboard`). On iOS every
tab root shows the same brand lockup, `injectbuddy`, and the screen name appears below it as a large
title, or not at all.

**Why it is one task and not four:** it was written up separately in `SHELL-PARITY.md` §S-01 #9,
§S-02 #8 and §S-05 before it was obvious that all three are the same decision applied five times.
Fixing it screen by screen would produce five slightly different headers.

**Second recurring item, folded in here for the same reason:** the raised centre `Log dose` hero is
**teal** on the web and **navy** on iOS, on every screen that shows the tab bar. Teal is the web's
primary-action colour and navy is its icon/label colour; iOS has the pair inverted. Same inversion
appears on the log-dose sheet's own CTA (S-04 #6).

**Careful — this one interacts with T-05.** `RouteContent` gives the Dashboard an inline title and
every other tab root a large one, and that difference is T-05's leading candidate for the dead
pull-to-refresh. **Whatever is done here changes the thing T-05 is trying to measure**, so measure
T-05 first or the experiment is spoiled.

**Done when:** one header treatment names the screen on every shell root, photographed across all
five, and the hero matches the web's colour.
