# docs/ui-audit/archive — the audit trail, not the app

These are the per-cycle capture folders from 2026-08-01. **They are not what the app
looks like now.** Current state is `docs/ui-audit/2026-08-02-current/`.

`BOARD.md` puts it plainly: *"The per-cycle folders and `2026-08-01-current` are the
audit trail, not the app as it stands — don't open `cycle3` and read it as now."*
Moving them out of the top level is that sentence enforced by the filesystem instead of
by a warning nobody reads.

Every frame in here is **pre-serial**: the serial + log-row rule (`SCREENSHOT-LOG.md`,
BOARD §5.16) starts on 2026-08-02, and these frames are deliberately **not** backfilled
— an invented serial is a number that looks issued and was not (BOARD §5.32).

| Folder | What it captured |
|---|---|
| `2026-08-01/` | The original audit sweep — 17 frames plus `FINDINGS.md`. |
| `2026-08-01-cycle1/` … `2026-08-01-cycle10/` | One folder per fix/verify cycle, each with its own `README.md`. |
| `2026-08-01-controls/` | The control inventory — every distinct control measured at default and AX5. |
| `2026-08-01-logsheet/` | Log-sheet type scale, contrast and rows. |
| `2026-08-01-quickbuttons/` | Calculator quick buttons, and the 100-vs-300 field/engine bug found doing it. |
| `2026-08-01-signedout/` | Disclaimer gate and signed-out welcome. |

**Still at the top level, deliberately:** `2026-08-01-current/` — it is audit trail too,
but `Tests/InjectBuddyTests/AuditFolderConsistencyTests.swift` enumerates it by literal
name in `preSerialFolders` and asserts the folder exists. Moving it turns that
grandfather clause red. It needs the test edited in the same commit, which is a
deliberate act with BOARD §5.32 attached to it, not a side effect of a tidy-up.

Reference material is **not** archived and stays at the top level: `app-reference/`,
`calculator-reference/`, `onboarding-reference/`, `pwa-reference/`, `result-panel/`.
