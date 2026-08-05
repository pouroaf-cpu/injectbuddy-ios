# SCREENS — the canonical inventory

> **Read-only to agents. Changes go through the owner.**

Recovered from `AUDIT.md` on the 2026-08-05 restructure. This is the list a capture run is counted
against, both ways — screens expected vs frames present. Anything not captured is **named with the
reason**, never silently absent: a missing frame and a frame nobody asked for look the same in a
folder.

Used by `ROLES/REVIEWER.md` (count both ways) and `ROLES/PLANNER.md` (coverage).

---

## Every screen means every screen

| Group | Screens |
|---|---|
| **Shell** | Dashboard · Calendar · Log-dose sheet · Tools · Add |
| **Calculators** | all fifteen |
| **Add funnel** | the funnel, and its confirm-start step |
| **Settings** | Settings, and the drawer |
| **Onboarding** | thirteen screens across six paths, from the **preview target** (no login needed) |
| **Onboarding end states** | both |

## Capture conditions

- One run, `content_size` at default — **set and reset in the same command** (`ENVIRONMENT.md`).
- **Assert arrival before every shutter.** Not a wait, not a sleep — assert something only that
  screen renders.
- **Screens that render the account's email or avatar** — Settings, the drawer — are captured with
  the identity scrolled off or cropped, and the crop rect stated. Assert the email is absent before
  the shutter; a scroll that did not move looks identical to one that worked.
