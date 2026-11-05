# Development Progress

> Live project-development context for a fresh chat. Keep this current and concise. Remove or compress superseded detail once it no longer affects future work.

## Current
- Branch: `dev`; verified the prior handoff `fc848b53eb8d8a6f3d9f0fd05a8752c95d553e84` matched actual HEAD before BB-PAL-01 work on **2026-11-05**.
- Version (TOC source of truth): **`0.1.8-dev`**.
- Latest runtime-changing commit: **`663210ce387a4f6413718faeac2d574a30879c85`**, BB-PAL-01 native intent/resolver. This status-only commit follows that code commit; verify actual `dev` HEAD before future work.
- Latest stable baseline: `0.1.6` on `main` at `f56b68eb4b7be5110ab680452acd7ed7b392575c`.
- Goal: Work through **BB-PAL-01..08 as eight locked, one-chat-per-chunk steps**, in order. BB-PAL-01 is **implemented and source-checked, not yet target-client-tested or accepted**.
- Scope boundary: **Stop after BB-PAL-01**. Do not begin BB-PAL-02 without the required BB-PAL-01 runtime acceptance/provenance. The new Blessing window, PPV outbound sends and Greater-chain rewrite belong to later locked chunks; GCD, expiry/range UX and non-Paladin providers remain deferred.

## BB-PAL-01 — Implementation, verification and outstanding acceptance (2026-11-05)
- **Implementation commit:** `663210ce387a4f6413718faeac2d574a30879c85` on `dev`, version `0.1.8-dev`; changes only `BuffBro.lua` and `BuffBro.toc` (+254/-13 lines in Lua; TOC patch bump). `dev_rulebook.md`, PPV and `main` untouched.
- **Implemented:** Native persisted Paladin class rules per provider name and local individual normal-Blessing overrides per target name, stored in `BuffBroDB.assignmentIntent.paladin.{classByProvider,individualByProvider}`. Both use stable case-normalized names for reload/roster churn; live roster/provider GUIDs still own target selection. Explicit `-1` clears mask stale PPV fallback; local override clear falls through to class. Getter/setter APIs validate class/family and learned local Blessings, allow separate Paladins to hold same-family rules, and rebuild the **existing** raw/execution queue. `BB.ResolvePaladinBlessing` replaces the old raw-queue resolver; `INDIVIDUAL` remains a normal cast through the existing `BB.ResolveJobSpell` / `BB.ExecuteNext`.
- **Diagnostic entry point (local Paladin only):** `/bb bless class <class|0-9> <family|clear>`, `/bb bless player <name> <family|clear>`, `/bb bless show`, `/bb queue`; family names are wisdom/might/salvation/light/kings/sanctuary (or 0..5). No new assignment window, network send, second scheduler or Greater cast-chain change.
- **Before/after parity provenance:** Previous `0.1.7-dev` source and `0.1.8-dev` committed source were examined. The existing Lua UI construction, debug, cooldown/GCD code, roster/provider lifecycle, PPV receive-only adapter, aura scanning, queue, preflight and one-click executor still exist; only assignment resolution is changed. This is **static/source parity only**. No freshly observed WoW baseline mini/debug/cast parity test was possible from this chat; inherited 0.1.5 dungeon and prior 0.1.7a GCD reports are not new tests of this commit.
- **Static checks actually run (PASS):** 11 pre-commit source assertions and 16 post-commit source assertions verified version/loader, changed-file scope, stable persisted keys, class and individual clear branches, raw queue wiring, individual-normal cast branch, diagnostics, no new PPV outbound calls, preserved GCD constant, and unchanged Lua-only UI entry. Git compare confirms exactly `BuffBro.lua` and `BuffBro.toc` modified. These are source inspections, **not compiler or runtime passes**.
- **Compiler:** **NOT RUN**. Source is reachable through the GitHub connection but no checkout/vendored `tools/lua50/` checker is mounted in the executable environment; no exact Lua 5.0.3 compiler pass can be asserted. The presence of `texlua` (Lua 5.3) does not substitute for the rulebook's required checker.
- **In-game BB-PAL-01 acceptance:** **NOT RUN / PENDING USER TEST** for PPV-disabled baseline load/UI/mini/debug/queue/cast, native set/clear/queue/cast, reload persistence, local normal override, and two-Paladin duplicate records. No new runtime-pass or baseline-failure claim. A confirmed non-GCD parity failure would block progression and must be handled **inside BB-PAL-01 only**, or stopped with explicit user approval.
- **Known/deferred:** Existing unresolved GCD sweep; legacy cast-mode preflight risk; PPV receive-only fallback until BB-PAL-06/07; post-Greater normal recast chain until BB-PAL-05; no Blessing assignment grid until BB-PAL-02; no class/individual editing UI permissions until BB-PAL-03/04. Do not claim same-client PPV edit parity or two-way protocol from this chunk.
- **Exact next action:** User performs the numbered `0.1.8-dev` WoW 1.12.1 + ClassicAPI PPV-disabled BB-PAL-01 runtime matrix below and reports results against code commit `663210ce387a4f6413718faeac2d574a30879c85`. Record pass/fail and resolve any blocking non-GCD failure within BB-PAL-01. Once accepted, start **BB-PAL-02 in a NEW chat**, and implement only its read-only assignment window.

