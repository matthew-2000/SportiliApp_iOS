# Multi-series weights

The shared additive format is `users/{code}/weightSessions/{canonicalExerciseKey}/{sessionId}`:

```json
{
  "schemaVersion": 1,
  "timestamp": 1790000000000,
  "sets": {
    "set_00": { "reps": 12, "weight": 30 },
    "set_01": { "reps": 10, "weight": 35.5 },
    "set_02": { "reps": 8, "weight": 40 },
    "set_03": { "reps": 6, "weight": 45 }
  }
}
```

- Timestamp is an integer in milliseconds, preserved on edits. A draft keeps the same ID on retry.
- Sets use contiguous, padded map keys, not Firebase numeric-key arrays. There are 1–20 sets; reps are integers 1–1000 and weights are finite numbers greater than zero.
- Use the existing cross-platform canonical exercise-name key, independent of legacy `exerciseData` aliases. Never move or rewrite legacy keys.
- `exerciseData/.../weightLogs` and notes remain unchanged. Released clients keep their single-weight behavior and do not show multi-series sessions. Old iOS cleanup of an `exerciseData` node cannot delete sessions.
- Updated clients merge both histories by date. Existing weights remain single weights, without invented reps. Charts contain only single weights; series comparisons and reuse require the same ordered reps.
- Auto-fill only plain prescriptions such as `12-10-8-6` and `4x10`. Composite/superset instructions require manual series entry.
- No backend rules, Auth, Storage or admin changes are needed. Compatibility tests use the recorded rules in a local emulator; no production migration or deployment is performed.

Run `python3 Tests/run_weight_session_tests.py`, `python3 Tests/run_s05_tests.py` and `python3 Tests/run_note_tests.py` for model, write-boundary and legacy regressions. Build the iOS target for SwiftUI verification. These tests do not replace on-device UI QA.
