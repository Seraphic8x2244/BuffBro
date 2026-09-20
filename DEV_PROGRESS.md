# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Goal: Bring BuffBro under the VanillaTemplate development workflow, then resume the unresolved GCD overlay work without disturbing the verified backend.

## Recent Commits
- `c5512f1` - Move active development to 0.1.7-dev.
- `ad8484f` - Adopt modern addon development guide.
- `f56b68e` - Enhance README with detailed addon description (pre-workflow `main`).
- `05059f4` - Early addon build/WIP (pre-workflow `main`).

## Completed / Verified
- Core roster/provider/assignment/aura/queue pipeline works in live dungeon testing.
- Explicit local-provider readiness lifecycle works without hover-driven initialization.
- PallyPower assignment compatibility works alongside PallyPower.
- Range and line-of-sight preflight behaviour has been user tested.
- Queue updates were observed to react faster than PallyPower during dungeon testing.
- Mini UI can be Ctrl-dragged and its position persists through `BuffBroDB`.

## Implemented / Awaiting Test
- Chat build `0.1.7b` (not yet committed to this repo) adds reagent-aware Greater Blessing selection, right-click normal Blessing casting, and a Vanilla `Model`/`CooldownFrameTemplate` GCD overlay attempt.
- Four-edge class-colour cast-button border from the later chat builds still needs explicit visual confirmation.
- The repository's current code is still the older `main` codebase inherited at branch creation; later chat-build changes must be reconciled deliberately before testing from `dev`.

## Current Issues
- GCD overlay has not displayed in any tested implementation so far.
- Repository `main` was at `0.1.6` and lagged behind the latest chat build when the modern workflow migration began.
- BuffBro currently declares ClassicAPI as a required dependency. This predates the VanillaTemplate extension policy and should be reviewed deliberately rather than changed during workflow setup.

## Testing

### Last Test
- Version/commit: chat build `0.1.7a`.
- Passed: existing core behaviour remained functional.
- Failed: GCD overlay still did not display.
- Not tested: chat build `0.1.7b` Vanilla cooldown-model rendering change.

### Next Test
- Do not test the current `dev` branch as if it contains `0.1.7b`.
- First reconcile the `0.1.7b` chat build into `dev`, inspect the exact diff, then test the GCD overlay and the other carried-forward `0.1.7` behaviours in game.

## Planned / To-do
- Reconcile the latest `0.1.7b` chat build with the new `dev` branch and commit it as `0.1.7-dev`.
- Audit BuffBro against `DEV_GUIDE.md` without opportunistic refactoring.
- Move user-facing strings into `locales/enUS.lua` as a discrete migration task.
- Decide whether the current debug UI is shipped functionality or should become dev-only `Debug.lua`.
- Review the intentional ClassicAPI requirement against the template's optional-extension rule.
- Continue PallyPower compatibility through a clean adapter/module boundary when there is a concrete need to extract it.
- Continue broader provider support beyond Paladins only after the Paladin path is solid.

## Ideas / Backlog
- Minimal client modes for assignment/buff communication and display.
- Future Priest/Druid/Mage provider support.
- Keep core provider/assignment concepts generic while isolating third-party protocol details.

## Deferred
- Splitting the main core Lua merely for file size.
- Additional abstractions/modules without a concrete architectural need.
- Stable release work on `main` until the user explicitly confirms a release-worthy version.

## Exact Next Step
Reconcile the exact `0.1.7b` chat-build files against `dev`, preserve the newly adopted workflow files/versioning, inspect the resulting diff, and commit the functional changes before the next in-game GCD test.