## APPROVED / LOCKED IMPLEMENTATION CONTRACT — 2026-11-04

**Approval state:** Product behaviour and the implementation plan are approved for planning purposes; **no coding requested in the 2026-11-04 handoff**. The user must explicitly start chunk BB-PAL-01. This section supersedes contradictory pre-decision advice in the 2026-11-01 audit sections below. Eight fixed chunks = eight distinct development chats; no executor chat may split, merge, reorder, skip, or re-scope chunks autonomously.

### User-approved game and UX behaviour
- Paladin Blessings are the initial implementation and live-test target; the underlying BuffBro data/queue ownership stays class-extensible. Do not export non-Paladin assignments through the Paladin-only PPV protocol.
- Match **PPV's actual assignment interactions**, not just appearance, for this first Blessing slice: Paladin/provider rows, class columns (including the PPV pet column where applicable), class-colour connectors and fading grey guides, left-click cycle, right-click clear, class-header individual flyouts, individual left-click cycle and right-click clear. Do not force the eventual all-class model into PPV's singleton-cell limitation.
- **Blessing-only initial assignment window.** Defer PPV Aura, Seal, Righteous Fury and Judgement columns and associated assignment UX; the existing mini cast/debug UI remains in place.
- Class Blessing assignments synchronize **two ways** via the existing PPV addon protocol: editing in BuffBro updates PPV peers and vice versa, using equivalent PPV sender/control permissions. **Do not edit PPV's code** as part of this plan unless the user separately approves an actual protocol compatibility blocker.
- Individual *normal* Blessing overrides **remain local**, matching current PPV: editable/synchronized between BuffBro and PPV only if both are on the *same client*; **not** sent across clients. Do not advertise full network sync for individual overrides.
- Allow duplicate/same-family class assignments across different Paladins exactly as PPV permits; never silently reject or resolve them as conflicts. If a Blessing is detected on a target, all assigned Paladins needing that same Blessing see it as satisfied, regardless of which one cast it. Duplicate-assignment warnings are deferred UX.
- Greater Blessings are **class-wide**, not raid-subgroup-wide. After a successful Greater Blessing casts on a class, re-queue/reapply that Paladin's affected individual normal Blessing overrides in BuffBro's manual, one-cast-per-click **chain**, even where ordinary buff-presence logic would otherwise skip them. This ordering is Blessing-specific; do **not** generalize Blessing's per-caster exclusivity, normal/Greater ranks or overwriting behaviour to other future buffing classes.
- Keep local provider capability, spellbook lifecycle, roster, aura observations, existing raw/execution queues, reagent-based AUTO/normal selection, preflight and one-click casting owned by BuffBro. Do not introduce a second cast scheduler or make opening the UI mutate provider readiness.
- Defer visual range warnings, expiry/rebuff thresholds, GCD overlay diagnosis/fix (prior tested builds did not render the sweep), duplicate alerts, other buffing classes, native non-PPV all-class network protocol, and broader raid-role/group targeting. Do not lose these backlog items.

### Fixed chat-by-chat coding partitions (strict order)

