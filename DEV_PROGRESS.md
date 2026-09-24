# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Development source head: `7ee4868e88b2cc77b68a5906068fedee5360c8d0` (Lua-only UI migration implementation; verified live `dev` head before this status-only update).
- Stable baseline: `0.1.6` on `main` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`.
- Goal: Runtime-validate the Lua-only UI migration while preserving existing behaviour; resume the separate GCD investigation only after UI parity is confirmed.
- Current scope boundary: The XML-to-Lua implementation and static parity review are complete. The next action is runtime parity testing only. Do not redesign the UI, change backend state ownership, alter ClassicAPI/PallyPower semantics, or modify the unresolved GCD implementation before that parity run.

## Current Design / Development Contract

### Architecture / Ownership
- BuffBro owns its runtime state. PallyPower is an external compatibility/assignment source, not a state owner.
- Core state flow is: roster -> providers/capabilities -> assignments -> aura detection -> raw queue -> execution/preflight -> display/cast.
- Provider capability is intentionally generic for future Priest/Druid/Mage support; Paladin is the first implemented provider.
- UI consumes backend state. Hovering, clicking, or opening debug UI must not implicitly initialize, repair, or mutate backend readiness.
- Local provider readiness is explicit: `UNINITIALIZED`, `WAITING_SPELLBOOK`, `READY`, or `NOT_PROVIDER`.
- BuffBro remains a single-runtime-Lua addon: `BuffBro.lua` is the runtime implementation file. Do not introduce `UI.lua` or another runtime module merely to perform this migration.
- The XML review is resolved and implemented: `BuffBro.xml` has been removed. Its event frame, mini UI, debug UI, textures, font strings, buttons, scroll frame, cooldown anchor, and script wiring are now constructed programmatically in `BuffBro.lua`.
- Lua-created UI should have explicit ownership under BuffBro's UI structures where practical; use named globals only where a Blizzard template/API genuinely requires them or where temporary parity wiring makes migration safer.
- Dynamic frame construction is an implementation detail only; authoritative addon state remains in the existing backend pipeline.

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
- **Lua-only UI decision:** implemented at `7ee4868e88b2cc77b68a5906068fedee5360c8d0`. `BuffBro.lua` now constructs the former XML UI and the TOC loads only `BuffBro.lua`; `BuffBro.xml` is deleted.
- The migration is construction/ownership work, not a visual redesign or behavioural rewrite. Current dimensions, anchors, Blizzard template inheritance, drag behaviour, click semantics, tooltips, debug behaviour, status display, class-colour borders, event registration, and saved mini-frame position behaviour were retained for runtime parity testing.
- Existing named UI globals and callback globals were retained where current runtime code or parity wiring still references them; no callback was removed merely because XML was removed.
- Preserve the current backend architecture unchanged: roster/provider/assignment/aura/queue/executor state and lifecycle must not move into or become dependent on UI creation.
- Do not attempt to fix or redesign the unresolved GCD during the XML removal. Recreate the current cooldown anchor/renderer relationship faithfully first; GCD diagnosis remains a separate runtime task after migration parity.
- Do not add `UI.lua` or another runtime module. The rulebook's single-main-Lua default remains the project decision.
- If the GCD renderer still fails after migration, do not make another speculative timing/render tweak. First inspect the exact runtime result of `C_Spell.GetSpellCooldown(61304)` immediately after a Blessing and separately prove the cooldown Model can visibly render a forced timer.
- Keep PallyPower protocol details isolated from the generic core; extract an adapter/module only when there is a concrete reason.
- Review the ClassicAPI requirement against the rulebook separately; do not opportunistically change dependency policy during the UI migration.

## Recent Relevant Commits
- `7ee4868e88b2cc77b68a5906068fedee5360c8d0` - Migrate BuffBro UI construction to Lua.
- `61609228f00b21a3fa8564afb34adc7d911c3161` - Migrate BuffBro to VanillaTemplate workflow.
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
- Lua-only UI migration is implemented at `7ee4868e88b2cc77b68a5906068fedee5360c8d0`: all former XML-owned frames/regions/scripts are constructed inside `BuffBro.lua`, `BuffBro.xml` is deleted, and its TOC entry is removed.
- The Lua-only construction recreates the event frame, debug frame and controls, scroll child/text, mini frame, menu/cast/status controls, four-edge class-colour border, and cooldown anchor without changing the existing backend callbacks.
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
- Static parity review completed against the pre-migration `BuffBro.xml`: all 24 XML-named objects have Lua construction equivalents; the documented dimensions, anchors, templates, backdrop, texture layers, scroll child, click registration, drag wiring, tooltip/status handlers, debug actions, event wiring, and cooldown anchor are represented.
- The pre-existing `BuffBro.lua` runtime/backend source is preserved byte-for-byte apart from the inserted UI-construction section and explicit Lua bootstrap.
- `BuffBro.toc` now has one runtime entry, `BuffBro.lua`; there is no `BuffBro.xml` or `UI.lua` runtime entry.
- The new `BB.CreateUI()` function adds five function-local variables and no new top-level locals, avoiding pressure on Lua 5.0's top-level local-variable limit.
- The inserted UI path uses only established Vanilla-era frame methods/templates already represented by the XML design; no backend, PallyPower, ClassicAPI, reagent, queue, executor, or GCD semantics were changed.
- A Lua 5.0 compiler was not available in the execution environment, so this checkpoint is statically reviewed but not compiler- or in-game-validated.

## Current Issues
- The Lua-only UI migration has not yet been runtime-tested; clean load, visual parity, interaction parity, saved-position behaviour, and debug-window behaviour remain validation debt.
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
Runtime source: `7ee4868e88b2cc77b68a5906068fedee5360c8d0` (`0.1.7-dev`; any following status-only commit does not change runtime files).
1. Confirm a clean addon load with no Lua/XML loader errors and no `BuffBro.xml` TOC entry.
2. Confirm the mini frame has the same layout, dimensions, anchors, icon, status button, and class-colour border presentation.
3. Confirm Ctrl-drag, saved position, and position restore still work.
4. Confirm the menu/debug window opens and its tabs, refresh action, scrolling, close/drag behaviour, and rendered state still work.
5. Confirm left-click AUTO, right-click normal Blessing, Shift-force behaviour, tooltips, and expected-failure status behaviour are unchanged.
6. Confirm provider/queue behaviour remains inherited from the previously verified backend baseline.
7. Then test whether the existing GCD sweep renders. If it still fails, inspect runtime `C_Spell.GetSpellCooldown(61304)` values and independently force a visible cooldown timer before changing the GCD implementation.

## Planned / Next Work
- Run the Lua-only parity runtime test before resuming GCD diagnosis.
- If parity passes, record the exact tested commit/version and then test the existing GCD sweep without changing it first.
- If the GCD still fails after parity is confirmed, inspect runtime `C_Spell.GetSpellCooldown(61304)` values and independently force a visible cooldown timer before changing the GCD implementation.
- Keep BuffBro as a single-runtime-Lua addon; do not create `UI.lua` or another runtime module without a concrete architectural need.
- Move user-facing strings into `locales/enUS.lua` as a discrete later migration task, not opportunistically.
- Decide whether the current debug UI is shipped functionality or should become dev-only `Debug.lua`.
- Review the intentional ClassicAPI requirement against the rulebook's optional-extension guidance.
- Broaden provider support beyond Paladins only after the Paladin path is solid.

## Deferred / Out of Scope
- Splitting UI construction into `UI.lua` or another runtime module without a concrete architectural need.
- Minimal client modes for assignment/buff communication and display.
- Future Priest/Druid/Mage provider support.
- Additional BuffBro-native communication beyond PallyPower compatibility.
- Potential keybind for the cast action.
- Splitting the main core Lua merely for file size.
- Additional abstractions/modules without a concrete architectural need.
- Stable release work on `main` until the user explicitly confirms a release-worthy version.

## Release / Promotion Notes
- Main-only or release-only content to preserve: `main` currently contains only `BuffBro.lua`, `BuffBro.toc`, `BuffBro.xml`, and `README.md`; the README is shared with `dev`. The planned dev migration intentionally removes `BuffBro.xml`, so a future promotion must compare trees and remove the stable XML loader/file deliberately rather than assuming byte-for-byte parity.
- Known validation debt accepted for release: None currently accepted.
- External/runtime prerequisites: current dev and stable TOCs require `!!!ClassicAPI`; PallyPower is optional compatibility input, not a hard addon dependency.
- Stable baseline provenance: `main` is `0.1.6` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`. Prior documentation does not prove an exact runtime test of that stable tree, so do not overstate its validation provenance.

## Exact Next Step
Runtime-test the Lua-only `0.1.7-dev` UI from runtime source commit `7ee4868e88b2cc77b68a5906068fedee5360c8d0`: confirm clean load, mini-frame visual/layout parity, Ctrl-drag and saved-position restore, debug-window tabs/refresh/scroll/close/drag behaviour, cast/status tooltips and click semantics, and unchanged provider/queue behaviour. Only after that parity pass, test the existing GCD sweep; do not change the GCD implementation or backend semantics before this runtime validation.
