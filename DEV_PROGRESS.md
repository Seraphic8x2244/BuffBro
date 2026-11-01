# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Latest audited `dev` branch head before this status-only update: `f2d4dfb2f9146d7d330857d0a74523a2c2fd306d` (2026-11-01); runtime source remains `7ee4868e88b2cc77b68a5906068fedee5360c8d0`.
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

### Product Direction — BuffBro-Native Coordination (clarified 2026-11-01)
- BuffBro is a ground-up, class-extensible raid-buff addon, **not** a PallyPower replacement constrained to PallyPower's buffing/assignment workflow. Stop treating PallyPower feature parity or its class-only one-Blessing-per-cell scheme as the product specification.
- PallyPower is optional compatibility input and a visual reference only. BuffBro owns assignment intent, provider/capability state, aura detection, execution and eventual BuffBro-native coordination protocol.
- The user explicitly wants to reuse the **redesigned PallyPowerVanilla assignment window's look** (especially class-coloured connectors and visibility presentation) while redesigning assignment interaction, targeting, scheduling and player/provider workflows independently.
- A visual reference does not authorize copying PPV's fixed 12-Paladin x 14-column grid, legacy storage/globals, cycling semantics, special-button visibility semantics, or communication/control authority rules.
- This is a future UI/product direction, **not** permission to interrupt the outstanding 0.1.7-dev Lua-only UI runtime parity and GCD gate. Before code work, define a BuffBro-native assignment data contract and UI projection; no code or version change occurred in this audit.

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
- Compiler check corrected: the environment provides `texlua` with Lua 5.3. The inserted Lua-only UI construction/bootstrap parses successfully with `loadfile`, and this compiler also enforces the 200-local-per-function limit. It is not an exact Lua 5.0 compiler, so target-client runtime validation is still required.

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

## Read-Only Comparison Audit — 2026-11-01
- Audit branch/head: `dev` at `4772b7c06c7d88fe427294bcff83a52067692612`; addon version remains `0.1.7-dev`. `main` remains the `0.1.6` baseline at `f56b68eb4b7be5110ab680452acd7ed7b392575c`. Latest commits are documentation/rulebook synchronization on 2026-09-26 and 2026-09-25, after the runtime-changing Lua-only migration at `7ee4868e88b2cc77b68a5906068fedee5360c8d0`.
- Verified implemented from code and earlier user-tested reports: Paladin-only roster/provider/capability scan, PallyPower receive/import adapter, aura observation, raw and execution queues, smart blocked-work rotation, spell-specific range and LoS preflight, AUTO Greater/normal selection, reagent inspection, one-button cast, mini/debug UI construction. Earlier dungeon test results belong to the tested baseline and do not establish current migrated-UI parity.
- Major feature-parity gaps vs 1.12 PallyPower: no BuffBro-owned editable raid-assignment grid; no outbound BuffBro-native synchronization or PP SELF/ASSIGN broadcasting; no replacement coordination model; no near-expiry countdown/rebuff logic (the queue currently considers a matching aura 'present' without remaining-time threshold); no other class providers; no documented 40-player raid/performance test or automated test suite. The first implementation is a capable PallyPower-assisted Paladin cast client, not yet a standalone coordinator.
- Code audit candidates requiring test/fix after the current UI parity checkpoint: `BB.BuildExecutionQueue` reads `castMode` without defining/passing it and `BB.ExecuteNext` invokes preflight without its chosen mode; right-click NORMAL preflight may use AUTO's Greater spell range. The fallback question-mark texture paths in `UpdateMiniUI` contain single backslashes and should be checked against Lua string escape rules. The PLPWR ASSIGN/MASSIGN receiver appears to lack the original reference addon's leader/control validation. PallyPower individual overrides are imported from local globals only. Hardcoded English aura names prevent verified localization parity.
- Untested/deferred: no current runtime validation of `0.1.7-dev` Lua-only frame construction; GCD Model timer remains unresolved; no stress, reconnect, cross-client protocol, secure-casting or localization matrix run. These findings are static audit candidates, not confirmed in-game failures.
- Scope unchanged: this was a read-only code review plus status documentation update, not a runtime code change or a request to broaden provider implementation. Continue the previously agreed gate before changes to GCD, assignment protocol, or new providers.
- Exact next step: runtime-test the `0.1.7-dev` Lua-only UI at runtime-source commit `7ee4868e88b2cc77b68a5906068fedee5360c8d0` using the checklist below; then isolate GCD timer data versus rendering. Only after this gate plan independent assignment UI/protocol and impending-expiry rebuffs.