**BB-PAL-01 — Baseline gate and standalone assignment engine**
- Scope: Smoke-check current 0.1.7-dev Lua-only UI, debug/mini controls, queue and cast behaviour against inherited known-good reports (record actual newly tested provenance). GCD failure is recorded, **not fixed or used as a blocker**. Build BuffBro-owned Paladin class assignment + local individual-override state, stable provider/target references, mutation/read APIs, reload persistence as genuine user intent, and a resolver that feeds the **existing** raw queue. Minimal diagnostic/slash verification permitted without building the new grid.
- Acceptance: With PPV disabled, change a local class assignment through the diagnostic entry point, observe the correct missing-buff queue and cast path, clear it, and verify persistence on reload; a local override resolves as normal; duplicate Paladins' rule records can coexist. Capture before/after parity. No new window, PPV outbound, or Greater-chain rewrite.
- Gate: If non-GCD baseline parity fails, diagnose/repair only the blocking baseline defect inside this chunk, and do not progress until tested or user-authorized to stop with a blocker.

**BB-PAL-02 — Read-only PPV-style Blessing assignment window**
- Scope: Lua-built BuffBro-owned frame, scalable Paladin rows, PPV class/pet headers and class cells, role-appropriate empty/assigned icons, icon crop/borders, class-colour main connector and grey continuation/fade, layout sizing/visibility, roster refresh/dirty redraw. Project *state* to icons; never use texture presence as assignment truth. Do not clone PPV globals or its fixed 12-row/15-player cap.
- Acceptance: In game, visually inspect zero/one/multiple Paladins, empty/sparse assignments, coloured/grey line termination, roster change, flyout anchor reservation, and window open/close with PPV absent. Read-only grid only; no assignment edits, no individual flyout function yet.

**BB-PAL-03 — Class-grid editing and permissions**
- Scope: Bind left-click forward cycle, right-click clear, PPV-equivalent valid option filtering/modifier semantics and optionally its wheel reverse cycle if present in the reviewed PPV controls. Apply edits through native mutation API, persist, re-render immediately, update queue. Implement editability presentation based on PPV control rules; no network sends until BB-PAL-06.
- Acceptance: Class assignments made/cleared in the grid affect queue and visuals, survive reload, and never let an unauthorized editor silently change another Paladin's assignment. Any yet-unavailable remote synchronization must be visibly marked local-only/testing; no false claim of PPV compatibility.

**BB-PAL-04 — Local individual-player flyouts**
- Scope: Header-click player list/flyout, exclusivity of one open flyout, bounds-aware placement, individual normal-Blessing forward cycling/right-click clear, tooltip/status, native local-override persistence and refresh. Only **the local Paladin's** overrides are editable in this slice; leave other Paladins' local overrides unrepresented rather than inventing network visibility. PPV same-client mutual bridge is completed in BB-PAL-07.
- Acceptance: Individual overrides work solo and in party/raid and appear in existing queue as normal Blessings; clearing reverts to class assignment; reload/roster churn does not lose configured intent; flyouts remain on screen. Do not change Greater-chain ordering yet.

**BB-PAL-05 — Greater Blessing -> individual override casting chain**
- Scope: Correct class-wide Greater cast work and detect a successful cast before scheduling/re-prioritizing all *affected local normal overrides* for that Paladin/class. Preserve one real cast per click; avoid treating class Greater as subgroup-wide; prevent an aura-presence test or queue rebuild from dropping required override recasts; don't spin on failed casts. Preserve reagent-aware AUTO->normal behaviour and duplicate-assignment-visible-as-satisfied semantics. Revisit cast-mode propagation in preflight **only as required for accurate casting-chain checks**, not as a new range UX feature.
- Acceptance: With at least two same-class targets and one individual override, a needed Greater is cast first, then the override reappears in the chain and is manually recast; a failed Greater does not falsely trigger recasts; two Paladins assigning the same family show buff detected without an artificial conflict; no automatic multi-casting.

