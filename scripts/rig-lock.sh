#!/bin/bash
# rig-lock.sh — exclusive access to the one simulator.
#
# WHY THIS EXISTS. Discipline failed twice on 2026-08-03. Two agents were each told
# they were the sole owner of the rig, both ran UI tests against one simulator, and both
# edited one test file with no commit between them. The numbers survived on a timing
# argument, but the code that produced them was a mixture nobody could reconstruct — and
# a green you cannot attribute is not evidence.
#
# The second failure is the one that matters: a point-in-time `pgrep` CANNOT prove
# exclusivity, because something can start a second later. That is exactly what happened
# — a build began 28 seconds after a clean check. No amount of checking harder fixes it.
# So this replaces the discipline with a mechanism.
#
# THE TRADE THIS MAKES is the one the project makes everywhere else: turn an
# unattributable run into a LOUD REFUSAL. A run that dies saying "PID 50962 holds the
# rig" costs a minute. A run that quietly shares the device costs a finding nobody can
# close.
#
#   scripts/rig-lock.sh acquire OWNER "what I am doing"   # exits 1 if held, naming the holder
#   scripts/rig-lock.sh release OWNER
#   scripts/rig-lock.sh status
#
# OWNER is a string YOU choose and reuse across calls — e.g. your agent name. It is NOT
# a PID, and that is the whole point (see below).
#
# ALWAYS pair acquire with a trap so a crash cannot leave the rig locked:
#   scripts/rig-lock.sh acquire sweep4 "shear re-measure" || exit 1
#   trap 'scripts/rig-lock.sh release sweep4' EXIT
#
# WHY NOT A PID — THIS SCRIPT HAS NOW BEEN WRONG TWICE, BOTH TIMES BY BELIEVING A PID
# OUTLIVES THE CALL THAT WROTE IT.
#   v1 recorded $$   — the script'"'"'s own PID, dead the instant `acquire` returned.
#   v2 recorded $PPID — correct for an interactive shell, but under the agent harness
#                       EVERY command runs in its own short-lived shell, so $PPID is a
#                       different dead process on every call. A sweep acquired the lock
#                       and it was stale before the next command ran.
# Both versions provided NO mutual exclusion while printing that they had. So the lease
# is now TIME-based with a caller-chosen owner string: it expires on its own, it does not
# depend on any process still existing, and a stale lease is loud rather than invisible.

set -uo pipefail

LOCK="${TMPDIR:-/tmp}/injectbuddy-rig.lock"
# A device task that has done nothing for this long is assumed dead. Long enough for a
# cold build (258s) plus a real signed-in UI run (159s) with room to spare.
LEASE_SECONDS="${RIG_LEASE_SECONDS:-900}"

case "${1:-status}" in
  acquire)
    OWNER="${2:-}"
    WHAT="${3:-unnamed task}"
    if [ -z "$OWNER" ]; then
      echo "usage: rig-lock.sh acquire OWNER \"what\"  — OWNER is a string you reuse" >&2
      exit 2
    fi
    if [ -f "$LOCK" ]; then
      HOLDER=$(sed -n '1p' "$LOCK" 2>/dev/null)
      HOLDER_WHAT=$(sed -n '2p' "$LOCK" 2>/dev/null)
      HOLDER_WHEN=$(sed -n '3p' "$LOCK" 2>/dev/null)
      HOLDER_EPOCH=$(sed -n '4p' "$LOCK" 2>/dev/null)
      AGE=$(( $(date +%s) - ${HOLDER_EPOCH:-0} ))
      if [ "$HOLDER" = "$OWNER" ]; then
        echo "RIG already held by you ($OWNER) since $HOLDER_WHEN — refreshing lease."
        { echo "$OWNER"; echo "$WHAT"; date '+%Y-%m-%d %H:%M:%S'; date +%s; } > "$LOCK"
        exit 0
      fi
      if [ "$AGE" -lt "$LEASE_SECONDS" ]; then
        echo "RIG LOCKED — refusing to start." >&2
        echo "  held by '$HOLDER': $HOLDER_WHAT" >&2
        echo "  since $HOLDER_WHEN (${AGE}s ago, lease ${LEASE_SECONDS}s)" >&2
        echo "  Do NOT proceed and do NOT kill it. Report this and wait." >&2
        exit 1
      fi
      # Lease expired. Say so loudly — a silent steal is how a stale lock becomes
      # invisible, and an expired lease may mean the holder DIED MID-RUN with the
      # simulator in an unknown state.
      echo "EXPIRED LEASE from '$HOLDER' ($HOLDER_WHAT, ${AGE}s old) — reclaiming." >&2
      echo "  If that task is still running, YOU ARE ABOUT TO SHARE THE DEVICE. Check first." >&2
      rm -f "$LOCK"
    fi
    # RECORD THE CALLER'S PID ($PPID), NOT OUR OWN.
    # This script exits the instant `acquire` returns, so a lock naming $$ is stale
    # before the caller has run anything — it would provide NO mutual exclusion at all.
    # Found by self-test on 2026-08-03: a second acquire happily reclaimed a "stale"
    # lock two seconds old. That is why a check is made to fail before it is trusted.
    { echo "$OWNER"; echo "$WHAT"; date '+%Y-%m-%d %H:%M:%S'; date +%s; } > "$LOCK"
    echo "RIG ACQUIRED by '$OWNER' — $WHAT (lease ${LEASE_SECONDS}s, re-acquire to refresh)"
    # Report anything already touching the device. This does NOT prove exclusivity —
    # only the lock does — but a pre-existing process means someone bypassed the lock,
    # which is worth knowing loudly.
    if pgrep -f 'xcodebuild|XCTest' >/dev/null 2>&1; then
      echo "WARNING: xcodebuild/XCTest already running while the lock was free —" >&2
      echo "         someone is touching the device WITHOUT the lock. Investigate." >&2
      pgrep -fl 'xcodebuild|XCTest' >&2
    fi
    ;;
  release)
    OWNER="${2:-}"
    if [ -f "$LOCK" ]; then
      HOLDER=$(sed -n '1p' "$LOCK" 2>/dev/null)
      if [ "$HOLDER" != "$OWNER" ]; then
        echo "NOT RELEASING — lock is held by '$HOLDER', not by '$OWNER'." >&2
        exit 1
      fi
      rm -f "$LOCK"
      echo "RIG RELEASED by '$OWNER'"
    else
      echo "RIG was not locked."
    fi
    ;;
  status)
    if [ -f "$LOCK" ]; then
      HOLDER=$(sed -n '1p' "$LOCK" 2>/dev/null)
      AGE=$(( $(date +%s) - $(sed -n '4p' "$LOCK" 2>/dev/null || echo 0) ))
      if [ "$AGE" -lt "$LEASE_SECONDS" ]; then
        echo "LOCKED by '$HOLDER': $(sed -n '2p' "$LOCK") since $(sed -n '3p' "$LOCK") (${AGE}s ago)"
      else
        echo "EXPIRED lease from '$HOLDER': $(sed -n '2p' "$LOCK") (${AGE}s old)"
      fi
    else
      echo "FREE"
    fi
    ;;
  *)
    echo "usage: rig-lock.sh {acquire OWNER \"what\"|release OWNER|status}" >&2
    exit 2
    ;;
esac
