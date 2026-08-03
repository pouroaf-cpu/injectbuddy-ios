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
#   scripts/rig-lock.sh acquire "what I am doing"   # exits 1 if held, naming the holder
#   scripts/rig-lock.sh release
#   scripts/rig-lock.sh status
#
# ALWAYS pair acquire with a trap so a crash cannot leave the rig locked:
#   scripts/rig-lock.sh acquire "shear re-measure" || exit 1
#   trap 'scripts/rig-lock.sh release' EXIT

set -uo pipefail

LOCK="${TMPDIR:-/tmp}/injectbuddy-rig.lock"

case "${1:-status}" in
  acquire)
    WHAT="${2:-unnamed task}"
    if [ -f "$LOCK" ]; then
      HOLDER_PID=$(sed -n '1p' "$LOCK" 2>/dev/null)
      HOLDER_WHAT=$(sed -n '2p' "$LOCK" 2>/dev/null)
      HOLDER_WHEN=$(sed -n '3p' "$LOCK" 2>/dev/null)
      if [ -n "$HOLDER_PID" ] && kill -0 "$HOLDER_PID" 2>/dev/null; then
        echo "RIG LOCKED — refusing to start." >&2
        echo "  held by PID $HOLDER_PID: $HOLDER_WHAT" >&2
        echo "  since $HOLDER_WHEN" >&2
        echo "  Do NOT proceed and do NOT kill it. Report this and wait." >&2
        exit 1
      fi
      # Holder is gone — a crash left this behind. Say so; a silent steal is how a
      # stale lock becomes invisible.
      echo "STALE LOCK from dead PID ${HOLDER_PID:-?} ($HOLDER_WHAT, $HOLDER_WHEN) — reclaiming." >&2
      rm -f "$LOCK"
    fi
    # RECORD THE CALLER'S PID ($PPID), NOT OUR OWN.
    # This script exits the instant `acquire` returns, so a lock naming $$ is stale
    # before the caller has run anything — it would provide NO mutual exclusion at all.
    # Found by self-test on 2026-08-03: a second acquire happily reclaimed a "stale"
    # lock two seconds old. That is why a check is made to fail before it is trusted.
    { echo "$PPID"; echo "$WHAT"; date '+%Y-%m-%d %H:%M:%S'; } > "$LOCK"
    echo "RIG ACQUIRED by PID $PPID — $WHAT"
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
    if [ -f "$LOCK" ]; then
      HOLDER_PID=$(sed -n '1p' "$LOCK" 2>/dev/null)
      if [ "$HOLDER_PID" != "$PPID" ]; then
        echo "NOT RELEASING — lock is held by PID $HOLDER_PID, not by me ($PPID)." >&2
        exit 1
      fi
      rm -f "$LOCK"
      echo "RIG RELEASED by PID $PPID"
    else
      echo "RIG was not locked."
    fi
    ;;
  status)
    if [ -f "$LOCK" ]; then
      HOLDER_PID=$(sed -n '1p' "$LOCK" 2>/dev/null)
      if kill -0 "$HOLDER_PID" 2>/dev/null; then
        echo "LOCKED by PID $HOLDER_PID: $(sed -n '2p' "$LOCK") since $(sed -n '3p' "$LOCK")"
      else
        echo "STALE lock from dead PID $HOLDER_PID: $(sed -n '2p' "$LOCK")"
      fi
    else
      echo "FREE"
    fi
    ;;
  *)
    echo "usage: rig-lock.sh {acquire \"what\"|release|status}" >&2
    exit 2
    ;;
esac