**BB-PAL-06 — PPV class-assignment protocol, bidirectional**
- Scope: Complete isolated PLPWR Paladin-class protocol adapter: receive validated SELF/ASSIGN/MASSIGN, send equivalent permitted ASSIGN/MASSIGN, publish/respond to PPV presence/REQ/SELF as needed for a BuffBro-only client, roster/capability identity constraints, sender/permission checks equivalent to PPV, and replay/echo suppression. Keep BuffBro-native assignments authoritative locally but reconcile PPV-compatible edits into the same rules; never transmit non-Paladin rules or individual overrides.
- Acceptance: Two separate clients, one BuffBro and one PPV, observe class assignment edits in either direction with correct permission handling; joining/reloading doesn't silently create competing assignment owners or duplicate endless broadcasts. Do not yet claim complete same-client compatibility or finished regression.

**BB-PAL-07 — Same-client coexistence and reconciliation**
- Scope: BuffBro and PPV installed together: resolve local self-message blind spots, synchronize class assignment edits in both windows without feedback loops, read/write the local PPV individual-override storage safely in both directions, and reconcile login/reload/roster/REQ states. Confirm PPV remains optional and no other-class outbound messages occur. No PPV source modification without separate authorization.
- Acceptance: On the same Paladin client, changing class assignments in either addon updates the other and the BuffBro queue; changing *local* individual overrides in either updates the other; another client does not receive those overrides; PPV-disabled startup/casting still works.

**BB-PAL-08 — Bounded end-to-end regression and handoff**
- Scope: Run and document the full acceptance matrix, perform Lua 5.0.3 compiler checks where the canonical checker is actually executable, check runtime load/cast/UI/reload/party/raid/duplicate/Greater chain/reagents/permissions/mixed-addon/reconnect use, and fix only defects directly inside BB-PAL-01..07 functionality. Record precise tested versions/commits and unresolved defects. No new feature development, range/expiry UX, GCD work, or release promotion.
- Acceptance: User-reported in-game results bound to exact dev commit/version, explicit pass/fail/untested entries, and a clear stable-or-blocked result. Work outside locked scope is deferred and requires user-approved plan amendment.

### Chat execution / frozen-scope policy
1. **Exactly eight execution chunks, one new chat per chunk**, in BB-PAL-01..08 order. Do not split an oversized chunk or combine smaller ones, re-sequence them, silently add an extra chunk, or use unapproved time estimates. If a chunk proves too large or blocked, stop at a safe point and ask the user to approve an *explicit plan amendment* in DEV_PROGRESS.md; do not self-rechunk.
2. Every chat reads the current DEV_PROGRESS.md and unchanged dev_rulebook.md, verifies dev branch head and TOC version, checks prior chunk acceptance/provenance, and implements **only its numbered chunk**. Do not advance merely because code was written; report user runtime checks separately. User supplies WoW game/UX decisions; implementer handles technical details, flags only decisions where game behaviour is genuinely ambiguous.
3. Each code/metadata-affecting revision increments the TOC patch version according to dev_rulebook.md; documentation-only status commits do not. Check Lua 5.0.3 syntax/local limits and use ClassicAPI only as already required; do not quietly change dependency policy or introduce UI.lua. No main promotion without explicit approval.
4. At the end of each chunk, record completed work, exact dev commit/version, test provenance (implemented/static checked/user tested), remaining blockers and exact next chunk in DEV_PROGRESS.md; commit the handoff and supply a fresh-chat resume prompt. Any chunk still awaiting target-client tests is **not automatically accepted**.
5. Only the user can authorize altering any chunk boundary, dropping/adding features, a PPV repository modification, or promotion/release. Keep all deferred items visible but outside the eight-chat scope.

### Cross-chunk risk notes
- PPV source at reviewed dev 1.11.70-dev sends class ASSIGN/MASSIGN/SELF across clients but its individual normal Blessing overrides are local client storage. Do not claim a protocol message for remote individual overrides exists.
- BuffBro 0.1.7-dev currently only *receives* PLPWR SELF/ASSIGN/MASSIGN and imports local PPV globals; it does not originate protocol assignments or provide its own grid. Source-level cast-mode preflight propagation is suspect, and buff-presence-only queue logic does not itself preserve post-Greater individual recasts. These are implementation risks, **not** verified regressions.
- PPV copy of a Blessing can be satisfied by the observed family from either Paladin; after a Greater class cast, local normal overrides must still be scheduled for recast despite that family-level satisfaction rule. Design a deliberate chain/invalidation marker, not indiscriminate aura clearing.
- Initial window intentionally omits PPV Aura, RF, Seal and Judgement columns while closely matching approved PPV Blessing look/click patterns. The existing PPV eye icons toggle Buff Bar special abilities, not these class columns.

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