## PPV Window Visual Audit — 2026-11-01 (status-only)
- Sources: `Seraphic8x2244/PallyPowerVanilla` dev head `d5c4383fb56680844490248b2c78d19d1188e3e4`, `1.11.70-dev`, `PallyPowerUI.lua` (notably lines 21-65, 160-246, 264-465, 874-1339, 1401-1847), `PallyPower.lua` (notably lines 983-1059, 1676-1788, 2818-3086), and existing PPV `DEV_PROGRESS.md` design/test history. Stable PPV `main` is `1.11.39` at `a3c6d739992f958a8c45d03dacb3974ff146c99a`. BuffBro's prior audited dev head was `f2d4dfb2f9146d7d330857d0a74523a2c2fd306d`. The audited BuffBro runtime remains `7ee4868...`, version `0.1.7-dev`.
- Reusable appearance: borderless/no-grey-grid assignments; class-colour vertical textures on the BORDER layer anchored header-icon centre to lowest populated cell centre, crossing blank intermediate provider rows; if no cells assigned, a grey guide to the last visible empty cell with a fading 32px tail; if trailing provider rows are empty, coloured segment stops at last populated cell and grey continuation/fade occupies lower empty tail. Hide all guides with zero visible rows. Class-colour header hover borders revert to black; 32px icon hitboxes, 2px borders and slight native-icon crop. Layout values are adjustable/persistent.
- Current PPV runtime defaults (override older historical design prose): line width 12px clamped 0-18; vertical/horizontal spacing 12px each clamped 8-64; personal divider 36px clamped 8-64; row height 44px with 32px icons. Class-palette mapping is hardcoded for ten columns, including PET using warrior-brown, while the four special columns use Paladin pink.
- Visibility is NOT one feature: (1) coloured/grey connector presence is derived from visible provider rows and actual assignment icon textures; (2) class-icon flyouts are single-open, show only when their class has members, have max 15 hardcoded player controls and float above frame; (3) four eye icons toggle Aura/RF/Seal/Judgement **Buff Bar buttons**, not class-column visibility; (4) assignment UI refresh is dirty-state/visible-window gated and rebuilds link geometry on roster or assignment changes. In PPV non-Paladins can still view assignment grid while Buff Bar is hidden.
- Transfer guidance: implement a BuffBro-owned view renderer from its assignment/provider/target model, not PPV's legacy data/handlers, global names, SavedVariables or casting. Class colours should label target groups; multiple buffs per group/provider, role/unit exceptions and eventual all-class providers must remain expressible. Rendering visibility preferences must never delete or implicitly change assignment intent.
- Static risks to design out: PPV caps rows at 12 Paladins / 15 players per class, assumes fixed Paladin-specific special columns, stores one texture per main grid cell, places flyouts outside the parent without visible screen-edge clamping, and OnHide does not explicitly reset open flyout state. The linker detects assignment presence through icon textures rather than model records. Validate empty, partial, sparse, many-provider, off-screen, collapsed-filter and role/override layouts in game.
- Validation provenance: source/behavior static audit only; no image pixel-parity review, new BuffBro code, Lua 5.0.3 compiler check, or BuffBro runtime test conducted. PPV's own documentation records previous user-tested refinements; it does not establish BuffBro rendering parity.
- Exact next step unchanged: first run and record BuffBro 0.1.7-dev Lua-only UI runtime parity gate at source `7ee4868...`, then GCD diagnosis. After that, scope a standalone BuffBro assignment-model/UI design using only the approved PPV visual language; do not silently broaden into an implementation.
 
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
