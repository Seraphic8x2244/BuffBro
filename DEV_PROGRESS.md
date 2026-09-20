# Development Progress

> **FIRST THING NEXT CHAT:** Before making further code changes, explain why BuffBro currently uses `BuffBro.xml` for its UI, what XML is buying us on WoW 1.12.1, and whether keeping it is preferable to creating the UI entirely from Lua. This is a discussion/review item first, not permission to remove XML.

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Goal: Continue BuffBro from the latest 0.1.7b chat implementation under the VanillaTemplate development workflow, with the unresolved GCD overlay as the current functional issue.

## Recent Commits
- `718e123` - Reconcile latest BuffBro 0.1.7b UI.
- `10785fc` - Reconcile latest BuffBro 0.1.7b implementation.
- `043ce3c` - Add BuffBro development handoff.
- `c5512f1` - Move active development to 0.1.7-dev.
- `ad8484f` - Adopt modern addon development guide.
- `f56b68e` - Last pre-workflow main commit.

## Architecture / Decisions
- Target is WoW 1.12.1 / Lua 5.0.
- BuffBro owns its own runtime state. PallyPower is a compatibility/assignment source, not the core state owner.
- Main state pipeline: roster -> providers/capabilities -> assignments -> aura detection -> raw queue -> execution/preflight -> display/cast.
- Provider concept is intentionally generic for future Priest/Druid/Mage support; Paladin is the first implementation.
- UI consumes backend state. Hovering, clicking or opening debug must not secretly initialize or repair backend state.
- Local provider readiness is explicit: `UNINITIALIZED`, `WAITING_SPELLBOOK`, `READY`, `NOT_PROVIDER`.
- `PLAYER_LOGIN` performs the initial provider scan; `SPELLS_CHANGED` is the authoritative spellbook lifecycle signal.
- Provider spell data is published only when all discovered Blessing records have valid ClassicAPI spell IDs.
- Queue ordering is actionable/READY work first, expected failures after it with reasons.
- Normal click does not attempt a blocked expected-failure job. Shift-click forces the currently displayed blocked job; an immediate failure rotates it behind its peers rather than stalling progression.
- PallyPower individual assignments always resolve to normal Blessings.
- Class assignments use AUTO on left-click: Greater when learned and its actual spell reagents are available, otherwise normal.
- Right-click explicitly casts the normal Blessing.
- Reagent handling is data-driven through ClassicAPI spell reagent data; Symbol of Kings is not hardcoded.
- SavedVariables are for genuine user configuration such as mini-UI position, not derived runtime state.
- TOC metadata is the version source of truth.
- Keep the core primarily in `BuffBro.lua`; do not split files merely because it becomes large. Third-party compatibility such as PallyPower may become an adapter/module when there is a concrete need.

## Completed / Verified
- Core roster/provider/assignment/aura/queue pipeline works in live dungeon testing.
- Explicit provider readiness/startup works without the old hover-driven initialization dependency.
- PallyPower assignment compatibility works alongside PallyPower.
- Range and line-of-sight preflight behaviour has been user tested.
- Queue updates were observed to react faster than PallyPower during dungeon testing.
- Mini UI Ctrl-drag and saved position have been user tested.
- Summarized 0.1.5 dungeon test: behaviour otherwise matched PallyPower and core casting/queue behaviour was working.

## Implemented / Awaiting Test
- Latest 0.1.7b chat source is now reconciled into `dev`.
- Reagent-aware AUTO Greater/normal choice using `C_Spell.GetSpellReagents` + `C_Item.GetItemCount`.
- Right-click normal Blessing; left-click AUTO; Shift modifies either mode only to force the current blocked job.
- Four explicit 2px class-colour border textures replace the old gold `UI-Quickslot-Depress` overlay.
- GCD rendering now creates a Vanilla `Model` frame with `CooldownFrameTemplate`, sized 36x36, scaled to the 26x26 icon and placed five frame levels above the cast button.
- Current GCD source is `C_Spell.GetSpellCooldown(61304)`, driven by `SPELL_UPDATE_COOLDOWN` and `ACTIONBAR_UPDATE_COOLDOWN`.
- The 0.1.7b GCD Model-frame change has not yet been user tested.

## Current Issues
- GCD overlay has not displayed in any tested implementation through 0.1.7a.
- Previous failed GCD attempts:
  1. Vanilla `GetSpellCooldown(spellbookIndex, BOOKTYPE_SPELL)` with the earlier cooldown widget.
  2. Same legacy cooldown source with `CooldownFrame_SetTimer`.
  3. `C_Spell.GetSpellCooldown(queuedBlessingSpellID)`.
  4. 0.1.7a: dedicated spell ID 61304 as the GCD probe, still using the previous rendering setup.
- 0.1.7b changes the rendering primitive itself to a Vanilla `Model` + `CooldownFrameTemplate`; this is the next thing to test.
- If 0.1.7b still shows no sweep, do not blindly tweak again. Verify the exact ClassicAPI return from `C_Spell.GetSpellCooldown(61304)` immediately after a Blessing and separately prove the cooldown Model can visibly render a forced timer.
- BuffBro currently declares ClassicAPI as a required dependency. This predates the VanillaTemplate optional-extension policy and should be reviewed deliberately rather than silently changed.

## Testing

### Last Test
- Version: chat build `0.1.7a`.
- Passed: existing core behaviour remained functional.
- Failed: GCD overlay still did not display.
- Not tested: `0.1.7b` Model-frame cooldown rendering.
- Class-colour four-edge border has not received explicit visual confirmation.

### Next Test
1. First discuss why the UI is XML-backed and whether that remains the right design.
2. Install/test current `dev` (`0.1.7-dev`, functionally reconciled from 0.1.7b).
3. Cast a Blessing and check whether the GCD sweep is now visibly drawn over the blessing icon.
4. Confirm left-click AUTO uses Greater with reagent and falls back to normal without reagent.
5. Confirm right-click always uses normal Blessing.
6. Confirm the four-edge class-colour border looks correct.
7. If GCD still fails, inspect runtime `C_Spell.GetSpellCooldown(61304)` values and independently force a visible cooldown timer before changing implementation again.

## Planned / To-do
- Explain/review the reason for using XML before further implementation work.
- Audit BuffBro against `DEV_GUIDE.md` without opportunistic refactoring.
- Move user-facing strings into `locales/enUS.lua` as a discrete migration task.
- Decide whether the current debug UI is shipped functionality or should become dev-only `Debug.lua`.
- Review the intentional ClassicAPI requirement against the template's optional-extension rule.
- Keep PallyPower protocol details isolated from the generic core; extract an adapter only when there is a concrete reason.
- Broaden provider support beyond Paladins only after the Paladin path is solid.

## Ideas / Backlog
- Minimal client modes for assignment/buff communication and display.
- Future Priest/Druid/Mage provider support.
- Additional BuffBro-native communication beyond PallyPower compatibility.
- Potential keybind for the cast action.

## Deferred
- Splitting the main core Lua merely for file size.
- Additional abstractions/modules without a concrete architectural need.
- Stable release work on `main` until the user explicitly confirms a release-worthy version.

## Exact Next Step
Explain why BuffBro uses XML for its current UI and evaluate XML vs Lua-created frames for this addon. After that discussion, run the 0.1.7b-equivalent `dev` in-game test, starting with the GCD overlay.