### Product Direction — Superseded preliminary guidance (2026-11-01)
- The newer **2026-11-04 APPROVED / LOCKED IMPLEMENTATION CONTRACT above is authoritative**. The older audit correctly established BuffBro's independent class-extensible state ownership, but incorrectly excluded PPV-style interactions and outbound class-assignment compatibility.
- User now explicitly approves PPV-style **Blessing-only** grid interactions and **two-way** Paladin class assignment compatibility while retaining local-only individual overrides. Do not reuse PPV globals as BuffBro's authoritative state, PPV's hard limits, or Blessing-specific mechanics for other classes.
- 0.1.7-dev UI parity is the first BB-PAL-01 gate. GCD diagnosis is deferred until after the rework, rather than remaining a prerequisite.

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
- GCD diagnosis and any subsequent repair are explicitly **deferred until after** the locked Paladin rework. When resumed, inspect actual `C_Spell.GetSpellCooldown(61304)` timing data and independently force a visible cooldown timer instead of making speculative tweaks.
- Keep PallyPower protocol details isolated from the generic core; extract an adapter/module only when there is a concrete reason.
- Review the ClassicAPI requirement against the rulebook separately; do not opportunistically change dependency policy during the UI migration.

## Recent Relevant Commits
- `663210ce387a4f6413718faeac2d574a30879c85` — BB-PAL-01 native persisted Blessing assignment intent, resolver and diagnostic edits (0.1.8-dev; not yet user-tested).
- `fc848b53eb8d8a6f3d9f0fd05a8752c95d553e84` — Lock approved eight-chunk Paladin contract (status only).
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
- BB-PAL-01 native Paladin assignment engine/resolver and diagnostic slash are implemented in `0.1.8-dev` (`663210ce387a4f6413718faeac2d574a30879c85`); all new runtime paths and Lua-only baseline parity await user testing. See current BB-PAL-01 ledger and exact runtime matrix.
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

### Next Runtime Test — BB-PAL-01 gate (all PENDING, do not infer pass)
Target: `dev` runtime commit `663210ce387a4f6413718faeac2d574a30879c85`, addon `0.1.8-dev`; **WoW 1.12.1 + ClassicAPI, with PallyPowerVanilla disabled**.
1. Log in as a Paladin; check clean load/no Lua error and preserved Lua-only mini UI, button/icon/status/class-colour border.
2. Check Ctrl-drag, reload position restore, debug/menu open, tabs/refresh/scroll/close, and tooltips.
3. Establish baseline missing Blessing through an existing rule (if available) and verify ready/blocked queue ordering plus left AUTO, right normal, Shift-force and one-click cast; record baseline before native edits.
4. Note GCD sweep result without repairing it or treating its known failure as a BB-PAL-01 blocker.
5. Choose a learned Blessing (e.g. `might`), then `/bb bless class paladin might`; with the class lacking it, inspect `/bb queue` and confirm missing-buff job + one-click cast, then aura satisfaction.
6. `/bb bless class paladin clear`; verify the native rule is cleared and the corresponding native-only work disappears.
7. Set a class rule again; `/reload`; use `/bb bless show` and `/bb queue` to confirm persisted intent, not a runtime-queue snapshot.
8. Assign a different learned local normal Blessing with `/bb bless player <character> <family>`; check the individual job and that its spell is **normal** even when Greater is available. Clear the individual override and confirm fallback to the class rule.
9. With another Paladin present, exercise `BuffBro.SetPaladinClassAssignment("OtherPaladin", 4, <familyID>)` through the normal in-game Lua console and the same family for the local provider; verify separate stored provider records coexist and do not change the local cast owner. This is an API/diagnostic test only, not remote editing permissions.
10. Reload with PPV still disabled; confirm class + individual native intent persists and a clear remains cleared. Verify no new assignment window/outbound PPV behavior and no regression in mini/debug/queue.
A failure on non-GCD baseline parity requires BB-PAL-01 resolution before beginning BB-PAL-02. Report each item PASS/FAIL/NOT RUN with character/realm-sensitive details omitted from public logs where appropriate.

