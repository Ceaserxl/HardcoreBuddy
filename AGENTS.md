# Repository instructions

## Commit completed changes

- After completing a requested task, run the appropriate validation, review the
  diff, and commit the task's changes before giving the final response.
- Do not wait for a separate reminder or confirmation to commit.
- Stage only files belonging to the task; preserve unrelated working changes.
- Use a concise commit message describing the completed change, and include the
  commit hash in the final response.
- Push or publish only when the user has authorized it.

## No in-game interaction with Zygor

- HardcoreBuddy must operate independently of Zygor in-game. Do not access
  Zygor globals, APIs, settings or SavedVariables; hook or modify its functions
  or frames; load it; or add it as a runtime dependency.
- Read-only source inspection and comparison tests outside WoW are allowed.
  Keep that tooling out of the addon runtime.
