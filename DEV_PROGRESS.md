# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`
- Version: `0.1.7-dev`
- Development source head: `61609228f00b21a3fa8564afb34adc7d911c3161` (verified live `dev` head immediately before recording the Lua-only UI migration decision).
- Stable baseline: `0.1.6` on `main` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`.
- Goal: Convert BuffBro's remaining XML-defined UI to Lua-only construction while preserving the existing runtime behaviour and single-file runtime architecture.
- Current scope boundary: The next implementation is the XML-to-Lua UI migration only. Do not redesign the UI, change backend state ownership, fix the unresolved GCD behaviour, alter ClassicAPI/PallyPower semantics, or introduce new runtime modules as part of this migration.

## Current Design / Development Contract

### Architecture / Ownership
- BuffBro owns its runtime state. PallyPower is an external compatibility/assignment source, not a state owner.
- Core state flow is: roster -> providers/capabilities -> assignments -> aura detection -> raw queue -> execution/preflight -> display/cast.
- Provider capability is intentionally generic for future Priest/Druid/Mage support; Paladin is the first implemented provider.
- UI consumes backend state. Hovering, clicking, or opening debug UI must not implicitly initialize, repair, or mutate backend readiness.
- Local provider readiness is explicit: `UNINITIALIZED`, `WAITING_SPELLBOOK`, `READY`, or `NOT_PROVIDER`.
- BuffBro remains a single-runtime-Lua addon: `BuffBro.lua` is the runtime implementation file. Do not introduce `UI.lua` or another runtime module merely to perform this migration.
- The XML review is resolved: `BuffBro.xml` is an early-prototype structure and will be removed. Its event frame, mini UI, debug UI, textures, font strings, buttons, scroll frame, cooldown anchor, and script wiring will be recreated programmatically in `BuffBro.lua`.
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
- **Lua-only UI decision:** migrate the current XML-defined UI into `BuffBro.lua`, then remove `BuffBro.xml` and its TOC loader entry once every XML-owned object has a Lua equivalent.
- The migration is construction/ownership work, not a visual redesign or behavioural rewrite. Preserve current dimensions, anchors, Blizzard template inheritance, drag behaviour, click semantics, tooltips, debug behaviour, status display, class-colour borders, event registration, and saved mini-frame position behaviour unless an explicit defect requires otherwise.
- Preserve the current backend architecture unchanged: roster/provider/assignment/aura/queue/executor state and lifecycle must not move into or become dependent on UI creation.
- Do not attempt to fix or redesign the unresolved GCD during the XML removal. Recreate the current cooldown anchor/renderer relationship faithfully first; GCD diagnosis remains a separate runtime task after migration parity.
- Do not add `UI.lua` or another runtime module. The rulebook's single-main-Lua default remains the project decision.
- If the GCD renderer still fails after migration, do not make another speculative timing/render tweak. First inspect the exact runtime result of `C_Spell.GetSpellCooldown(61304)` immediately after a Blessing and separately prove the cooldown Model can visibly render a forced timer.
- Keep PallyPower protocol details isolated from the generic core; extract an adapter/module only when there is a concrete reason.
- Review the ClassicAPI requirement against the rulebook separately; do not opportunistically change dependency policy during the UI migration.

## Recent Relevant Commits
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
- Current `dev` still contains the XML-backed 0.1.7b-equivalent UI; the Lua-only migration is the next implementation and has not started yet.
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
- `BuffBro.xml` is now intentionally scheduled for removal in favour of Lua-only UI construction; this is an architectural cleanup while the addon is still early, not a response to a known XML correctness failure.
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
After the Lua-only migration and static parity review:
1. Confirm a clean addon load with no Lua/XML loader errors and no `BuffBro.xml` TOC entry.
2. Confirm the mini frame has the same layout, dimensions, anchors, icon, status button, and class-colour border presentation.
3. Confirm Ctrl-drag, saved position, and position restore still work.
4. Confirm the menu/debug window opens and its tabs, refresh action, scrolling, close/drag behaviour, and rendered state still work.
5. Confirm left-click AUTO, right-click normal Blessing, Shift-force behaviour, tooltips, and expected-failure status behaviour are unchanged.
6. Confirm provider/queue behaviour remains inherited from the previously verified backend baseline.
7. Then test whether the existing GCD sweep renders. If it still fails, inspect runtime `C_Spell.GetSpellCooldown(61304)` values and independently force a visible cooldown timer before changing the GCD implementation.

## Planned / Next Work
- Recreate every `BuffBro.xml`-owned frame/region/script in `BuffBro.lua` with behaviour and visual parity.
- Keep BuffBro as a single-runtime-Lua addon; do not create `UI.lua` or another runtime module for this migration.
- Remove `BuffBro.xml` and its TOC loader entry only after all XML-owned objects have Lua equivalents.
- Statically compare the Lua-created hierarchy/wiring against the current XML before runtime testing, including event frame wiring, debug controls, mini UI, cooldown anchor, templates, and script handlers.
- Search for XML-only callback globals and obsolete named-frame globals after conversion; remove only those no longer required.
- Run the Lua-only parity runtime test before resuming GCD diagnosis.
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
Convert the existing XML-defined UI to behaviour-equivalent Lua construction inside `BuffBro.lua` without changing backend/runtime semantics or attempting to fix the unresolved GCD issue. Preserve the current frame hierarchy, appearance, templates, interactions, debug behaviour, event wiring, and saved position behaviour; remove `BuffBro.xml` and its TOC entry only after every XML-owned object has a Lua equivalent. Then perform a static parity review before the next in-game test.