## Historical Read-Only Comparison Audit — 2026-11-01 (superseded where inconsistent with approved 2026-11-04 contract)
- Audit branch/head: `dev` at `4772b7c06c7d88fe427294bcff83a52067692612`; addon version remains `0.1.7-dev`. `main` remains the `0.1.6` baseline at `f56b68eb4b7be5110ab680452acd7ed7b392575c`. Latest commits are documentation/rulebook synchronization on 2026-09-26 and 2026-09-25, after the runtime-changing Lua-only migration at `7ee4868e88b2cc77b68a5906068fedee5360c8d0`.
- Verified implemented from code and earlier user-tested reports: Paladin-only roster/provider/capability scan, PallyPower receive/import adapter, aura observation, raw and execution queues, smart blocked-work rotation, spell-specific range and LoS preflight, AUTO Greater/normal selection, reagent inspection, one-button cast, mini/debug UI construction. Earlier dungeon test results belong to the tested baseline and do not establish current migrated-UI parity.
- Major feature-parity gaps vs 1.12 PallyPower: no BuffBro-owned editable raid-assignment grid; no outbound BuffBro-native synchronization or PP SELF/ASSIGN broadcasting; no replacement coordination model; no near-expiry countdown/rebuff logic (the queue currently considers a matching aura 'present' without remaining-time threshold); no other class providers; no documented 40-player raid/performance test or automated test suite. The first implementation is a capable PallyPower-assisted Paladin cast client, not yet a standalone coordinator.
- Code audit candidates requiring test/fix after the current UI parity checkpoint: `BB.BuildExecutionQueue` reads `castMode` without defining/passing it and `BB.ExecuteNext` invokes preflight without its chosen mode; right-click NORMAL preflight may use AUTO's Greater spell range. The fallback question-mark texture paths in `UpdateMiniUI` contain single backslashes and should be checked against Lua string escape rules. The PLPWR ASSIGN/MASSIGN receiver appears to lack the original reference addon's leader/control validation. PallyPower individual overrides are imported from local globals only. Hardcoded English aura names prevent verified localization parity.
- Untested/deferred: no current runtime validation of `0.1.7-dev` Lua-only frame construction; GCD Model timer remains unresolved; no stress, reconnect, cross-client protocol, secure-casting or localization matrix run. These findings are static audit candidates, not confirmed in-game failures.
- Historical outcome only: this was a read-only audit. Its prior sequencing recommendations are replaced by the 2026-11-04 locked plan: initial parity smoke in BB-PAL-01, then native Blessing assignments/UI/casting/PPV interoperability across BB-PAL-01..08; GCD and expiry work deferred.

