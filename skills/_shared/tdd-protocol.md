# TDD Protocol for SDD

## The Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

If you write code before the test: delete it. No exceptions. Cannot keep as reference, cannot adapt it. Delete means delete.

## The RED-GREEN-REFACTOR Cycle

### 1. RED -- Write Failing Test
- One minimal test showing desired behavior
- Clear name describing the behavior being tested
- Real code preferred (mocks only if unavoidable)
- One behavior per test
- Reference the spec scenario this test derives from

### 2. Verify RED (MANDATORY -- never skip)
- Run the test suite
- Confirm the test FAILS (not errors -- fails)
- The failure message should be meaningful
- If the test passes: investigate. Either the test is wrong or the feature already exists.

### 3. GREEN -- Write Minimal Code
- Write the simplest code that makes the test pass
- Do NOT add features, refactor other code, or "improve"
- YAGNI strictly enforced -- only what the test demands

### 4. Verify GREEN (MANDATORY -- never skip)
- Run the test suite
- The new test MUST pass
- ALL existing tests MUST still pass
- If the new test fails: fix the implementation, not the test
- If an existing test breaks: you introduced a regression -- fix before proceeding

### 5. REFACTOR
- Only after green
- Remove duplication, improve names, extract helpers
- Keep ALL tests green throughout
- Run tests after each refactor step
- Do NOT add behavior during refactoring

### 6. COMMIT
- Commit the test + implementation together
- Commit message references the spec scenario

## Verification Steps 2 and 4 Are Non-Negotiable

These steps exist to catch:
- Tests that pass for the wrong reason
- Tests that test nothing
- Tests that are tautological
- Implementations that break existing behavior

Skipping verification is a protocol violation.

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | What to Do Instead |
|---|---|---|
| Write code first, test after | Tests become confirmation bias | Delete the code, write the test first |
| Mock everything | Tests pass but production breaks | Use real dependencies where possible |
| Test the mock, not the behavior | Green tests, broken features | Test observable behavior |
| Skip verify-RED | Test might pass for wrong reason | Always run and verify failure |
| Add "just one more thing" in GREEN | Feature creep, untested code | One test, one behavior, one commit |
| Refactor before green | Changing too many things at once | Get green first, then clean up |

## Debugging Integration

When a test fails unexpectedly during the GREEN step:
1. Do NOT immediately add more code
2. Re-read the test -- is it testing what you think?
3. Re-read the implementation -- is it doing what you think?
4. If the failure is genuinely unexpected, enter the debugging protocol (sdd-debug)
