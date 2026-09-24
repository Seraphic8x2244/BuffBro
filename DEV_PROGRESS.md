# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Development source head: `cab1587d79046271c4606aef49073a9970809591` (verified live `dev` head immediately before this documentation-only workflow migration).
- Stable baseline: `0.1.6` on `main` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`.
- Goal: Finish validating the reconciled 0.1.7b-equivalent Paladin implementation, with the unresolved GCD overlay as the current functional issue.
- Current scope boundary: Before any further implementation, discuss/review the XML-backed UI. After that, runtime-test the existing `0.1.7-dev` code. Do not treat this documentation migration as permission for runtime changes.

## Current Design / Development Contract

### Architecture / Ownership
- BuffBro owns its runtime state. PallyPower is an external compatibility/assignment source, not a state owner.
- Core state flow is: roster -> providers/capabilities -> assignments -> aura detection -> raw queue -> execution/preflight -> display/cast.
- Provider capability is intentionally generic for future Priest/Druid/Mage support; Paladin is the first implemented provider.
- UI consumes backend state. Hovering, clicking, or opening debug UI must not implicitly initialize, repair, or mutate backend readiness.
- Local provider readiness is explicit: `UNINITIALIZED`, `WAITING_SPELLBOOK`, `READY`, or `NOT_PROVIDER`.
- Keep the core primarily in `BuffBro.lua`; do not split it solely because the file is large. Extract compatibility/adapters only when there is a concrete architectural need.
- `BuffBro.xml` currently owns the frame/template-backed UI definition. Its value versus Lua-created UI must be discussed before changing that design.

### Invariants
- `PLAYER_LOGIN` performs the initial provider scan; `SPELLS_CHANGED` is the authoritative spellbook lifecycle signal.
- Provider spell data is published only when all discovered Blessing records have valid ClassicAPI spell IDs.
- Queue ordering keeps actionable/`READY` work first and expected failures after it with explicit reasons.
- A normal click does not attempt a blocked expected-failure job.
- Shift-click only forces the currently displayed blocked job; an immediate failure rotates it behind peers rather than stalling progression.
- PallyPower individual assignments always resolve to normal Blessings.
- Class assignments use AUTO on left-click: Greater when learned and the spell's actual required reagents are available, otherwise normal.
- Right-click explicitly casts the normal Blessing.
- Reagent handling remains data-driven through ClassicAPI spell reagent data; Symbol of Kings is not hardcoded.
- SavedVariables are for genuine user configuration such as mini-UI position, not derived runtime state.
- The TOC is the version source of truth.

### Protocol / Data Model
- PallyPower integration supplies assignment intent while BuffBro retains provider/queue/cast ownership.
- Individual PallyPower assignments map to normal Blessings; class assignments feed BuffBro's AUTO Greater/normal selection.
- Current reagent-aware AUTO logic uses `C_Spell.GetSpellReagents` plus `C_Item.GetItemCount`.
- Current GCD probe is spell ID `61304` through `C_Spell.GetSpellCooldown(61304)`.
- BuffBro currently declares `!!!ClassicAPI` as a required TOC dependency. This predates the current VanillaTemplate optional-extension policy and must be reviewed deliberately rather than silently changed.

### Active Decisions
- **Mandatory next discussion:** explain why BuffBro currently uses `BuffBro.xml`, what XML provides on WoW 1.12.1, and whether retaining XML is preferable to constructing the UI entirely from Lua. Discussion/review comes before further implementation; do not remove XML by implication.
- If the current GCD renderer still fails, do not make another speculative timing/render tweak. First inspect the exact runtime result of `C_Spell.GetSpellCooldown(61304)` immediately after a Blessing and separately prove the cooldown Model can visibly render a forced timer.
- Keep PallyPower protocol details isolated from the generic core; extract an adapter/module only when there is a concrete reason.
- Review the ClassicAPI requirement against the new rulebook separately from the current GCD test; do not opportunistically change dependency policy during this validation pass.

## Recent Relevant Commits
- `cab1587d79046271c4606aef49073a9970809591` - Complete BuffBro handoff for fresh-chat continuation.
- `718e12325de3e35d2a3ba456ae9db92dbb3c43c9` - Reconcile latest BuffBro 0.1.7b UI.
- `10785fc7f5e1b7719834a3b1fb67f829fb33111b` - Reconcile latest BuffBro 0.1.7b implementation.
- `c5512f160512f80a44a9b8a69e1b0e93f656a407` - Move active development to 0.1.7-dev.
- `ad8484f0d925d56e2e0ded3d0489b5b6837a73fd` - Adopt the predecessor development guide.

## Completed / User-Verified
- Core roster/provider/assignment/aura/queue pipeline works in live dungeon testing.
- Explicit provider readiness/startup works without the old hover-driven initialization dependency.
- PallyPower assignment compatibility works alongside PallyPower.
- Range and line-of-sight preflight behaviour has been user tested.
- Queue updates were observed to react faster than PallyPower during dungeon testing.
- Mini UI Ctrl-drag and saved position have been user tested.
- The summarized 0.1.5 dungeon test reported behaviour otherwise matching PallyPower with core casting/queue behaviour working.

## Implemented / Awaiting Runtime Test
- Current `dev` reconciles the latest 0.1.7b chat source into `0.1.7-dev`.
- Reagent-aware AUTO Greater/normal choice via `C_Spell.GetSpellReagents` + `C_Item.GetItemCount`.
- Left-click AUTO, right-click normal Blessing, and Shift only as the force modifier for the current blocked job.
- Four explicit 2px class-colour border textures replace the old gold `UI-Quickslot-Depress` overlay.
- GCD rendering now uses a Vanilla `Model` frame with `CooldownFrameTemplate`, sized 36x36, scaled to the 26x26 icon, and placed five frame levels above the cast button.
- The GCD source remains `C_Spell.GetSpellCooldown(61304)`, updated by `SPELL_UPDATE_COOLDOWN` and `ACTIONBAR_UPDATE_COOLDOWN`.
- The 0.1.7b-equivalent Model-frame GCD change has not been user tested.
- The four-edge class-colour border has not received explicit visual confirmation.

## Static / Automated Checks
- No automated test suite is documented for the addon.
- The 0.1.7b implementation/UI were reconciled into Git before this migration, but static inspection does not substitute for the pending in-game test.
- This workflow migration intentionally changes documentation only; runtime addon files are not part of the migration.

## Current Issues
- The GCD overlay did not display in tested implementations through the 0.1.7a chat build.
- Failed approaches already ruled out as sufficient on their own: legacy `GetSpellCooldown(spellbookIndex, BOOKTYPE_SPELL)` with the earlier widget; the legacy source with `CooldownFrame_SetTimer`; `C_Spell.GetSpellCooldown(queuedBlessingSpellID)`; and the dedicated 61304 GCD probe while retaining the earlier renderer.
- 0.1.7b changes the rendering primitive itself to `Model` + `CooldownFrameTemplate`; this is the next runtime question.
- Exact Git provenance for the prior 0.1.7a chat runtime test was not recorded in the predecessor progress file; do not invent an exact commit for that result.
- ClassicAPI is currently mandatory in the TOC and needs a deliberate policy review under the new rulebook, but that is not part of the immediate GCD validation.

## Testing

### Last Runtime Test
- Version/commit: chat build `0.1.7a`; exact Git commit not recorded in the predecessor handoff.
- Passed: existing core behaviour remained functional.
- Failed: GCD overlay still did not display.
- Not tested: current 0.1.7b-equivalent Model-frame cooldown renderer; class-colour border visual result; current reagent-aware click-mode delta as reconciled on `dev`.

### Next Runtime Test
1. First complete the XML-vs-Lua UI discussion/review; make no implementation change as part of that discussion unless explicitly agreed.
2. Install/test current `dev` (`0.1.7-dev`, functionally reconciled from 0.1.7b).
3. Cast a Blessing and check whether the GCD sweep is visibly drawn over the Blessing icon.
4. Confirm left-click AUTO uses Greater with the required reagent and falls back to normal without it.
5. Confirm right-click always uses the normal Blessing.
6. Confirm the four-edge class-colour border looks correct.
7. If the GCD still fails, inspect runtime `C_Spell.GetSpellCooldown(61304)` values and independently force a visible cooldown timer before changing implementation again.

## Planned / Next Work
- Complete the XML-backed UI design review before further implementation.
- Run the pending 0.1.7b-equivalent runtime validation.
- Move user-facing strings into `locales/enUS.lua` as a discrete migration task, not opportunistically.
- Decide whether the current debug UI is shipped functionality or should become dev-only `Debug.lua`.
- Review the intentional ClassicAPI requirement against the rulebook's optional-extension guidance.
- Broaden provider support beyond Paladins only after the Paladin path is solid.

## Deferred / Out of Scope
- Minimal client modes for assignment/buff communication and display.
- Future Priest/Druid/Mage provider support.
- Additional BuffBro-native communication beyond PallyPower compatibility.
- Potential keybind for the cast action.
- Splitting the main core Lua merely for file size.
- Additional abstractions/modules without a concrete architectural need.
- Stable release work on `main` until the user explicitly confirms a release-worthy version.

## Release / Promotion Notes
- Main-only or release-only content to preserve: `main` currently contains only `BuffBro.lua`, `BuffBro.toc`, `BuffBro.xml`, and `README.md`; the README is shared with `dev`. Release preparation must still compare trees rather than blindly replacing `main`.
- Known validation debt accepted for release: None currently accepted.
- External/runtime prerequisites: current dev and stable TOCs require `!!!ClassicAPI`; PallyPower is optional compatibility input, not a hard addon dependency.
- Stable baseline provenance: `main` is `0.1.6` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`. Prior documentation does not prove an exact runtime test of that stable tree, so do not overstate its validation provenance.

## Exact Next Step
Explain/review why BuffBro uses XML for its current UI and evaluate retaining XML versus Lua-created frames for this addon. Do not change implementation during that review unless explicitly agreed. After the discussion, runtime-test the existing 0.1.7b-equivalent `0.1.7-dev`, starting with the GCD overlay.
