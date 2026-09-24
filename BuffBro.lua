-- ============================================================================
-- BuffBro 0.1.0-test1
-- WoW 1.12.1 + ClassicAPI
--
-- PHASE 1 PURPOSE
--   Prove the backend state pipeline while running alongside PallyPower:
--
--   Roster
--     -> Providers / capabilities
--     -> Assignments
--     -> Aura detection
--     -> Raw work queue
--
-- There is intentionally NO casting and NO designed UI in this build.
--
-- DESIGN RULES
--   * BuffBro owns its own state. PallyPower is only a compatibility source.
--   * Detection is independent of assignments.
--   * Assignments are authoritative once validly created.
--   * Capability constrains assignment creation; queue logic does not invent
--     "better" assignments.
--   * UI must read state rather than own game truth.
--   * Unknown data remains unknown.
-- ============================================================================

BuffBro = BuffBro or {}
local BB = BuffBro

BB.ADDON_NAME = "BuffBro"
BB.VERSION = GetAddOnMetadata(BB.ADDON_NAME, "Version") or "unknown"
BB.PP_PREFIX = "PLPWR"
BB.GCD_SPELL_ID = 61304
BB.RECONCILE_SECONDS = 2.0

BB.State = {
    mode = "SOLO",
    roster = {},          -- [guid] = member
    rosterOrder = {},     -- stable debug iteration order
    nameToGuid = {},      -- [name] = guid
    providers = {},       -- [guid] = provider
    observations = {},    -- [guid] = { buffs = {...}, observedAt = time }
    rawQueue = {},        -- base missing-work set in stable assignment order
    executionQueue = {},    -- READY first, expected failures after
}

BB.Queue = {
    rotation = {},         -- [jobKey] = { order, section }
    rotationCounter = 0,
}

BB.Debug = {
    enabled = false,
    dirty = true,
    view = "queue",
}

BB.UI = {
    castHover = false,
    draggingMini = false,
    suppressMenuClick = false,
}

BB.LocalProvider = {
    state = "UNINITIALIZED", -- UNINITIALIZED / WAITING_SPELLBOOK / READY / NOT_PROVIDER
    reason = nil,
    blessingCount = 0,
    resolvedSpellCount = 0,
    generation = 0,
}

-- Local spell registry used by the executor.
-- Provider capability remains generic; these spellbook details are local-only.
BB.LocalSpells = {}

BB.Executor = {
    pending = nil,
    lastResult = nil,
}

BB.ReagentCounts = {}

BuffBroDB = BuffBroDB or {}

