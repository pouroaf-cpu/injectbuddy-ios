# TEST-QUEUE

One simulator, one runner. **No agent other than the test-runner touches the device.**

Every other agent, when its change is ready, appends an entry below by **shell append**
(`cat >> docs/TEST-QUEUE.md <<'EOF' ... EOF`) — never by rewriting the whole file, because
several agents append concurrently.

The runner takes entries in order, **batches everything sharing a build** (the build is the cost,
not the run), executes, writes the result into the entry, and reports back to the filing agent.

Runner rules:
- Set **and reset** `content_size` in the same command, every time. A left-over large-text setting
  has already been misread once as "the app broke".
- `xcodegen generate` runs **only** when a file is added to or removed from the project definition.
- Re-run only what decides a board item, and only once.

## Entry format

```
### Q<n> — <title>            [filed by: <agent>] [status: QUEUED|RUNNING|PASS|FAIL]
- Changed: <what changed, files>
- Must answer: <the question the run decides>
- Invocation: <exact command>
- Report to: <agent>
- Result: <filled in by runner>
```

## Queue

<!-- append entries below this line -->