## Historical PPV Window Visual Audit — 2026-11-01 (source reference; approved interaction scope changed 2026-11-04)
- Sources: `Seraphic8x2244/PallyPowerVanilla` dev head `d5c4383fb56680844490248b2c78d19d1188e3e4`, `1.11.70-dev`, `PallyPowerUI.lua` (notably lines 21-65, 160-246, 264-465, 874-1339, 1401-1847), `PallyPower.lua` (notably lines 983-1059, 1676-1788, 2818-3086), and existing PPV `DEV_PROGRESS.md` design/test history. Stable PPV `main` is `1.11.39` at `a3c6d739992f958a8c45d03dacb3974ff146c99a`. BuffBro's prior audited dev head was `f2d4dfb2f9146d7d330857d0a74523a2c2fd306d`. The audited BuffBro runtime remains `7ee4868...`, version `0.1.7-dev`.
- Reusable appearance: borderless/no-grey-grid assignments; class-colour vertical textures on the BORDER layer anchored header-icon centre to lowest populated cell centre, crossing blank intermediate provider rows; if no cells assigned, a grey guide to the last visible empty cell with a fading 32px tail; if trailing provider rows are empty, coloured segment stops at last populated cell and grey continuation/fade occupies lower empty tail. Hide all guides with zero visible rows. Class-colour header hover borders revert to black; 32px icon hitboxes, 2px borders and slight native-icon crop. Layout values are adjustable/persistent.
- Current PPV runtime defaults (override older historical design prose): line width 12px clamped 0-18; vertical/horizontal spacing 12px each clamped 8-64; personal divider 36px clamped 8-64; row height 44px with 32px icons. Class-palette mapping is hardcoded for ten columns, including PET using warrior-brown, while the four special columns use Paladin pink.
- Visibility is NOT one feature: (1) coloured/grey connector presence is derived from visible provider rows and actual assignment icon textures; (2) class-icon flyouts are single-open, show only when their class has members, have max 15 hardcoded player controls and float above frame; (3) four eye icons toggle Aura/RF/Seal/Judgement **Buff Bar buttons**, not class-column visibility; (4) assignment UI refresh is dirty-state/visible-window gated and rebuilds link geometry on roster or assignment changes. In PPV non-Paladins can still view assignment grid while Buff Bar is hidden.
- Transfer guidance: implement a BuffBro-owned view renderer from its assignment/provider/target model, not PPV's legacy storage, globals or casting. **The user subsequently approved replicating PPV's Blessing grid click-to-cycle/right-clear and individual flyout interactions** (see locked plan). Other-class and eventual broader targeting cannot be constrained by PPV's original schema. Visibility preferences never delete assignment intent.
- Static risks to design out: PPV caps rows at 12 Paladins / 15 players per class, assumes fixed Paladin-specific special columns, stores one texture per main grid cell, places flyouts outside the parent without visible screen-edge clamping, and OnHide does not explicitly reset open flyout state. The linker detects assignment presence through icon textures rather than model records. Validate empty, partial, sparse, many-provider, off-screen, collapsed-filter and role/override layouts in game.
- Validation provenance: source/behavior static audit only; no image pixel-parity review, new BuffBro code, Lua 5.0.3 compiler check, or BuffBro runtime test conducted. PPV's own documentation records previous user-tested refinements; it does not establish BuffBro rendering parity.
- Historical next-step guidance superseded by the 2026-11-04 approved eight-chat Blessing rework. GCD work is explicitly deferred.
 
## Planned / Next Work
- **Current next action:** Run and record the BB-PAL-01 `0.1.8-dev` PPV-disabled runtime matrix above. BB-PAL-01 is not accepted without the required target-client results; fix a confirmed non-GCD baseline blocker only within BB-PAL-01.
- Run BB-PAL-02 through BB-PAL-08 in strict numerical order, each in its own fresh development chat. Later implementers may not rewrite this partition list.
- Keep GCD diagnosis, expiry thresholds, range UX, duplicates UX, other Paladin special columns, other classes and all-class native sync on the deferred backlog. Do not conflate the initial Blessing window with full PPV feature parity.
- Each chunk's next handoff must cite the exact code commit/version, implemented/checked/user-tested scope and immediate acceptance test/blocker.

## Deferred / Out of Scope
- Splitting UI construction into `UI.lua` or another runtime module without a concrete architectural need.
- Minimal client modes for assignment/buff communication and display.
- Future Priest/Druid/Mage provider support.
- Additional BuffBro-native all-class communication beyond the approved Paladin-only two-way PPV compatibility.
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
Validate **BB-PAL-01 `0.1.8-dev`, code commit `663210ce387a4f6413718faeac2d574a30879c85`** in the WoW 1.12.1 client with PPV disabled using the numbered matrix above. Capture actual mini/debug/queue/cast parity and native assignment set/clear/reload/override/duplicate results. If a non-GCD baseline test fails, address it **only inside BB-PAL-01** before acceptance; if a blocker cannot be resolved, stop and request an explicit plan amendment rather than silently adding a chat/chunk. On user acceptance, the **next fresh development chat is BB-PAL-02 only: read-only PPV-style Blessing assignment window**. Do not start it here or work on GCD.

**Fresh-chat recovery:** Read `dev_rulebook.md` and this file, verify current `dev` HEAD (the documentation-only handoff commit following `663210ce387a4f6413718faeac2d574a30879c85`) and TOC `0.1.8-dev`, confirm the exact BB-PAL-01 user-test results, then proceed only when its acceptance gate is satisfied.
