# Summary

The change adds a save flow for user profile edits. The overall structure is clear, but the current implementation deletes the old profile record before the new one has been written successfully.

# Findings

## [severity: high] Non-transactional profile replacement can lose data

- **File:** `src/profile/save.ts` lines 42-61
- **What can go wrong:** If the delete succeeds and the insert fails, the user loses their existing profile.
- **Why vulnerable:** The code performs two separate database operations without a transaction or rollback path.
- **Impact:** User profile data can be permanently lost during a transient database failure.
- **Recommendation:** Wrap delete + insert in a transaction, or update the existing row in place.
- **Verification needed:** Confirm the database client supports transactions in this code path and add a failing test for insert failure after delete.

# Scorecard

- **Reviewed:** 1 items
- **Passing:** 0
- **Needs revision:** 1 (1 high)

# Verdict

VERDICT: REVISE — 0 passing, 1 need revision (1 high)