BB.ClassColors = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    MAGE = { 0.41, 0.80, 0.94 },
    ROGUE = { 1.00, 0.96, 0.41 },
    DRUID = { 1.00, 0.49, 0.04 },
    HUNTER = { 0.67, 0.83, 0.45 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    PRIEST = { 1.00, 1.00, 1.00 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    PALADIN = { 0.96, 0.55, 0.73 },
}

-- ============================================================================
-- STATIC DEFINITIONS
-- ============================================================================

-- PallyPower protocol class indices.
-- Confirmed against PallyPowerVanilla 1.6.1 localization-enUS.lua.
BB.PPClassByToken = {
    WARRIOR = 0,
    ROGUE = 1,
    PRIEST = 2,
    DRUID = 3,
    PALADIN = 4,
    HUNTER = 5,
    MAGE = 6,
    WARLOCK = 7,
    SHAMAN = 8,
}

BB.PPClassName = {
    [0] = "Warrior",
    [1] = "Rogue",
    [2] = "Priest",
    [3] = "Druid",
    [4] = "Paladin",
    [5] = "Hunter",
    [6] = "Mage",
    [7] = "Warlock",
    [8] = "Shaman",
    [9] = "Pet",
}

-- Generic core terminology, Paladin implementation first.
BB.BuffFamily = {
    [0] = { key = "WISDOM",    name = "Wisdom" },
    [1] = { key = "MIGHT",     name = "Might" },
    [2] = { key = "SALVATION", name = "Salvation" },
    [3] = { key = "LIGHT",     name = "Light" },
    [4] = { key = "KINGS",     name = "Kings" },
    [5] = { key = "SANCTUARY", name = "Sanctuary" },
}

-- Phase-1 recogniser.
-- ClassicAPI gives us spellId as well; the first test build uses exact aura
-- names because this keeps the prototype small and makes failures obvious.
-- This table is deliberately isolated so we can replace it with a proper
-- spell-ID registry without touching detection/queue architecture.
BB.BuffNameToFamily = {
    ["Blessing of Wisdom"] = 0,
    ["Greater Blessing of Wisdom"] = 0,
    ["Blessing of Might"] = 1,
    ["Greater Blessing of Might"] = 1,
    ["Blessing of Salvation"] = 2,
    ["Greater Blessing of Salvation"] = 2,
    ["Blessing of Light"] = 3,
    ["Greater Blessing of Light"] = 3,
    ["Blessing of Kings"] = 4,
    ["Greater Blessing of Kings"] = 4,
    ["Blessing of Sanctuary"] = 5,
    ["Greater Blessing of Sanctuary"] = 5,
}

-- ============================================================================
-- SMALL UTILITIES
-- ============================================================================

local function BB_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[BuffBro]|r " .. tostring(msg))
    end
end

local function BB_Debug(msg)
    if BB.Debug.enabled then
        BB_Print("|cffaaaaaa" .. tostring(msg) .. "|r")
    end
end

local function BB_CountTable(t)
    local n = 0
    if not t then return 0 end
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function BB_FamilyName(id)
    local def = BB.BuffFamily[id]
    if def then return def.name end
    return "Unknown(" .. tostring(id) .. ")"
end

local function BB_SafeGuid(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitGUID then
        return UnitGUID(unit)
    end
    return nil
end

local function BB_PlayerGuid()
    return BB_SafeGuid("player")
end

local function BB_EnsureProvider(guid, name)
    if not guid then return nil end
    local p = BB.State.providers[guid]
    if not p then
        p = {
            guid = guid,
            name = name,
            class = "PALADIN",
            addon = {
                pallyPower = false,
                buffBro = false,
            },
            capabilities = {},   -- [family] = { rank, talent, source }
            assignments = {},    -- [ppClass] = family / -1
            individual = {},     -- [targetName] = family / -1 (local PP bridge only in Phase 1)
            sources = {},
        }
        BB.State.providers[guid] = p
    end
    if name then p.name = name end
    return p
end

local function BB_FindProviderByName(name)
    if not name then return nil end

    local guid = BB.State.nameToGuid[name]
    if guid and BB.State.providers[guid] then
        return BB.State.providers[guid]
    end

    for _, provider in pairs(BB.State.providers) do
        if provider.name == name then
            return provider
        end
    end

    return nil
end

local function BB_EnsureProviderByName(name)
    local provider = BB_FindProviderByName(name)
    if provider then return provider end

    -- A PLPWR sender can arrive a moment before the roster event settles.
    -- Keep the record under a temporary name key rather than dropping data.
    local guid = BB.State.nameToGuid[name]
    if not guid then
        guid = "NAME:" .. tostring(name)
    end
    return BB_EnsureProvider(guid, name)
end

-- ============================================================================
-- CLASSICAPI DEPENDENCY
-- ============================================================================

function BB.CheckClassicAPI()
    local ok = true

    if not UnitGUID then ok = false end
    if not C_UnitAuras then ok = false end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then ok = false end

    BB.classicAPIReady = ok
    return ok
end

-- ============================================================================
-- ROSTER
-- ============================================================================

local function BB_AddRosterUnit(unit)
    if not unit or not UnitExists(unit) then return end

    local name = UnitName(unit)
    if not name then return end

    local guid = BB_SafeGuid(unit)
    if not guid then
        -- ClassicAPI is required, so a missing GUID is not silently replaced
        -- with name identity. Skip and make the problem visible in debug.
        BB_Debug("Roster skipped " .. tostring(unit) .. ": no GUID")
        return
    end

    local _, classToken = UnitClass(unit)
    local member = BB.State.roster[guid]

    if not member then
        member = { guid = guid }
        BB.State.roster[guid] = member
        table.insert(BB.State.rosterOrder, guid)
    end

    -- Prefer "player" as the local player's token even when raidN also maps it.
    if member.unit ~= "player" or unit == "player" then
        member.unit = unit
    end

    member.name = name
    member.class = classToken
    member.connected = UnitIsConnected(unit) and true or false
    member.dead = UnitIsDeadOrGhost(unit) and true or false
    member.ppClass = BB.PPClassByToken[classToken]
    member.seenAt = GetTime()

    BB.State.nameToGuid[name] = guid

    if classToken == "PALADIN" then
        local provider = BB_EnsureProvider(guid, name)
        provider.unit = member.unit
    end
end

function BB.RebuildRoster(reason)
    BB.State.roster = {}
    BB.State.rosterOrder = {}
    BB.State.nameToGuid = {}

    local raidCount = GetNumRaidMembers()
    local partyCount = GetNumPartyMembers()

    BB_AddRosterUnit("player")

    if raidCount and raidCount > 0 then
        BB.State.mode = "RAID"
        local i
        for i = 1, raidCount do
            BB_AddRosterUnit("raid" .. i)
        end
    elseif partyCount and partyCount > 0 then
        BB.State.mode = "PARTY"
        local i
        for i = 1, partyCount do
            BB_AddRosterUnit("party" .. i)
        end
    else
        BB.State.mode = "SOLO"
    end

    -- Refresh current provider unit tokens after the roster rebuild.
    local guid, provider
    for guid, provider in pairs(BB.State.providers) do
        local member = BB.State.roster[guid]
        if member then
            provider.unit = member.unit
            provider.name = member.name
        else
            provider.unit = nil
        end
    end

    BB.ScanAllAuras()

    if BB.IsLocalProviderReady() then
        BB.RefreshProviderDependents(reason)
    else
        BB.State.executionQueue = {}
        BB.UpdateMiniUI()
    end

    BB.Debug.dirty = true

    BB_Debug("Roster rebuilt (" .. tostring(reason) .. "): " ..
        tostring(BB_CountTable(BB.State.roster)) .. " members, mode=" .. BB.State.mode)
end

-- ============================================================================
-- PROVIDER CAPABILITY
-- ============================================================================

local function BB_LocalSpellSignature(spells)
    local parts = {}
    local family

    for family = 0, 5 do
        local set = spells[family]
        if set then
            local normal = set.normal
            local greater = set.greater

            if normal then
                table.insert(parts,
                    tostring(family) .. ":N:" ..
                    tostring(normal.spellID or "nil") .. ":" ..
                    tostring(normal.rank or 0))
            end

            if greater then
                table.insert(parts,
                    tostring(family) .. ":G:" ..
                    tostring(greater.spellID or "nil") .. ":" ..
                    tostring(greater.rank or 0))
            end
        end
    end

    return table.concat(parts, "|")
end

function BB.ScanLocalProvider(reason)
    local _, classToken = UnitClass("player")

    if classToken ~= "PALADIN" then
        local changed = BB.LocalProvider.state ~= "NOT_PROVIDER"
        BB.LocalSpells = {}
        BB.LocalProvider.state = "NOT_PROVIDER"
        BB.LocalProvider.reason = reason
        BB.LocalProvider.blessingCount = 0
        BB.LocalProvider.resolvedSpellCount = 0

        if changed then
            BB.LocalProvider.generation = BB.LocalProvider.generation + 1
            BB.Debug.dirty = true
        end

        return true, changed
    end

    local guid = BB_PlayerGuid()
    local name = UnitName("player")
    local provider = BB_EnsureProvider(guid, name)

    if not provider then
        BB.LocalProvider.state = "WAITING_SPELLBOOK"
        BB.LocalProvider.reason = "NO_PLAYER_IDENTITY"
        BB.Debug.dirty = true
        return false, false
    end

    local oldSignature = BB_LocalSpellSignature(BB.LocalSpells or {})
    local newSpells = {}
    local newCapabilities = {}
    local blessingCount = 0
    local resolvedSpellCount = 0

    -- Spell names/ranks come from the Vanilla spellbook.
    -- Spell IDs come from ClassicAPI. We only publish the new provider state
    -- after the complete scan has been validated.
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end

        local family = BB.BuffNameToFamily[spellName]
        if family ~= nil then
            blessingCount = blessingCount + 1

            local rankNumber = 0
            if spellRank then
                local _, _, rankText = string.find(spellRank, "Rank (%d+)")
                if rankText then
                    rankNumber = tonumber(rankText) or 0
                end
            end

            local isGreater = string.find(spellName, "^Greater Blessing of ") ~= nil
            local info = nil

            if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and
               Enum and Enum.SpellBookSpellBank then
                info = C_SpellBook.GetSpellBookItemInfo(
                    i,
                    Enum.SpellBookSpellBank.Player
                )
            end

            local spellID = info and info.spellID or nil
            if spellID then
                resolvedSpellCount = resolvedSpellCount + 1
            end

            newCapabilities[family] = newCapabilities[family] or {
                rank = 0,
                talent = nil,
                source = "SPELLBOOK",
            }

            local cap = newCapabilities[family]
            if rankNumber > (cap.rank or 0) then
                cap.rank = rankNumber
            end

            if isGreater then
                cap.hasGreater = true
            else
                cap.hasNormal = true
            end

            newSpells[family] = newSpells[family] or {}
            local bucket = isGreater and "greater" or "normal"
            local old = newSpells[family][bucket]

            if not old or rankNumber >= (old.rank or 0) then
                newSpells[family][bucket] = {
                    spellbookIndex = i,
                    spellID = spellID,
                    name = spellName,
                    rankText = spellRank,
                    rank = rankNumber,
                    icon = (info and info.iconID) or GetSpellTexture(i, BOOKTYPE_SPELL),
                    reagents = (spellID and C_Spell and C_Spell.GetSpellReagents)
                        and C_Spell.GetSpellReagents(spellID) or nil,
                }
            end
        end

        i = i + 1
    end

    BB.LocalProvider.blessingCount = blessingCount
    BB.LocalProvider.resolvedSpellCount = resolvedSpellCount
    BB.LocalProvider.reason = reason

    -- A Paladin with learned Blessings is READY only when every Blessing
    -- spellbook record we intend to expose has a ClassicAPI spell ID.
    -- We do not publish a half-resolved provider table.
    if blessingCount == 0 or resolvedSpellCount < blessingCount then
        local stateChanged = BB.LocalProvider.state ~= "WAITING_SPELLBOOK"
        BB.LocalProvider.state = "WAITING_SPELLBOOK"

        if stateChanged then
            BB.Debug.dirty = true
        end

        return false, stateChanged
    end

    local newSignature = BB_LocalSpellSignature(newSpells)
    local changed = newSignature ~= oldSignature or BB.LocalProvider.state ~= "READY"

    BB.LocalSpells = newSpells
    provider.capabilities = newCapabilities
    provider.sources.localSpellbook = true

    BB.LocalProvider.state = "READY"

    if BB.RefreshReagentCounts then
        BB.RefreshReagentCounts()
    end

    if changed then
        BB.LocalProvider.generation = BB.LocalProvider.generation + 1
        BB.Debug.dirty = true
    end

    return true, changed
end

function BB.IsLocalProviderReady()
    return BB.LocalProvider.state == "READY"
end

function BB.RefreshProviderDependents(reason)
    if not BB.IsLocalProviderReady() then
        BB.State.executionQueue = {}
        if BB.UpdateMiniUI then
            BB.UpdateMiniUI()
        end
        BB.Debug.dirty = true
        return
    end

    BB.ImportLocalPallyPowerState()
    BB.BuildRawQueue()
    BB.Debug.dirty = true

    BB_Debug("Provider dependents refreshed (" .. tostring(reason) .. ")")
end

-- ============================================================================
-- PALLYPOWER COMPATIBILITY ADAPTER
--
-- Phase 1 is receive-only.
-- BuffBro never writes PallyPower globals.
-- ============================================================================

local function BB_ParseSelf(sender, msg)
    local _, _, numbers, assign = string.find(msg, "^SELF ([0-9n]*)@?([0-9n]*)")
    if not numbers then return false end

    local provider = BB_EnsureProviderByName(sender)
    if not provider then return false end

    provider.addon.pallyPower = true
    provider.sources.plpwr = true

    local id
    for id = 0, 5 do
        local rank = string.sub(numbers, id * 2 + 1, id * 2 + 1)
        local talent = string.sub(numbers, id * 2 + 2, id * 2 + 2)

        if rank and rank ~= "" and rank ~= "n" then
            provider.capabilities[id] = {
                rank = tonumber(rank) or 0,
                talent = tonumber(talent) or 0,
                source = "PLPWR_SELF",
            }
        else
            provider.capabilities[id] = nil
        end
    end

    if assign and assign ~= "" then
        for id = 0, 9 do
            local value = string.sub(assign, id + 1, id + 1)
            if value == "n" or value == "" then
                provider.assignments[id] = -1
            else
                provider.assignments[id] = tonumber(value) or -1
            end
        end
    end

    BB.BuildRawQueue()
    return true
end

local function BB_ParseAssign(sender, msg)
    local _, _, providerName, classText, skillText =
        string.find(msg, "^ASSIGN (.*) (.*) (.*)")
    if not providerName then return false end

    local provider = BB_EnsureProviderByName(providerName)
    if not provider then return false end

    provider.assignments[tonumber(classText)] = tonumber(skillText)
    provider.sources.plpwr = true

    BB.BuildRawQueue()
    return true
end

local function BB_ParseMassign(sender, msg)
    local _, _, providerName, skillText =
        string.find(msg, "^MASSIGN (.*) (.*)")
    if not providerName then return false end

    local provider = BB_EnsureProviderByName(providerName)
    if not provider then return false end

    local skill = tonumber(skillText)
    local classId
    for classId = 0, 9 do
        provider.assignments[classId] = skill
    end
    provider.sources.plpwr = true

    BB.BuildRawQueue()
    return true
end

function BB.OnPallyPowerMessage(sender, msg)
    if not sender or not msg then return end

    if string.find(msg, "^SELF ") then
        BB_ParseSelf(sender, msg)
        return
    end

    if string.find(msg, "^ASSIGN ") then
        BB_ParseAssign(sender, msg)
        return
    end

    if string.find(msg, "^MASSIGN ") then
        BB_ParseMassign(sender, msg)
        return
    end
end

-- Temporary Phase-1 bridge:
-- When BuffBro is deliberately run alongside PallyPower on the SAME client,
-- the client may not receive its own outgoing addon messages. Read-only import
-- lets us compare BuffBro's queue against the local PallyPower assignment UI.
--
-- This function is isolated compatibility code and is NOT BuffBro's future
-- assignment architecture.
function BB.ImportLocalPallyPowerState()
    local name = UnitName("player")
    local guid = BB_PlayerGuid()
    if not name or not guid then return end

    if not PallyPower_Assignments then return end

    local source = PallyPower_Assignments[name]
    if not source then return end

    local provider = BB_EnsureProvider(guid, name)
    if not provider then return end

    provider.addon.pallyPower = true
    provider.sources.localPallyPowerBridge = true

    local classId
    for classId = 0, 9 do
        if source[classId] ~= nil then
            provider.assignments[classId] = source[classId]
        end
    end

    -- Individual normal-Blessing overrides are local PallyPower state rather
    -- than part of the old SELF class-assignment payload. Import them only so
    -- the side-by-side prototype comparison is faithful.
    provider.individual = {}
    if PallyPower_NormalAssignments and PallyPower_NormalAssignments[name] then
        local classTable
        for classId, classTable in pairs(PallyPower_NormalAssignments[name]) do
            if type(classTable) == "table" then
                local targetName, family
                for targetName, family in pairs(classTable) do
                    provider.individual[targetName] = family
                end
            end
        end
    end

    -- If PallyPower already knows the local capability/talent table, enrich
    -- the local spellbook record with that compatibility information.
    if AllPallys and AllPallys[name] then
        local family
        for family = 0, 5 do
            local ppCap = AllPallys[name][family]
            if ppCap then
                provider.capabilities[family] = provider.capabilities[family] or {}
                provider.capabilities[family].rank = tonumber(ppCap.rank) or
                    provider.capabilities[family].rank or 0
                provider.capabilities[family].talent = tonumber(ppCap.talent) or 0
                provider.capabilities[family].source = "LOCAL_PP+SPELLBOOK"
            end
        end
    end
end

-- ============================================================================
-- DETECTION
-- ============================================================================

function BB.ScanUnitAuras(member)
    if not member or not member.unit then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end

    local buffs = {}
    local index = 1

    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(member.unit, index, "HELPFUL")
        if not aura then break end

        local family = BB.BuffNameToFamily[aura.name]
        if family ~= nil then
            buffs[family] = {
                present = true,
                name = aura.name,
                spellId = aura.spellId,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
                sourceUnit = aura.sourceUnit,
                sourceGUID = aura.sourceGUID,
                observedAt = GetTime(),
                source = "CLASSICAPI",
            }
        end

        index = index + 1

        -- Defensive ceiling only; active aura iteration should naturally end.
        if index > 64 then break end
    end

    BB.State.observations[member.guid] = {
        buffs = buffs,
        observedAt = GetTime(),
    }
end

function BB.ScanAllAuras()
    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local member = BB.State.roster[guid]
        if member then
            BB.ScanUnitAuras(member)
        end
    end

    BB.BuildRawQueue()
end

-- ============================================================================
-- RAW QUEUE
--
-- Raw means exactly that: no range, LoS, dead or disconnected filtering here.
-- Those belong to the later pre-flight/executor layer.
-- ============================================================================

local function BB_GetAssignedFamily(provider, member)
    if not provider or not member then return -1 end

    -- Local individual PallyPower override wins over class assignment.
    -- This exists for faithful Phase-1 side-by-side testing only.
    local override = provider.individual and provider.individual[member.name]
    if override ~= nil and override ~= -1 then
        return override, "INDIVIDUAL"
    end

    if member.ppClass == nil then return -1, nil end

    local family = provider.assignments[member.ppClass]
    if family == nil then return -1, nil end
    return family, "CLASS"
end

local function BB_HasFamily(guid, family)
    local obs = BB.State.observations[guid]
    if not obs or not obs.buffs then return false end
    local buff = obs.buffs[family]
    return buff and buff.present and true or false
end

function BB.BuildRawQueue()
    BB.State.rawQueue = {}

    if not BB.IsLocalProviderReady() then
        BB.State.executionQueue = {}
        if BB.UpdateMiniUI then
            BB.UpdateMiniUI()
        end
        BB.Debug.dirty = true
        return
    end

    local playerGuid = BB_PlayerGuid()
    local provider = playerGuid and BB.State.providers[playerGuid]
    if not provider then return end

    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local member = BB.State.roster[guid]
        if member then
            local family, assignmentType = BB_GetAssignedFamily(provider, member)
            if family ~= nil and family >= 0 and not BB_HasFamily(guid, family) then
                table.insert(BB.State.rawQueue, {
                    providerGUID = playerGuid,
                    providerName = provider.name,
                    targetGUID = member.guid,
                    targetName = member.name,
                    targetUnit = member.unit,
                    targetClass = member.class,
                    ppClass = member.ppClass,
                    family = family,
                    familyName = BB_FamilyName(family),
                    assignmentType = assignmentType,
                    createdAt = GetTime(),

                    -- Snapshot only for debugging.
                    -- These flags DO NOT determine raw-queue membership.
                    connected = member.connected,
                    dead = member.dead,
                })
            end
        end
    end

    BB.BuildExecutionQueue()
end

-- ============================================================================
-- PRE-FLIGHT / EXECUTION QUEUE
--
-- rawQueue is only the stable base missing-work set.
-- executionQueue is what the player experiences:
--   READY work first, expected failures afterwards.
--
-- IMPORTANT:
--   * Only KNOWN failures become blocked.
--   * Unknown range / unknown LoS remain READY.
--   * Blocked work stays in the queue; it is not discarded.
--   * Shift only overrides the CURRENT blocked job, never jumps elsewhere.
-- ============================================================================

local function BB_PreflightJob(job, castMode)
    local result = {
        actionable = true,
        status = "READY",
        reason = nil,
        range = "UNKNOWN",
        los = "UNKNOWN",
        checkedAt = GetTime(),
    }

    if not job or not job.targetGUID then
        result.actionable = false
        result.status = "INVALID"
        result.reason = "INVALID_JOB"
        return result
    end

    local member = BB.State.roster[job.targetGUID]
    if not member then
        result.actionable = false
        result.status = "INVALID"
        result.reason = "LEFT_ROSTER"
        return result
    end

    local unit = member.unit
    if not unit or not UnitExists(unit) then
        result.actionable = false
        result.status = "INVALID"
        result.reason = "NO_UNIT"
        return result
    end

    -- Refresh hard state at the instant of pre-flight.
    member.connected = UnitIsConnected(unit) and true or false
    member.dead = UnitIsDeadOrGhost(unit) and true or false

    if not member.connected then
        result.actionable = false
        result.status = "BLOCKED"
        result.reason = "OFFLINE"
        return result
    end

    if member.dead then
        result.actionable = false
        result.status = "BLOCKED"
        result.reason = "DEAD"
        return result
    end

    -- Resolve the exact spell this job would cast, then ask ClassicAPI for
    -- that spell's real engine range. This avoids the generic UnitInRange()
    -- group threshold (which is wider than Paladin Blessings).
    --
    -- C_Spell.IsSpellInRange returns true / false / nil:
    --   true  = the queued spell can reach this unit
    --   false = the queued spell is definitely out of range
    --   nil   = range cannot be determined / does not apply
    --
    -- UNKNOWN remains actionable; only a known false blocks SMART.
    local rangeSpell = BB.ResolveJobSpell and BB.ResolveJobSpell(job, castMode) or nil
    result.rangeSpellID = rangeSpell and rangeSpell.spellID or nil
    result.rangeSpellName = rangeSpell and rangeSpell.name or nil

    if rangeSpell and rangeSpell.spellID and
       C_Spell and C_Spell.IsSpellInRange then
        local inRange = C_Spell.IsSpellInRange(rangeSpell.spellID, unit)

        if inRange == true then
            result.range = "IN"
        elseif inRange == false then
            result.range = "OUT"
            result.actionable = false
            result.status = "BLOCKED"
            result.reason = "OUT_OF_RANGE"
            return result
        else
            result.range = "UNKNOWN"
        end
    else
        result.range = "UNKNOWN"
    end

    -- ClassicAPI UnitInLineOfSight returns true / false / nil.
    -- nil is UNKNOWN and must not be converted into a failure.
    if UnitInLineOfSight then
        local los = UnitInLineOfSight(unit)
        if los == true then
            result.los = "CLEAR"
        elseif los == false then
            result.los = "BLOCKED"
            result.actionable = false
            result.status = "BLOCKED"
            result.reason = "LOS_BLOCKED"
            return result
        else
            result.los = "UNKNOWN"
        end
    end

    return result
end

local function BB_JobKey(job)
    if not job then return nil end
    return tostring(job.providerGUID or "?") .. "|" ..
           tostring(job.targetGUID or "?") .. "|" ..
           tostring(job.family or "?") .. "|" ..
           tostring(job.assignmentType or "?")
end

local function BB_QueueSection(job)
    if job and job.preflight and job.preflight.actionable then
        return "READY"
    end
    return "BLOCKED"
end

local function BB_RotateJob(job)
    local key = BB_JobKey(job)
    if not key then return end

    BB.Queue.rotationCounter = (BB.Queue.rotationCounter or 0) + 1
    BB.Queue.rotation[key] = {
        order = BB.Queue.rotationCounter,
        section = BB_QueueSection(job),
    }
end

function BB.BuildExecutionQueue()
    BB.State.executionQueue = {}

    local activeKeys = {}
    local i, job

    for i, job in ipairs(BB.State.rawQueue) do
        job.baseOrder = i
        job.preflight = BB_PreflightJob(job, castMode)

        local key = BB_JobKey(job)
        job.queueKey = key
        activeKeys[key] = true

        local section = BB_QueueSection(job)
        local rotation = BB.Queue.rotation[key]

        -- A job that changes section (for example OUT_OF_RANGE -> READY)
        -- returns to its natural assignment order. Rotation only exists to
        -- progress past repeated attempts within the same section.
        if rotation and rotation.section ~= section then
            BB.Queue.rotation[key] = nil
            rotation = nil
        end

        job.rotationOrder = rotation and rotation.order or nil
        table.insert(BB.State.executionQueue, job)
    end

    -- Drop transient rotation data for work which no longer exists.
    local key
    for key in pairs(BB.Queue.rotation) do
        if not activeKeys[key] then
            BB.Queue.rotation[key] = nil
        end
    end

    table.sort(BB.State.executionQueue, function(a, b)
        local aReady = a.preflight and a.preflight.actionable
        local bReady = b.preflight and b.preflight.actionable

        if aReady ~= bReady then
            return aReady and true or false
        end

        local ar = a.rotationOrder
        local br = b.rotationOrder

        if ar and not br then return false end
        if br and not ar then return true end
        if ar and br and ar ~= br then return ar < br end

        return (a.baseOrder or 0) < (b.baseOrder or 0)
    end)

    BB.Debug.dirty = true

    if BB.UpdateMiniUI then
        BB.UpdateMiniUI()
    end
end

function BB.GetCurrentJob()
    return BB.State.executionQueue[1]
end

-- Compatibility aliases for old debug/internal calls while the prototype
-- evolves. They are deliberately NOT separate player-facing queues anymore.
BB.BuildActionableQueue = BB.BuildExecutionQueue

function BB.GetNextRawJob()
    return BB.State.rawQueue[1]
end

function BB.GetNextActionableJob()
    local _, job
    for _, job in ipairs(BB.State.executionQueue) do
        if job.preflight and job.preflight.actionable then
            return job
        end
    end
    return nil
end

function BB.GetNextJob()
    return BB.GetCurrentJob()
end

-- ============================================================================
-- MINI UI POSITION
-- ============================================================================

function BB.CreateCastCooldown()
    if BuffBroCastCooldown then return end
    if not BuffBroCastButton or not BuffBroCastCooldownAnchor then return end

    local cooldown = CreateFrame(
        "Model",
        "BuffBroCastCooldown",
        BuffBroCastButton,
        "CooldownFrameTemplate"
    )

    cooldown:SetWidth(36)
    cooldown:SetHeight(36)
    cooldown:SetPoint(
        "CENTER",
        BuffBroCastCooldownAnchor,
        "CENTER",
        0,
        0
    )
    cooldown:SetScale(26 / 36)
    cooldown:SetFrameLevel(BuffBroCastButton:GetFrameLevel() + 5)

    BuffBroCastCooldown = cooldown
    CooldownFrame_SetTimer(BuffBroCastCooldown, 0, 0, 0)
end

function BB.RestoreMiniPosition()
    if not BuffBroMiniFrame then return end

    BuffBroMiniFrame:ClearAllPoints()

    local pos = BuffBroDB and BuffBroDB.miniPosition
    if pos and pos.point and pos.relativePoint and pos.x and pos.y then
        BuffBroMiniFrame:SetPoint(
            pos.point,
            UIParent,
            pos.relativePoint,
            pos.x,
            pos.y
        )
    else
        BuffBroMiniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

function BB.SaveMiniPosition()
    if not BuffBroMiniFrame then return end

    local point, _, relativePoint, x, y = BuffBroMiniFrame:GetPoint(1)
    if not point then return end

    BuffBroDB = BuffBroDB or {}
    BuffBroDB.miniPosition = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

function BuffBro_MenuButton_OnMouseDown()
    if arg1 == "LeftButton" and IsControlKeyDown() then
        BB.UI.draggingMini = true
        BuffBroMiniFrame:StartMoving()
    end
end

function BuffBro_MenuButton_OnMouseUp()
    if BB.UI.draggingMini then
        BuffBroMiniFrame:StopMovingOrSizing()
        BB.UI.draggingMini = false
        BB.UI.suppressMenuClick = true
        BB.SaveMiniPosition()
    end
end

function BuffBro_MenuButton_OnClick()
    if BB.UI.suppressMenuClick then
        BB.UI.suppressMenuClick = false
        return
    end

    BuffBro_DebugToggle()
end

-- ============================================================================
-- EXECUTOR / MINI UI
--
-- 0.1.1 deliberately performs one cast per click.
-- Normal click casts the CURRENT READY job.
-- When CURRENT is an expected failure, Shift-click forces that same job.
-- ClassicAPI's C_Spell.CastAtUnit targets the unit directly without changing
-- the player's current target.
-- ============================================================================

function BB.RefreshReagentCounts()
    local counts = {}
    local needed = {}
    local family, kind, spell, _, reagent

    for family = 0, 5 do
        local familySpells = BB.LocalSpells[family]
        if familySpells then
            for _, kind in ipairs({ "normal", "greater" }) do
                spell = familySpells[kind]
                if spell and spell.reagents then
                    for _, reagent in ipairs(spell.reagents) do
                        if reagent.itemID and reagent.itemID > 0 then
                            needed[reagent.itemID] = true
                        end
                    end
                end
            end
        end
    end

    local itemID
    for itemID in pairs(needed) do
        if C_Item and C_Item.GetItemCount then
            counts[itemID] = C_Item.GetItemCount(itemID, false) or 0
        else
            counts[itemID] = 0
        end
    end

    BB.ReagentCounts = counts
end

function BB.HasSpellReagents(spell)
    if not spell then return false end
    if not spell.reagents or table.getn(spell.reagents) == 0 then
        return true
    end

    local _, reagent
    for _, reagent in ipairs(spell.reagents) do
        local have = BB.ReagentCounts[reagent.itemID] or 0
        local need = reagent.count or 1
        if have < need then
            return false
        end
    end

    return true
end

function BB.ResolveJobSpell(job, castMode)
    if not job then return nil end

    local familySpells = BB.LocalSpells[job.family]
    if not familySpells then return nil end

    -- PallyPower individual overrides are explicitly normal Blessings.
    if job.assignmentType == "INDIVIDUAL" then
        return familySpells.normal
    end

    if castMode == "NORMAL" then
        return familySpells.normal
    end

    -- AUTO / left-click:
    -- Greater only when learned AND its actual spell reagents are available.
    -- This is data-driven through ClassicAPI rather than hardcoding Symbols.
    if familySpells.greater and BB.HasSpellReagents(familySpells.greater) then
        return familySpells.greater
    end

    return familySpells.normal
end

local function BB_SetExecutorResult(status, job, spell, detail)
    BB.Executor.lastResult = {
        status = status,
        targetName = job and job.targetName or nil,
        familyName = job and job.familyName or nil,
        spellID = spell and spell.spellID or nil,
        spellName = spell and spell.name or nil,
        detail = detail,
        at = GetTime(),
    }
end

function BB.ExecuteNext(forceBlocked, castMode)
    BB.BuildExecutionQueue()

    local job = BB.GetCurrentJob()
    if not job then
        BB_SetExecutorResult("NO_JOB", nil, nil, nil)
        BB.UpdateMiniUI()
        return false
    end

    -- Always perform a fresh pre-flight at click time.
    job.preflight = BB_PreflightJob(job)

    -- Normal click never attempts a known expected failure.
    -- Shift-click only overrides THIS displayed blocked job.
    if not job.preflight.actionable and not forceBlocked then
        BB_SetExecutorResult(
            "BLOCKED",
            job,
            nil,
            job.preflight.reason
        )
        BB.UpdateMiniUI()
        return false
    end

    local forced = (not job.preflight.actionable) and forceBlocked and true or false

    local spell = BB.ResolveJobSpell(job, castMode)
    if not spell or not spell.spellID then
        BB_SetExecutorResult("NO_SPELL", job, spell, nil)
        BB.UpdateMiniUI()
        return false
    end

    local member = BB.State.roster[job.targetGUID]
    local unit = member and member.unit or job.targetUnit
    if not unit or not UnitExists(unit) then
        BB_SetExecutorResult("NO_UNIT", job, spell, nil)
        BB_RotateJob(job)
        BB.BuildExecutionQueue()
        return false
    end

    if not C_Spell or not C_Spell.CastAtUnit then
        BB_SetExecutorResult("NO_CAST_API", job, spell, nil)
        BB.UpdateMiniUI()
        return false
    end

    local accepted = C_Spell.CastAtUnit(spell.spellID, unit)

    if accepted then
        BB.Executor.pending = {
            job = job,
            spell = spell,
            spellID = spell.spellID,
            targetGUID = job.targetGUID,
            targetName = job.targetName,
            forcedBlocked = forced,
            castMode = castMode or "AUTO",
            startedAt = GetTime(),
        }
        BB_SetExecutorResult(
            forced and "CAST_SENT_FORCED" or "CAST_SENT",
            job,
            spell,
            job.preflight.reason
        )
    else
        -- Immediate rejection should never stall the queue. Keep the same
        -- classification, but rotate this job behind its peers in that section.
        BB.Executor.pending = nil
        BB_SetExecutorResult(
            forced and "FORCED_REJECTED" or "CAST_REJECTED",
            job,
            spell,
            job.preflight.reason
        )
        BB_RotateJob(job)
        BB.BuildExecutionQueue()
    end

    BB.UpdateMiniUI()
    return accepted
end

function BuffBro_CastButton_OnClick(button)
    button = button or arg1

    local castMode = "AUTO"
    if button == "RightButton" then
        castMode = "NORMAL"
    end

    BB.ExecuteNext(IsShiftKeyDown() and true or false, castMode)
end

local function BB_UpdateCastBorder(job)
    local color = job and BB.ClassColors[job.targetClass]
    local r, g, b = 0.65, 0.65, 0.65
    if color then r, g, b = color[1], color[2], color[3] end

    if BuffBroCastBorderTop then BuffBroCastBorderTop:SetVertexColor(r, g, b) end
    if BuffBroCastBorderBottom then BuffBroCastBorderBottom:SetVertexColor(r, g, b) end
    if BuffBroCastBorderLeft then BuffBroCastBorderLeft:SetVertexColor(r, g, b) end
    if BuffBroCastBorderRight then BuffBroCastBorderRight:SetVertexColor(r, g, b) end
end

local function BB_UpdateCastCooldown(job, spell)
    if not BuffBroCastCooldown then return end

    -- Use the dedicated GCD probe spell instead of the queued Blessing.
    local info = nil
    if C_Spell and C_Spell.GetSpellCooldown then
        info = C_Spell.GetSpellCooldown(BB.GCD_SPELL_ID)
    end

    if info and info.startTime and info.duration and
       info.startTime > 0 and info.duration > 0 and info.isEnabled ~= false then
        CooldownFrame_SetTimer(
            BuffBroCastCooldown,
            info.startTime,
            info.duration,
            1
        )
    else
        CooldownFrame_SetTimer(BuffBroCastCooldown, 0, 0, 0)
    end
end

local function BB_BlockReasonLabel(reason)
    if reason == "OUT_OF_RANGE" then return "R" end
    if reason == "LOS_BLOCKED" then return "LoS" end
    if reason == "DEAD" then return "DEAD" end
    if reason == "OFFLINE" then return "DC" end
    if reason == "LEFT_ROSTER" or reason == "NO_UNIT" then return "?" end
    return "!"
end

local function BB_BlockReasonText(reason)
    if reason == "OUT_OF_RANGE" then return "Out of range" end
    if reason == "LOS_BLOCKED" then return "Line of sight blocked" end
    if reason == "DEAD" then return "Target is dead" end
    if reason == "OFFLINE" then return "Target is offline" end
    if reason == "LEFT_ROSTER" then return "Target left roster" end
    if reason == "NO_UNIT" then return "No current unit" end
    return tostring(reason or "Expected failure")
end

function BB.UpdateMiniUI()
    if not BuffBroMiniFrame or not BuffBroCastButton or not BuffBroCastIcon then
        return
    end

    local job = BB.GetCurrentJob()

    if not job then
        BuffBroCastIcon:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
        BuffBroCastIcon:SetVertexColor(0.45, 0.45, 0.45)
        BuffBroCastButton:Disable()
        if BuffBroStatusButton then BuffBroStatusButton:Hide() end
        BB_UpdateCastBorder(nil)
        BB_UpdateCastCooldown(nil, nil)
        if BB.RenderCastTooltip then
            BB.RenderCastTooltip()
        end
        return
    end

    local spell = BB.ResolveJobSpell(job)
    if spell and spell.icon then
        BuffBroCastIcon:SetTexture(spell.icon)
    else
        BuffBroCastIcon:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
    end

    BB_UpdateCastBorder(job)
    BB_UpdateCastCooldown(job, spell)

    BuffBroCastIcon:SetVertexColor(1, 1, 1)
    BuffBroCastButton:Enable()

    if job.preflight and not job.preflight.actionable then
        if BuffBroStatusButton then
            BuffBroStatusButton:SetText(BB_BlockReasonLabel(job.preflight.reason))
            BuffBroStatusButton:Show()
        end
    else
        if BuffBroStatusButton then BuffBroStatusButton:Hide() end
    end

    if BB.RenderCastTooltip then
        BB.RenderCastTooltip()
    end
end

function BB.RenderCastTooltip()
    if not BB.UI.castHover or not BuffBroCastButton then return end

    local job = BB.GetCurrentJob()
    GameTooltip:SetOwner(BuffBroCastButton, "ANCHOR_RIGHT")

    if not BB.IsLocalProviderReady() then
        GameTooltip:SetText("BuffBro", 1, 1, 1)
        GameTooltip:AddLine(
            "Provider state: " .. tostring(BB.LocalProvider.state),
            0.8, 0.8, 0.8
        )
        GameTooltip:Show()
        return
    end

    if not job then
        GameTooltip:SetText("BuffBro", 1, 1, 1)
        GameTooltip:AddLine("No missing assigned buffs.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    end

    local spell = BB.ResolveJobSpell(job, "AUTO")
    GameTooltip:SetText(spell and spell.name or job.familyName, 1, 1, 1)
    GameTooltip:AddLine(tostring(job.targetName), 0.8, 0.8, 0.8)

    local familySpells = BB.LocalSpells[job.family]
    if job.assignmentType ~= "INDIVIDUAL" and familySpells and familySpells.normal then
        if familySpells.greater then
            if BB.HasSpellReagents(familySpells.greater) then
                GameTooltip:AddLine("Left-click: Greater Blessing", 0.7, 0.9, 0.7)
            else
                GameTooltip:AddLine("Left-click: normal (no Greater reagent)", 1, 0.75, 0.3)
            end
        end
        GameTooltip:AddLine("Right-click: normal Blessing", 0.75, 0.75, 0.9)
    end

    if job.preflight and not job.preflight.actionable then
        GameTooltip:AddLine(
            BB_BlockReasonText(job.preflight.reason),
            1, 0.4, 0.4
        )
        GameTooltip:AddLine(
            "Shift-click to attempt anyway.",
            0.8, 0.8, 0.8
        )
    end

    GameTooltip:Show()
end

function BuffBro_CastButton_OnEnter()
    BB.UI.castHover = true
    BB.RenderCastTooltip()
end

function BuffBro_CastButton_OnLeave()
    BB.UI.castHover = false
    GameTooltip:Hide()
end

function BuffBro_StatusButton_OnEnter()
    if not BuffBroStatusButton then return end

    local job = BB.GetCurrentJob()
    GameTooltip:SetOwner(BuffBroStatusButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Expected failure", 1, 1, 1)

    if job and job.preflight then
        GameTooltip:AddLine(
            BB_BlockReasonText(job.preflight.reason),
            1, 0.4, 0.4
        )
        GameTooltip:AddLine(
            tostring(job.targetName or ""),
            0.8, 0.8, 0.8
        )
        GameTooltip:AddLine(
            "Shift-click the buff to force an attempt.",
            0.8, 0.8, 0.8
        )
    end

    GameTooltip:Show()
end

function BuffBro_StatusButton_OnLeave()
    GameTooltip:Hide()
end

local function BB_ExecutorSpellEvent(event, unit, castGUID, spellID, spellName, rank)
    local pending = BB.Executor.pending
    if not pending then return end
    if unit ~= "player" then return end
    if tonumber(spellID) ~= tonumber(pending.spellID) then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        BB_SetExecutorResult("SUCCEEDED", pending.job, pending.spell, castGUID)
        BB.Executor.pending = nil
        BB.UpdateMiniUI()

        -- Give the aura state a moment to land, then let Detection rebuild
        -- the queues. UNIT_AURA normally beats this; this is cheap insurance.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, function()
                BB.ScanAllAuras()
                BB.UpdateMiniUI()
            end)
        else
            BB.ScanAllAuras()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or
           event == "UNIT_SPELLCAST_FAILED_QUIET" or
           event == "UNIT_SPELLCAST_INTERRUPTED" then
        BB_SetExecutorResult(event, pending.job, pending.spell, castGUID)
        BB.Executor.pending = nil

        -- Whether this was a rare READY failure or a forced expected failure,
        -- never let the same job stall progression. Rotate it behind peers in
        -- its current section and present the next job.
        BB_RotateJob(pending.job)
        BB.BuildExecutionQueue()
    end
end

-- ============================================================================
-- DEBUG WINDOW
-- ============================================================================

local function BB_DebugLine(lines, text)
    table.insert(lines, tostring(text or ""))
end

local function BB_DebugRosterText()
    local lines = {}
    BB_DebugLine(lines, "ROSTER  mode=" .. BB.State.mode ..
        "  members=" .. tostring(BB_CountTable(BB.State.roster)))
    BB_DebugLine(lines, "")

    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local m = BB.State.roster[guid]
        if m then
            BB_DebugLine(lines,
                tostring(m.unit) .. "  " ..
                tostring(m.name) .. "  " ..
                tostring(m.class) ..
                "  connected=" .. tostring(m.connected) ..
                "  dead=" .. tostring(m.dead))
            BB_DebugLine(lines, "  GUID: " .. tostring(m.guid))
        end
    end

    return table.concat(lines, "\n")
end

local function BB_DebugProvidersText()
    local lines = {}
    BB_DebugLine(lines, "PROVIDERS  count=" .. tostring(BB_CountTable(BB.State.providers)))
    BB_DebugLine(lines,
        "Local provider: " .. tostring(BB.LocalProvider.state) ..
        "  blessings=" .. tostring(BB.LocalProvider.blessingCount) ..
        "  resolved=" .. tostring(BB.LocalProvider.resolvedSpellCount) ..
        "  generation=" .. tostring(BB.LocalProvider.generation))
    BB_DebugLine(lines, "")

    local _, p
    for _, p in pairs(BB.State.providers) do
        BB_DebugLine(lines,
            tostring(p.name) ..
            "  PP=" .. tostring(p.addon.pallyPower) ..
            "  unit=" .. tostring(p.unit))

        local family
        for family = 0, 5 do
            local cap = p.capabilities[family]
            if cap then
                BB_DebugLine(lines,
                    "  " .. BB_FamilyName(family) ..
                    "  rank=" .. tostring(cap.rank) ..
                    "  talent=" .. tostring(cap.talent) ..
                    "  source=" .. tostring(cap.source))
            end
        end
        BB_DebugLine(lines, "")
    end

    return table.concat(lines, "\n")
end

local function BB_DebugAssignmentsText()
    local lines = {}
    BB_DebugLine(lines, "ASSIGNMENTS")
    BB_DebugLine(lines, "")

    local _, p
    for _, p in pairs(BB.State.providers) do
        BB_DebugLine(lines, "Provider: " .. tostring(p.name))

        local any = false
        local classId
        for classId = 0, 9 do
            local family = p.assignments[classId]
            if family ~= nil and family >= 0 then
                any = true
                BB_DebugLine(lines,
                    "  " .. tostring(BB.PPClassName[classId]) ..
                    " -> " .. BB_FamilyName(family))
            end
        end

        local targetName, family
        for targetName, family in pairs(p.individual or {}) do
            if family ~= nil and family >= 0 then
                any = true
                BB_DebugLine(lines,
                    "  " .. tostring(targetName) ..
                    " -> " .. BB_FamilyName(family) ..
                    "  (individual)")
            end
        end

        if not any then
            BB_DebugLine(lines, "  (none)")
        end
        BB_DebugLine(lines, "")
    end

    return table.concat(lines, "\n")
end

local function BB_DebugAurasText()
    local lines = {}
    BB_DebugLine(lines, "DETECTED BLESSINGS")
    BB_DebugLine(lines, "")

    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local m = BB.State.roster[guid]
        local obs = BB.State.observations[guid]

        if m then
            BB_DebugLine(lines, tostring(m.name))

            local found = false
            if obs and obs.buffs then
                local family
                for family = 0, 5 do
                    local b = obs.buffs[family]
                    if b then
                        found = true
                        local remaining = "unknown"
                        if b.expirationTime and b.expirationTime > 0 then
                            remaining = tostring(math.max(0, math.floor(b.expirationTime - GetTime()))) .. "s"
                        end

                        BB_DebugLine(lines,
                            "  " .. BB_FamilyName(family) ..
                            "  remaining=" .. remaining ..
                            "  spellId=" .. tostring(b.spellId))
                        BB_DebugLine(lines,
                            "    casterGUID=" .. tostring(b.sourceGUID))
                    end
                end
            end

            if not found then
                BB_DebugLine(lines, "  (none)")
            end

            BB_DebugLine(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

local function BB_DebugQueueText()
    local lines = {}

    BB_DebugLine(lines,
        "EXECUTION QUEUE  jobs=" ..
        tostring(table.getn(BB.State.executionQueue)))
    BB_DebugLine(lines, "")
    BB_DebugLine(lines, "READY jobs are ordered first; expected failures follow.")
    BB_DebugLine(lines, "")

    local i, job
    for i, job in ipairs(BB.State.executionQueue) do
        local p = job.preflight or {}
        local stateText

        if p.actionable then
            stateText = "READY"
        else
            stateText = tostring(p.reason or p.status or "BLOCKED")
        end

        BB_DebugLine(lines,
            tostring(i) .. ". " ..
            tostring(job.targetName) ..
            " -> " .. tostring(job.familyName) ..
            "  [" .. stateText .. "]")

        BB_DebugLine(lines,
            "   base=" .. tostring(job.baseOrder or "?") ..
            "  range=" .. tostring(p.range or "UNKNOWN") ..
            "  los=" .. tostring(p.los or "UNKNOWN"))

        if p.rangeSpellName then
            BB_DebugLine(lines,
                "   range spell=" .. tostring(p.rangeSpellName) ..
                " (" .. tostring(p.rangeSpellID or "?") .. ")")
        end

        if job.rotationOrder then
            BB_DebugLine(lines,
                "   rotated=" .. tostring(job.rotationOrder))
        end
    end

    if table.getn(BB.State.executionQueue) == 0 then
        BB_DebugLine(lines, "(empty)")
    end

    BB_DebugLine(lines, "")
    local current = BB.GetCurrentJob()
    if current then
        local stateText = current.preflight and
            (current.preflight.actionable and "READY" or
             tostring(current.preflight.reason or "BLOCKED")) or "UNKNOWN"

        BB_DebugLine(lines,
            "CURRENT: " ..
            tostring(current.targetName) ..
            " -> " .. tostring(current.familyName) ..
            "  [" .. stateText .. "]")
    else
        BB_DebugLine(lines, "CURRENT: (none)")
    end

    BB_DebugLine(lines, "")
    local last = BB.Executor.lastResult
    if last then
        BB_DebugLine(lines,
            "EXECUTOR: " .. tostring(last.status) ..
            "  " .. tostring(last.targetName or "") ..
            "  " .. tostring(last.spellName or last.familyName or ""))
        if last.detail then
            BB_DebugLine(lines, "  detail=" .. tostring(last.detail))
        end
    else
        BB_DebugLine(lines, "EXECUTOR: (no cast attempted)")
    end

    return table.concat(lines, "\n")
end

local function BuffBro_DebugTextForView(view)
    if view == "roster" then
        return BB_DebugRosterText()
    elseif view == "providers" then
        return BB_DebugProvidersText()
    elseif view == "assignments" then
        return BB_DebugAssignmentsText()
    elseif view == "auras" then
        return BB_DebugAurasText()
    else
        BB.Debug.view = "queue"
        return BB_DebugQueueText()
    end
end

function BuffBro_DebugRender(view)
    if not BuffBroDebugFrame or not BuffBroDebugText then return end

    view = view or BB.Debug.view or "queue"
    BB.Debug.view = view
    BuffBroDebugText:SetText(BuffBro_DebugTextForView(view) or "")
    BB.Debug.dirty = false
end

function BuffBro_DebugShow(view)
    if not BuffBroDebugFrame or not BuffBroDebugText then return end

    view = view or "queue"
    BB.Debug.view = view

    -- Explicit tab selection may force reconciliation during development.
    -- Merely rendering an already-open tab never performs discovery.
    if view == "assignments" or view == "queue" then
        BB.ImportLocalPallyPowerState()
    end
    if view == "auras" or view == "queue" then
        BB.ScanAllAuras()
    end

    BuffBro_DebugRender(view)
    BuffBroDebugScrollFrame:SetVerticalScroll(0)
    BuffBroDebugFrame:Show()
end

function BuffBro_DebugToggle()
    if not BuffBroDebugFrame then return end

    if BuffBroDebugFrame:IsShown() then
        BuffBroDebugFrame:Hide()
    else
        BuffBro_DebugShow(BB.Debug.view or "queue")
    end
end

-- ============================================================================
-- DEBUG / TEST OUTPUT
-- ============================================================================

function BB.DebugRoster()
    BB_Print("Roster: mode=" .. BB.State.mode ..
        ", members=" .. tostring(BB_CountTable(BB.State.roster)))

    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local m = BB.State.roster[guid]
        if m then
            BB_Print("  " .. tostring(m.unit) .. "  " .. tostring(m.name) ..
                "  " .. tostring(m.class) ..
                "  guid=" .. tostring(m.guid) ..
                "  connected=" .. tostring(m.connected) ..
                "  dead=" .. tostring(m.dead))
        end
    end
end

function BB.DebugProviders()
    BB_Print("Providers: " .. tostring(BB_CountTable(BB.State.providers)))

    local _, p
    for _, p in pairs(BB.State.providers) do
        BB_Print("  " .. tostring(p.name) ..
            "  PP=" .. tostring(p.addon.pallyPower) ..
            "  unit=" .. tostring(p.unit))

        local family
        for family = 0, 5 do
            local cap = p.capabilities[family]
            if cap then
                BB_Print("    " .. BB_FamilyName(family) ..
                    " rank=" .. tostring(cap.rank) ..
                    " talent=" .. tostring(cap.talent) ..
                    " source=" .. tostring(cap.source))
            end
        end
    end
end

function BB.DebugAssignments()
    BB_Print("Assignments:")

    local _, p
    for _, p in pairs(BB.State.providers) do
        BB_Print("  Provider " .. tostring(p.name))
        local classId
        for classId = 0, 9 do
            local family = p.assignments[classId]
            if family ~= nil and family >= 0 then
                BB_Print("    " .. tostring(BB.PPClassName[classId]) ..
                    " -> " .. BB_FamilyName(family))
            end
        end

        local targetName, family
        for targetName, family in pairs(p.individual or {}) do
            if family ~= nil and family >= 0 then
                BB_Print("    individual " .. tostring(targetName) ..
                    " -> " .. BB_FamilyName(family))
            end
        end
    end
end

function BB.DebugAuras()
    BB_Print("Detected Blessings:")

    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local m = BB.State.roster[guid]
        local obs = BB.State.observations[guid]
        if m then
            BB_Print("  " .. tostring(m.name))
            local found = false
            if obs and obs.buffs then
                local family
                for family = 0, 5 do
                    local b = obs.buffs[family]
                    if b then
                        found = true
                        local remaining = "?"
                        if b.expirationTime and b.expirationTime > 0 then
                            remaining = math.max(0, math.floor(b.expirationTime - GetTime()))
                        end
                        BB_Print("    " .. BB_FamilyName(family) ..
                            " spellId=" .. tostring(b.spellId) ..
                            " remaining=" .. tostring(remaining) ..
                            " caster=" .. tostring(b.sourceGUID))
                    end
                end
            end
            if not found then BB_Print("    (none)") end
        end
    end
end

function BB.DebugQueue()
    BB_Print("RAW queue: " .. tostring(table.getn(BB.State.rawQueue)))

    local i, job
    for i, job in ipairs(BB.State.rawQueue) do
        BB_Print("  " .. tostring(i) .. ". " ..
            tostring(job.targetName) .. " -> " ..
            tostring(job.familyName) ..
            "  connected=" .. tostring(job.connected) ..
            "  dead=" .. tostring(job.dead))
    end
end

function BB.DebugAll()
    BB.DebugRoster()
    BB.DebugProviders()
    BB.DebugAssignments()
    BB.DebugAuras()
    BB.DebugQueue()
end

local function BB_Slash(msg)
    msg = string.lower(msg or "")

    if msg == "" or msg == "help" then
        BB_Print("0.1.0-test1 commands:")
        BB_Print("  /bb roster")
        BB_Print("  /bb providers")
        BB_Print("  /bb assignments")
        BB_Print("  /bb auras")
        BB_Print("  /bb queue")
        BB_Print("  /bb debug   (open debug window)")
        BB_Print("  /bb refresh")
        BB_Print("  /bb trace   (toggle quiet debug messages)")
        return
    end

    if msg == "debug" then
        BuffBro_DebugToggle()
    elseif msg == "roster" then
        BuffBro_DebugShow("roster")
    elseif msg == "providers" then
        BuffBro_DebugShow("providers")
    elseif msg == "assignments" then
        BuffBro_DebugShow("assignments")
    elseif msg == "auras" then
        BuffBro_DebugShow("auras")
    elseif msg == "queue" then
        BuffBro_DebugShow("queue")
    elseif msg == "all" then
        BuffBro_DebugShow("queue")
    elseif msg == "refresh" then
        BB.RebuildRoster("slash")
        BB_Print("State refreshed.")
    elseif msg == "trace" then
        BB.Debug.enabled = not BB.Debug.enabled
        BB_Print("Trace " .. (BB.Debug.enabled and "ON" or "OFF"))
    else
        BB_Print("Unknown command. Use /bb help")
    end
end

-- ============================================================================
-- UI CONSTRUCTION
-- ============================================================================
--
-- The original prototype defined these frames in BuffBro.xml. Keep the named
-- globals while existing runtime code still addresses them directly, but make
-- BuffBro.lua the single runtime implementation source.
function BB.CreateUI()
    local frame, button, texture, scrollChild, fontString

    frame = CreateFrame("Frame", "BuffBroEventFrame")
    frame:SetScript("OnLoad", BuffBro_OnLoad)
    frame:SetScript("OnEvent", function()
        BuffBro_OnEvent(event, arg1, arg2, arg3, arg4)
    end)
    frame:SetScript("OnUpdate", function()
        BuffBro_OnUpdate(arg1)
    end)
    BB.UI.eventFrame = frame

    frame = CreateFrame("Frame", "BuffBroDebugFrame", UIParent)
    frame:SetWidth(620)
    frame:SetHeight(430)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            BuffBroDebugFrame:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function()
        BuffBroDebugFrame:StopMovingOrSizing()
    end)
    BB.UI.debugFrame = frame

    fontString = frame:CreateFontString(
        "BuffBroDebugTitle",
        "ARTWORK",
        "GameFontNormalLarge"
    )
    fontString:SetText("BuffBro Debug")
    fontString:SetPoint("TOP", frame, "TOP", 0, -16)

    fontString = frame:CreateFontString(
        "BuffBroDebugSubtitle",
        "ARTWORK",
        "GameFontHighlightSmall"
    )
    fontString:SetText("Backend / execution queue / executor state")
    fontString:SetPoint("TOP", BuffBroDebugTitle, "BOTTOM", 0, -2)

    button = CreateFrame(
        "Button",
        "BuffBroDebugClose",
        frame,
        "UIPanelCloseButton"
    )
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    button = CreateFrame(
        "Button",
        "BuffBroDebugRosterButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(82)
    button:SetHeight(22)
    button:SetText("Roster")
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    button:SetScript("OnClick", function()
        BuffBro_DebugShow("roster")
    end)

    button = CreateFrame(
        "Button",
        "BuffBroDebugProvidersButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(82)
    button:SetHeight(22)
    button:SetText("Providers")
    button:SetPoint("LEFT", BuffBroDebugRosterButton, "RIGHT", 4, 0)
    button:SetScript("OnClick", function()
        BuffBro_DebugShow("providers")
    end)

    button = CreateFrame(
        "Button",
        "BuffBroDebugAssignmentsButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(90)
    button:SetHeight(22)
    button:SetText("Assignments")
    button:SetPoint("LEFT", BuffBroDebugProvidersButton, "RIGHT", 4, 0)
    button:SetScript("OnClick", function()
        BuffBro_DebugShow("assignments")
    end)

    button = CreateFrame(
        "Button",
        "BuffBroDebugAurasButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(72)
    button:SetHeight(22)
    button:SetText("Auras")
    button:SetPoint("LEFT", BuffBroDebugAssignmentsButton, "RIGHT", 4, 0)
    button:SetScript("OnClick", function()
        BuffBro_DebugShow("auras")
    end)

    button = CreateFrame(
        "Button",
        "BuffBroDebugQueueButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(72)
    button:SetHeight(22)
    button:SetText("Queue")
    button:SetPoint("LEFT", BuffBroDebugAurasButton, "RIGHT", 4, 0)
    button:SetScript("OnClick", function()
        BuffBro_DebugShow("queue")
    end)

    button = CreateFrame(
        "Button",
        "BuffBroDebugRefreshButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(78)
    button:SetHeight(22)
    button:SetText("Refresh")
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -48)
    button:SetScript("OnClick", function()
        BuffBro.ScanLocalProvider("debug")
        BuffBro.RebuildRoster("debug")
        BuffBro_DebugRender(BuffBro.Debug.view or "queue")
    end)

    button = CreateFrame(
        "ScrollFrame",
        "BuffBroDebugScrollFrame",
        frame,
        "UIPanelScrollFrameTemplate"
    )
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -82)
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -44, 22)

    scrollChild = CreateFrame("Frame", "BuffBroDebugScrollChild", button)
    scrollChild:SetWidth(540)
    scrollChild:SetHeight(1200)
    button:SetScrollChild(scrollChild)

    fontString = scrollChild:CreateFontString(
        "BuffBroDebugText",
        "ARTWORK",
        "GameFontHighlightSmall"
    )
    fontString:SetWidth(530)
    fontString:SetHeight(1180)
    fontString:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")

    frame:Hide()

    frame = CreateFrame("Frame", "BuffBroMiniFrame", UIParent)
    frame:SetWidth(102)
    frame:SetHeight(32)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    BB.UI.miniFrame = frame

    button = CreateFrame(
        "Button",
        "BuffBroMenuButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(34)
    button:SetHeight(30)
    button:SetText("BB")
    button:SetPoint("LEFT", frame, "LEFT", 0, 0)
    button:SetScript("OnClick", function()
        BuffBro_MenuButton_OnClick()
    end)
    button:SetScript("OnMouseDown", function()
        BuffBro_MenuButton_OnMouseDown()
    end)
    button:SetScript("OnMouseUp", function()
        BuffBro_MenuButton_OnMouseUp()
    end)
    BB.UI.menuButton = button

    button = CreateFrame("Button", "BuffBroCastButton", frame)
    button:SetWidth(30)
    button:SetHeight(30)
    button:SetPoint("LEFT", BuffBroMenuButton, "RIGHT", 4, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function()
        BuffBro_CastButton_OnClick(arg1)
    end)
    button:SetScript("OnEnter", function()
        BuffBro_CastButton_OnEnter()
    end)
    button:SetScript("OnLeave", function()
        BuffBro_CastButton_OnLeave()
    end)
    BB.UI.castButton = button

    texture = button:CreateTexture("BuffBroCastIcon", "ARTWORK")
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    texture = button:CreateTexture("BuffBroCastBorderTop", "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetWidth(30)
    texture:SetHeight(2)
    texture:SetPoint("TOP", button, "TOP", 0, 0)

    texture = button:CreateTexture("BuffBroCastBorderBottom", "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetWidth(30)
    texture:SetHeight(2)
    texture:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)

    texture = button:CreateTexture("BuffBroCastBorderLeft", "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetWidth(2)
    texture:SetHeight(26)
    texture:SetPoint("LEFT", button, "LEFT", 0, 0)

    texture = button:CreateTexture("BuffBroCastBorderRight", "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetWidth(2)
    texture:SetHeight(26)
    texture:SetPoint("RIGHT", button, "RIGHT", 0, 0)

    scrollChild = CreateFrame("Frame", "BuffBroCastCooldownAnchor", button)
    scrollChild:SetWidth(26)
    scrollChild:SetHeight(26)
    scrollChild:SetPoint("CENTER", BuffBroCastIcon, "CENTER", 0, 0)

    button = CreateFrame(
        "Button",
        "BuffBroStatusButton",
        frame,
        "UIPanelButtonTemplate"
    )
    button:SetWidth(30)
    button:SetHeight(22)
    button:SetPoint("LEFT", BuffBroCastButton, "RIGHT", 4, 0)
    button:SetScript("OnEnter", function()
        BuffBro_StatusButton_OnEnter()
    end)
    button:SetScript("OnLeave", function()
        BuffBro_StatusButton_OnLeave()
    end)
    button:Hide()
    BB.UI.statusButton = button
end

-- ============================================================================
-- EVENTS / LIFECYCLE
-- ============================================================================

function BuffBro_OnLoad()
    if not BB.CheckClassicAPI() then
        BB_Print("|cffff4444ClassicAPI required: expected UnitGUID + C_UnitAuras API not found.|r")
        return
    end

    BuffBroEventFrame:RegisterEvent("PLAYER_LOGIN")
    BuffBroEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    BuffBroEventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    BuffBroEventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    BuffBroEventFrame:RegisterEvent("UNIT_AURA")
    BuffBroEventFrame:RegisterEvent("UNIT_FLAGS")
    BuffBroEventFrame:RegisterEvent("UNIT_CONNECTION")
    BuffBroEventFrame:RegisterEvent("SPELLS_CHANGED")
    BuffBroEventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    BuffBroEventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    BuffBroEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    BuffBroEventFrame:RegisterEvent("CHAT_MSG_ADDON")
    BuffBroEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    BuffBroEventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    BuffBroEventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
    BuffBroEventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

    SLASH_BUFFBRO1 = "/bb"
    SLASH_BUFFBRO2 = "/buffbro"
    SlashCmdList["BUFFBRO"] = BB_Slash

    BB._reconcileElapsed = 0

    if BuffBroDebugTitle then
        BuffBroDebugTitle:SetText("BuffBro Debug v" .. tostring(BB.VERSION))
    end
    BB.UpdateMiniUI()
    BB_Print("v" .. BB.VERSION .. " loaded. /bb debug")
end

function BuffBro_OnEvent(event, arg1, arg2, arg3, arg4)
    if not BB.classicAPIReady then return end

    if event == "PLAYER_LOGIN" then
        BB.RestoreMiniPosition()
        BB.CreateCastCooldown()

        local ready, changed = BB.ScanLocalProvider(event)
        if ready and changed then
            BB.RefreshProviderDependents(event)
        end
        BB.Debug.dirty = true
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" or
       event == "ACTIONBAR_UPDATE_COOLDOWN" then
        BB.UpdateMiniUI()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        BB.RefreshReagentCounts()

        -- Reagent availability can change AUTO from Greater -> normal or back.
        -- Rebuild pre-flight because custom servers may give those spells
        -- different ranges.
        if BB.IsLocalProviderReady() then
            BB.BuildExecutionQueue()
        else
            BB.UpdateMiniUI()
        end
        return
    end

    if event == "SPELLS_CHANGED" then
        local ready, changed = BB.ScanLocalProvider(event)

        -- SPELLS_CHANGED is the authoritative spellbook lifecycle signal.
        -- Only propagate downstream when provider data actually changed.
        if ready and changed then
            BB.RefreshProviderDependents(event)
        elseif not ready then
            BB.State.executionQueue = {}
            BB.UpdateMiniUI()
        end

        BB.Debug.dirty = true
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or
       event == "PARTY_MEMBERS_CHANGED" or
       event == "RAID_ROSTER_UPDATE" then
        BB.RebuildRoster(event)
        return
    end

    if event == "UNIT_AURA" then
        local unit = arg1
        if unit and UnitExists(unit) then
            local guid = BB_SafeGuid(unit)
            local member = guid and BB.State.roster[guid]
            if member then
                BB.ScanUnitAuras(member)
                BB.BuildRawQueue()
            end
        end
        return
    end

    if event == "UNIT_FLAGS" or event == "UNIT_CONNECTION" then
        local unit = arg1
        if unit and UnitExists(unit) then
            local guid = BB_SafeGuid(unit)
            local member = guid and BB.State.roster[guid]
            if member then
                member.connected = UnitIsConnected(unit) and true or false
                member.dead = UnitIsDeadOrGhost(unit) and true or false
                if BB.IsLocalProviderReady() then
                    BB.BuildExecutionQueue()
                end
                BB.Debug.dirty = true
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" or
       event == "UNIT_SPELLCAST_FAILED" or
       event == "UNIT_SPELLCAST_FAILED_QUIET" or
       event == "UNIT_SPELLCAST_INTERRUPTED" then
        BB_ExecutorSpellEvent(event, arg1, arg2, arg3, arg4, nil)
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix = arg1
        local msg = arg2
        local channel = arg3
        local sender = arg4

        if prefix == BB.PP_PREFIX then
            BB.OnPallyPowerMessage(sender, msg)
        end
        return
    end
end

function BuffBro_OnUpdate(elapsed)
    if not BB.classicAPIReady then return end

    if BuffBroDebugFrame and BuffBroDebugFrame:IsShown() and BB.Debug.dirty then
        BuffBro_DebugRender(BB.Debug.view or "queue")
    end

    BB._reconcileElapsed = (BB._reconcileElapsed or 0) + (elapsed or 0)
    if BB._reconcileElapsed < BB.RECONCILE_SECONDS then return end
    BB._reconcileElapsed = 0

    -- Slow insurance pass:
    --  * catches remote aura changes that do not produce the expected event
    --  * refreshes connection/death snapshots
    --  * re-imports local PallyPower assignments during side-by-side testing
    --
    -- No per-frame full-roster scan.
    local _, guid
    for _, guid in ipairs(BB.State.rosterOrder) do
        local member = BB.State.roster[guid]
        if member and member.unit and UnitExists(member.unit) then
            member.connected = UnitIsConnected(member.unit) and true or false
            member.dead = UnitIsDeadOrGhost(member.unit) and true or false
        end
    end

    BB.ScanAllAuras()

    if BB.IsLocalProviderReady() then
        BB.ImportLocalPallyPowerState()
        BB.BuildRawQueue()
    end
end

BB.CreateUI()
BuffBro_OnLoad()
