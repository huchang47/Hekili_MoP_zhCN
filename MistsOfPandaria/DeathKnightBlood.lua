-- DeathKnightBlood.lua
-- Updated June 03, 2025

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]

if not Hekili or not Hekili.NewSpecialization then 
    return 
end

local class = Hekili.Class
local state = Hekili.State

-- Ensure death_knight namespace exists early to avoid unknown key errors in emulation.
if not state.death_knight then state.death_knight = { runeforge = {} } end
if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

-- Safe local references to WoW API (helps static analyzers and emulation)
local GetRuneCooldown = rawget( _G, "GetRuneCooldown" ) or function() return 0, 10, true end
local GetRuneType = rawget( _G, "GetRuneType" ) or function() return 1 end

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 250 ) -- Blood spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced Helper Functions (following Hunter Survival pattern)
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    -- MoP compatibility: use fallback methods since C_UnitAuras doesn't exist
    if filter == "HELPFUL" or not filter then
        return FindUnitBuffByID("player", spellID)
    else
        return FindUnitDebuffByID("player", spellID)
    end
end

local function GetTargetDebuffByID(spellID, caster)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = FindUnitDebuffByID("target", spellID, caster or "PLAYER")
    if name then
        return {
            name = name,
            icon = icon,
            count = count or 1,
            duration = duration,
            expires = expirationTime,
            applied = expirationTime - duration,
            caster = unitCaster
        }
    end
    return nil
end

-- Local shim for resource changes to normalize names and avoid global gain/spend calls.
local function _normalizeResource(res)
    if res == "runicpower" or res == "rp" then return "runic_power" end
    return res
end

local function gain(amount, resource, overcap, noforecast)
    local r = _normalizeResource(resource)
    if r == "runes" and state.runes and state.runes.expiry then
        local n = tonumber(amount) or 0
        if n >= 6 then
            for i = 1, 6 do state.runes.expiry[i] = 0 end
        else
            for _ = 1, n do
                local worstIdx, worstVal = 1, -math.huge
                for i = 1, 6 do
                    local e = state.runes.expiry[i] or 0
                    if e > worstVal then worstVal, worstIdx = e, i end
                end
                state.runes.expiry[worstIdx] = 0
            end
        end
        return
    end
    if state.gain then return state.gain(amount, r, overcap, noforecast) end
end

local function spend(amount, resource, noforecast)
    local r = _normalizeResource(resource)
    if state.spend then return state.spend(amount, r, noforecast) end
end

-- Minimal compatibility stubs to avoid undefineds in placeholder logic.
local function heal(amount)
    if state and state.gain then
        state.gain(amount, "health", true, true)
    elseif state and state.health then
        local cur, maxv = state.health.current or 0, state.health.max or 1
        state.health.current = math.min(maxv, cur + (tonumber(amount) or 0))
    end
end

local mastery = { blood_shield = { enabled = false } }
local mastery_value = (state and (state.mastery_value or (state.stat and state.stat.mastery_value))) or 0

-- Combat Log Event Tracking System (following Hunter Survival structure)
local bloodCombatLogFrame = CreateFrame("Frame")
local bloodCombatLogEvents = {}

local function RegisterBloodCombatLogEvent(event, handler)
    if not bloodCombatLogEvents[event] then
        bloodCombatLogEvents[event] = {}
    end
    table.insert(bloodCombatLogEvents[event], handler)
end

bloodCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = bloodCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

bloodCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- MoP runeforge detection (classic-safe), matching Unholy implementation
local blood_runeforges = {
    [3370] = "razorice",
    [3368] = "fallen_crusader",
    [3847] = "stoneskin_gargoyle",
}

local function Blood_ResetRuneforges()
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end
    table.wipe( state.death_knight.runeforge )
end

local function Blood_UpdateRuneforge( slot )
    if slot ~= 16 and slot ~= 17 then return end
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

    local link = GetInventoryItemLink( "player", slot )
    local enchant = link and link:match( "item:%d+:(%d+)" )
    if enchant then
        local name = blood_runeforges[ tonumber( enchant ) ]
        if name then
            state.death_knight.runeforge[ name ] = true
            if name == "razorice" then
                if slot == 16 then state.death_knight.runeforge.razorice_mh = true end
                if slot == 17 then state.death_knight.runeforge.razorice_oh = true end
            end
        end
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function(_, evt, ...)
        if evt == "PLAYER_ENTERING_WORLD" then
            Blood_ResetRuneforges()
            Blood_UpdateRuneforge(16)
            Blood_UpdateRuneforge(17)
        elseif evt == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if slot == 16 or slot == 17 then
                Blood_ResetRuneforges()
                Blood_UpdateRuneforge(16)
                Blood_UpdateRuneforge(17)
            end
        end
    end)
end

Hekili:RegisterGearHook( Blood_ResetRuneforges, Blood_UpdateRuneforge )

-- Blood Shield tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 77535 then -- Blood Shield
        -- Track Blood Shield absorption for optimization
    elseif spellID == 49222 then -- Bone Armor
        -- Track Bone Armor stacks
    elseif spellID == 55233 then -- Vampiric Blood
        -- Track Vampiric Blood for survival cooldown
    end
end)

-- Crimson Scourge proc tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 81141 then -- Crimson Scourge
        -- Track Crimson Scourge proc for free Death and Decay
    elseif spellID == 59052 then -- Freezing Fog
        -- Track Freezing Fog proc for Howling Blast
    end
end)

-- Disease application tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 55078 then -- Blood Plague
        -- Track Blood Plague for disease management
    elseif spellID == 55095 then -- Frost Fever
        -- Track Frost Fever for disease management
    end
end)

-- Death Strike healing tracking
RegisterBloodCombatLogEvent("SPELL_HEAL", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount)
    if spellID == 45470 then -- Death Strike
        -- Track Death Strike healing for survival optimization
    end
end)

-- Register resources
-- MoP: Use legacy power type constants
spec:RegisterResource( 6 ) -- RunicPower = 6 in MoP
-- Runes (unified model on the resource itself to avoid collision with a state table)
do
    local function buildTypeCounter(indices, typeId)
        return setmetatable({}, {
            __index = function(_, k)
                if k == "count" then
                    local ready = 0
                    if typeId == 4 then
                        for i = 1, 6 do
                            local start, duration, isReady = GetRuneCooldown(i)
                            local rtype = GetRuneType(i)
                            if (isReady or (start and duration and (start + duration) <= state.query_time)) and rtype == 4 then
                                ready = ready + 1
                            end
                        end
                    else
                        for _, i in ipairs(indices) do
                            local start, duration, isReady = GetRuneCooldown(i)
                            if isReady or (start and duration and (start + duration) <= state.query_time) then
                                ready = ready + 1
                            end
                        end
                    end
                    return ready
                end
                return 0
            end
        })
    end

    spec:RegisterResource( 5, {}, setmetatable({
        expiry = { 0, 0, 0, 0, 0, 0 },
        cooldown = 10,
        max = 6,
        reset = function()
            local t = state.runes
            for i = 1, 6 do
                local start, duration, ready = GetRuneCooldown(i)
                start = start or 0
                duration = duration or (10 * state.haste)
                t.expiry[i] = ready and 0 or (start + duration)
                t.cooldown = duration
            end
        end,
    }, {
        __index = function(t, k)
            local idx = tostring(k):match("time_to_(%d)")
            if idx then
                local i = tonumber(idx)
                local e = t.expiry[i] or 0
                return math.max(0, e - state.query_time)
            end
            if k == "blood" then return buildTypeCounter({1,2}, 1) end
            if k == "frost" then return buildTypeCounter({3,4}, 2) end
            if k == "unholy" then return buildTypeCounter({5,6}, 3) end
            if k == "death" then return buildTypeCounter({}, 4) end
            if k == "count" or k == "current" then
                local c = 0
                for i = 1, 6 do
                    if t.expiry[i] <= state.query_time then c = c + 1 end
                end
                return c
            end
            return rawget(t, k)
        end
    }) ) -- Runes = 5 in MoP with unified state

    spec:RegisterHook("reset_precast", function()
        if state.runes and state.runes.reset then state.runes.reset() end
    end)
end

-- Enhanced Resource Systems for Blood Death Knight
spec:RegisterResource( 6, { -- RunicPower
    -- Death Strike runic power generation
    death_strike = {
        aura = "death_strike",
        last = function ()
            local app = state.buff.death_strike.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.death_strike.up and 15 or 0 -- 15 runic power per Death Strike
        end,
    },
    
    -- Heart Strike runic power generation
    heart_strike = {
        aura = "heart_strike",
        last = function ()
            local app = state.buff.heart_strike.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.heart_strike.up and 10 or 0 -- 10 runic power per Heart Strike
        end,
    },
    
    -- Blood Boil runic power generation
    blood_boil = {
        aura = "blood_boil",
        last = function ()
            local app = state.buff.blood_boil.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.blood_boil.up and 10 or 0 -- 10 runic power per Blood Boil
        end,
    },
    
    -- Rune Tap runic power efficiency
    rune_tap = {
        aura = "rune_tap",
        last = function ()
            local app = state.buff.rune_tap.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.rune_tap.up and 5 or 0 -- Additional runic power efficiency
        end,
    },
}, {
    -- Enhanced base runic power generation
    base_regen = function ()
        local base = 0 -- Death Knights don't naturally regenerate runic power
        local combat_bonus = 0
        local presence_bonus = 0
        
        if state.combat then
            -- Runic power generation from abilities
            base = 2 -- Base generation in combat
        end
        
        -- Presence bonuses
        if state.buff.blood_presence.up then
            presence_bonus = presence_bonus + 1 -- 10% more runic power generation in Blood Presence
        end
        
        return base + combat_bonus + presence_bonus
    end,
    
    -- Runic Empowerment bonus
    runic_empowerment = function ()
        return state.talent.runic_empowerment.enabled and 0.5 or 0
    end,
    
    -- Runic Corruption bonus
    runic_corruption = function ()
        return state.talent.runic_corruption.enabled and 0.5 or 0    end,
} )

-- Register individual rune types for MoP 5.5.0 (Blood DK)
spec:RegisterResource( 20, { -- Blood Runes = 20 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.blood_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "blood_runes",

    reset = function()
        local t = state.blood_runes
        for i = 1, 2 do
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.blood_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.blood_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.blood_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

spec:RegisterResource( 21, { -- Frost Runes = 21 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.frost_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "frost_runes",

    reset = function()
        local t = state.frost_runes
        for i = 3, 4 do -- Frost runes are at positions 3-4
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i - 2 ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.frost_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.frost_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.frost_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

spec:RegisterResource( 22, { -- Unholy Runes = 22 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.unholy_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "unholy_runes",

    reset = function()
        local t = state.unholy_runes
        for i = 5, 6 do -- Unholy runes are at positions 5-6
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i - 4 ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.unholy_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.unholy_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.unholy_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

-- Unified DK Runes interface across specs
-- Removed duplicate RegisterStateTable("runes"); unified model lives on the resource.

-- Death Runes State Table for MoP 5.5.0 (Blood DK)
spec:RegisterStateTable( "death_runes", setmetatable( {
    state = {},

    reset = function()
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown( i )
            local type = GetRuneType( i )
            local expiry = ready and 0 or start + duration
            state.death_runes.state[i] = {
                type = type,
                start = start,
                duration = duration,
                ready = ready,
                expiry = expiry
            }
        end
    end,

    getActiveDeathRunes = function()
        local activeRunes = {}
        local state_array = state.death_runes.state
        for i = 1, 6 do
            if state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                table.insert(activeRunes, i)
            end
        end
        return activeRunes
    end,

    getActiveRunes = function()
        local activeRunes = {}
        local state_array = state.death_runes.state
        for i = 1, 6 do
            if state_array[i].expiry < state.query_time then
                table.insert(activeRunes, i)
            end
        end
        return activeRunes
    end,

    countDeathRunes = function()
        local count = 0
        local state_array = state.death_runes.state
        for i = 1, 6 do
            if state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                count = count + 1
            end
        end
        return count
    end,

    countRunesByType = function(type)
        local count = 0
        local state_array = state.death_runes.state
        local runeMapping = {
            blood = {1, 2},
            frost = {3, 4},
            unholy = {5, 6}
        }
        local runes = runeMapping[type]
        if runes then
            for _, rune in ipairs(runes) do
                if state_array[rune].type == 4 and state_array[rune].expiry < state.query_time then
                    count = count + 1
                elseif state_array[rune].type == (type == "blood" and 1 or type == "frost" and 2 or 3) and state_array[rune].expiry < state.query_time then
                    count = count + 1
                end
            end
        else
            print("Invalid rune type:", type)
        end
        return count
    end
}, {
    __index = function( t, k )
        if k == "active_death_runes" then
            return t.getActiveDeathRunes()
        elseif k == "active_runes" then
            return t.getActiveRunes()
        elseif k == "count" then
            return t.countDeathRunes()
        elseif k == "blood" then
            return t.countRunesByType("blood")
        elseif k == "frost" then
            return t.countRunesByType("frost")
        elseif k == "unholy" then
            return t.countRunesByType("unholy")
        end
        return rawget( t, k )
    end
} ) )

-- Tier sets
spec:RegisterGear( "tier14", 86919, 86920, 86921, 86922, 86923 ) -- T14 Battleplate of the Lost Cataphract
spec:RegisterGear( "tier15", 95225, 95226, 95227, 95228, 95229 ) -- T15 Battleplate of the All-Consuming Maw
spec:RegisterGear( 13, 6, { -- Tier 14 (Heart of Fear)
    { 86886, head = 86886, shoulder = 86889, chest = 86887, hands = 86888, legs = 86890 }, -- LFR
    { 86919, head = 86919, shoulder = 86922, chest = 86920, hands = 86921, legs = 86923 }, -- Normal
    { 87139, head = 87139, shoulder = 87142, chest = 87140, hands = 87141, legs = 87143 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_blood", {
    id = 105677,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_blood", {
    id = 105679,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterGear( 14, 6, { -- Tier 15 (Throne of Thunder)
    { 95225, head = 95225, shoulder = 95228, chest = 95226, hands = 95227, legs = 95229 }, -- LFR
    { 95705, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 }, -- Normal
    { 96101, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_blood", {
    id = 138252,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_blood", {
    id = 138253,
    duration = 10,
    max_stack = 1,
} )

spec:RegisterGear( 15, 6, { -- Tier 16 (Siege of Orgrimmar)
    { 99625, head = 99625, shoulder = 99628, chest = 99626, hands = 99627, legs = 99629 }, -- LFR
    { 98310, head = 98310, shoulder = 98313, chest = 98311, hands = 98312, legs = 98314 }, -- Normal
    { 99170, head = 99170, shoulder = 99173, chest = 99171, hands = 99172, legs = 99174 }, -- Heroic
    { 99860, head = 99860, shoulder = 99863, chest = 99861, hands = 99862, legs = 99864 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_blood", {
    id = 144958,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_blood", {
    id = 144966,
    duration = 15,
    max_stack = 1,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148011,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "resolve_of_undying", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "juggernaut_s_focusing_crystal", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "bone_link_fetish", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "armageddon", 105531, {
    main_hand = 105531,
} )

-- Talents (MoP talent system and Blood spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56)
    roiling_blood            = { 1, 1, 108170 }, -- Your Pestilence refreshes disease durations and spreads diseases from each diseased target to all other targets.
    plague_leech             = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
    unholy_blight            = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.
    
    -- Tier 2 (Level 57)
    lichborne                = { 2, 1, 49039 }, -- Draw upon unholy energy to become undead for 10 sec, immune to charm, fear, and sleep effects.
    anti_magic_zone          = { 2, 2, 51052 }, -- Places an Anti-Magic Zone that reduces spell damage taken by party members by 40%.
    purgatory                = { 2, 3, 114556 }, -- An unholy pact that prevents fatal damage, instead absorbing incoming healing.
    
    -- Tier 3 (Level 58)
    deaths_advance           = { 3, 1, 96268 }, -- For 8 sec, you are immune to movement impairing effects and take 50% less damage from area of effect abilities.
    chilblains               = { 3, 2, 50041 }, -- Victims of your Chains of Ice, Howling Blast, or Remorseless Winter are Chilblained, reducing movement speed by 50% for 10 sec.
    asphyxiate               = { 3, 3, 108194 }, -- Lifts an enemy target off the ground and crushes their throat, silencing them for 5 sec.
    
    -- Tier 4 (Level 60)
    death_pact               = { 4, 1, 48743 }, -- Sacrifice your ghoul to heal yourself for 20% of your maximum health.
    death_siphon             = { 4, 2, 108196 }, -- Inflicts Shadow damage to target enemy and heals you for 100% of the damage done.
    conversion               = { 4, 3, 119975 }, -- Continuously converts 2% of your maximum health per second into 20% of maximum health as healing.
    
    -- Tier 5 (Level 75)
    blood_tap                = { 5, 1, 45529 }, -- Consume 5 charges from your Blood Charges to immediately activate a random depleted rune.
    runic_empowerment        = { 5, 2, 81229 }, -- When you use a rune, you have a 45% chance to immediately regenerate that rune.
    runic_corruption         = { 5, 3, 51462 }, -- When you hit with a Death Coil, Frost Strike, or Rune Strike, you have a 45% chance to regenerate a rune.
    
    -- Tier 6 (Level 90)
    gorefiends_grasp         = { 6, 1, 108199 }, -- Shadowy tendrils coil around all enemies within 20 yards of a hostile target, pulling them to the target's location.
    remorseless_winter       = { 6, 2, 108200 }, -- Surrounds the Death Knight with a swirling blizzard that grows over 8 sec, slowing enemies by up to 50% and reducing their melee and ranged attack speed by up to 20%.
    desecrated_ground        = { 6, 3, 108201 }, -- Corrupts the ground targeted by the Death Knight for 30 sec. While standing on this ground you are immune to effects that cause loss of control.
} )

-- Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs (affecting tanking and mechanics)
    [58616] = "Glyph of Anti-Magic Shell",    -- Reduces the cooldown on Anti-Magic Shell by 5 sec, but the amount it absorbs is reduced by 50%.
    [58617] = "Glyph of Army of the Dead",    -- Your Army of the Dead spell summons an additional skeleton, but the cast time is increased by 2 sec.
    [58618] = "Glyph of Bone Armor",          -- Your Bone Armor gains an additional charge but the duration is reduced by 30 sec.
    [58619] = "Glyph of Chains of Ice",       -- Your Chains of Ice no longer reduces movement speed but increases the duration by 2 sec.
    [58620] = "Glyph of Dark Simulacrum",     -- Dark Simulacrum gains an additional charge but the duration is reduced by 4 sec.
    [58621] = "Glyph of Death and Decay",     -- Your Death and Decay no longer slows enemies but lasts 50% longer.
    [58622] = "Glyph of Death Coil",          -- Your Death Coil refunds 20 runic power when used on friendly targets but heals for 30% less.
    [58623] = "Glyph of Death Grip",          -- Your Death Grip no longer moves the target but reduces its movement speed by 50% for 8 sec.
    [58624] = "Glyph of Death Pact",          -- Your Death Pact no longer requires a ghoul but heals for 50% less.
    [58625] = "Glyph of Death Strike",        -- Your Death Strike deals 25% additional damage but heals for 25% less.
    [58626] = "Glyph of Frost Strike",        -- Your Frost Strike has no runic power cost but deals 20% less damage.
    [58627] = "Glyph of Heart Strike",        -- Your Heart Strike generates 10 additional runic power but affects 1 fewer target.
    [58628] = "Glyph of Icebound Fortitude",  -- Your Icebound Fortitude grants immunity to stun effects but the damage reduction is lowered by 20%.
    [58629] = "Glyph of Icy Touch",           -- Your Icy Touch dispels 1 beneficial magic effect but no longer applies Frost Fever.
    [58630] = "Glyph of Mind Freeze",         -- Your Mind Freeze has its cooldown reduced by 2 sec but its range is reduced by 5 yards.
    [58631] = "Glyph of Outbreak",            -- Your Outbreak no longer costs a Blood rune but deals 50% less damage.
    [58632] = "Glyph of Plague Strike",       -- Your Plague Strike does additional disease damage but no longer applies Blood Plague.
    [58633] = "Glyph of Raise Dead",          -- Your Raise Dead spell no longer requires a corpse but the ghoul has 20% less health.
    [58634] = "Glyph of Rune Strike",         -- Your Rune Strike generates 10% more threat but costs 10 additional runic power.
    [58635] = "Glyph of Rune Tap",            -- Your Rune Tap heals nearby allies for 5% of their maximum health but heals you for 50% less.
    [58636] = "Glyph of Scourge Strike",      -- Your Scourge Strike deals additional Shadow damage for each disease on the target but consumes all diseases.
    [58637] = "Glyph of Strangulate",         -- Your Strangulate has its cooldown reduced by 10 sec but the duration is reduced by 2 sec.
    [58638] = "Glyph of Vampiric Blood",      -- Your Vampiric Blood generates 5 runic power per second but increases damage taken by 10%.
    [58639] = "Glyph of Blood Boil",          -- Your Blood Boil deals 20% additional damage but no longer spreads diseases.
    [58640] = "Glyph of Dancing Rune Weapon", -- Your Dancing Rune Weapon lasts 5 sec longer but generates 20% less runic power.
    [58641] = "Glyph of Vampiric Aura",       -- Your Vampiric Aura affects 2 additional party members but the healing is reduced by 25%.
    [58642] = "Glyph of Unholy Frenzy",       -- Your Unholy Frenzy grants an additional 10% attack speed but lasts 50% shorter.
    [58643] = "Glyph of Corpse Explosion",    -- Your corpses explode when they expire, dealing damage to nearby enemies.
    [58644] = "Glyph of Disease",             -- Your diseases last 50% longer but deal 25% less damage.
    [58645] = "Glyph of Resilient Grip",      -- Your Death Grip removes one movement impairing effect from yourself.
    [58646] = "Glyph of Shifting Presences",  -- Reduces the rune cost to change presences by 1, but you cannot change presences while in combat.
    
    -- Minor Glyphs (convenience and visual)
    [58647] = "Glyph of Corpse Walker",       -- Your undead minions appear to be spectral.
    [58648] = "Glyph of the Geist",           -- Your ghoul appears as a geist.
    [58649] = "Glyph of Death's Embrace",     -- Your death grip has enhanced visual effects.
    [58650] = "Glyph of Bone Spikes",         -- Your abilities create bone spike visual effects.
    [58651] = "Glyph of Unholy Vigor",        -- Your character emanates an unholy aura.
    [58652] = "Glyph of the Bloodied",        -- Your weapons appear to be constantly dripping blood.
    [58653] = "Glyph of Runic Mastery",       -- Your runes glow with enhanced energy when available.
    [58654] = "Glyph of the Forsaken",        -- Your character appears more skeletal and undead.
    [58655] = "Glyph of Shadow Walk",         -- Your movement leaves shadowy footprints.
    [58656] = "Glyph of Death's Door",        -- Your abilities create portal-like visual effects.
} )

-- Enhanced Tier Sets with comprehensive bonuses for Blood Death Knight tanking
spec:RegisterGear( 13, 8, { -- Tier 14 (Heart of Fear) - Death Knight
    { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
    { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
    { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_blood", {
    id = 105919,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_blood", {
    id = 105925,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterGear( 14, 8, { -- Tier 15 (Throne of Thunder) - Death Knight
    { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
    { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
    { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_blood", {
    id = 138292,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_blood", {
    id = 138295,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( 15, 8, { -- Tier 16 (Siege of Orgrimmar) - Death Knight
    { 99683, head = 99455, shoulder = 99458, chest = 99453, hands = 99454, legs = 99456 }, -- LFR
    { 99684, head = 98340, shoulder = 98343, chest = 98338, hands = 98339, legs = 98341 }, -- Normal
    { 99685, head = 99200, shoulder = 99203, chest = 99198, hands = 99199, legs = 99201 }, -- Heroic
    { 99686, head = 99890, shoulder = 99893, chest = 99888, hands = 99889, legs = 99891 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_blood", {
    id = 144953,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_blood", {
    id = 144955,
    duration = 12,
    max_stack = 1,
} )

-- Advanced Mastery and Specialization Bonuses
spec:RegisterGear( 16, 8, { -- PvP Sets
    { 138001, head = 138454, shoulder = 138457, chest = 138452, hands = 138453, legs = 138455 }, -- Grievous Gladiator's
    { 138002, head = 139201, shoulder = 139204, chest = 139199, hands = 139200, legs = 139202 }, -- Prideful Gladiator's
} )

-- Combat Log Event Registration for advanced tracking
spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName, _, amount, interrupt, a, b, c, d, offhand, multistrike, ... )
    if sourceGUID == state.GUID then
        if subtype == "SPELL_CAST_SUCCESS" then
            if spellID == 49998 then -- Death Strike
                state.last_death_strike = GetTime()
            elseif spellID == 45462 then -- Plague Strike  
                state.last_plague_strike = GetTime()
            elseif spellID == 49930 then -- Blood Boil
                state.last_blood_boil = GetTime()
            end
        elseif subtype == "SPELL_AURA_APPLIED" then
            if spellID == 77535 then -- Blood Shield
                state.blood_shield_applied = GetTime()
            end
        elseif subtype == "SPELL_DAMAGE" then
            if spellID == 49998 then -- Death Strike healing
                state.death_strike_heal = amount
            end
        end
    end
end )

-- Advanced Aura System with Generate Functions (following Hunter Survival pattern)
spec:RegisterAuras( {
    -- Core Blood Death Knight Auras with Advanced Generate Functions
    blood_shield = {
        id = 77535,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 77535 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    bone_armor = {
        id = 49222,
        duration = 300,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 49222 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    crimson_scourge = {
        id = 81141,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 81141 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    vampiric_blood = {
        id = 55233,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 55233 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    dancing_rune_weapon = {
        id = 49028,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 49028 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced Tanking Mechanics
    death_pact = {
        id = 48743,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48743 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Disease Tracking with Enhanced Generate Functions
    blood_plague = {
        id = 55078,
        duration = 21,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 55078, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    frost_fever = {
        id = 55095,
        duration = 21,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 55095, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end    },
    
    -- Proc Tracking Auras
    will_of_the_necropolis = {
        id = 81162,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 81162 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Tier Set Coordination Auras
    t14_blood_2pc = {
        id = 105588,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105588 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    t14_blood_4pc = {
        id = 105589,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105589 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    t15_blood_2pc = {
        id = 138165,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 138165 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    t15_blood_4pc = {
        id = 138166,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 138166 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    t16_blood_2pc = {
        id = 144901,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 144901 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    t16_blood_4pc = {
        id = 144902,
        duration = 25,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 144902 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Defensive Cooldown Tracking
    icebound_fortitude = {
        id = 48792,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48792 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    anti_magic_shell = {
        id = 48707,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48707 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Rune Tracking
    blood_tap = {
        id = 45529,
        duration = 20,
        max_stack = 12,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 45529 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Presence Tracking
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48263 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48265 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48266 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Utility and Control
    death_grip = {
        id = 49576,
        duration = 3,
        max_stack = 1
    },
    
    death_and_decay = {
        id = 43265,
        duration = 10,
        max_stack = 1
    },
    
    -- Shared Death Knight Auras (Basic Tracking)
    dark_succor = {
        id = 101568,
        duration = 20,
        max_stack = 1
    },
    
    necrotic_strike = {
        id = 73975,
        duration = 15,
        max_stack = 15
    },
    
    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1
    },
    
    mind_freeze = {
        id = 47528,
        duration = 4,
        max_stack = 1
    },
    
    strangulate = {
        id = 47476,
        duration = 5,
        max_stack = 1
    },
} )

-- Blood DK core abilities
spec:RegisterAbilities( {
    -- Blood Presence: Increased armor, health, and threat generation. Reduced damage taken.
    blood_presence = {
        id = 48263,
        duration = 3600, -- Long duration buff
        max_stack = 1,
    },
    -- Dancing Rune Weapon: Summons a copy of your weapon that mirrors your attacks.
    dancing_rune_weapon = {
        id = 49028,
        duration = function() return glyph.dancing_rune_weapon.enabled and 17 or 12 end,
        max_stack = 1,
    },
    -- Crimson Scourge: Free Death and Decay proc
    crimson_scourge = {
        id = 81141,
        duration = 15,
        max_stack = 1,
    },
    -- Bone Shield: Reduces damage taken
    bone_shield = {
        id = 49222,
        duration = 300,
        max_stack = 10,
    },
    -- Blood Shield: Absorb from Death Strike
    blood_shield = {
        id = 77513,
        duration = 10,
        max_stack = 1,
    },
    -- Vampiric Blood: Increases health and healing received
    vampiric_blood = {
        id = 55233,
        duration = 10,
        max_stack = 1,
    },
    -- Veteran of the Third War: Passive health increase
    veteran_of_the_third_war = {
        id = 48263,
        duration = 3600, -- Passive talent effect
        max_stack = 1,
    },
    -- Death Grip Taunt
    death_grip = {
        id = 49560,
        duration = 3,
        max_stack = 1,
    },

    -- Common Death Knight Auras (shared across all specs)
    -- Diseases
    blood_plague = {
        id = 59879,
        duration = function() return 30 end,
        max_stack = 1,
        type = "Disease",
    },
    frost_fever = {
        id = 59921,
        duration = function() return 30 end,
        max_stack = 1,
        type = "Disease",
    },
    
    -- Other Presences
    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
    },
    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        duration = function() return glyph.anti_magic_shell.enabled and 7 or 5 end,
        max_stack = 1,
    },
    icebound_fortitude = {
        id = 48792,
        duration = function() return glyph.icebound_fortitude.enabled and 6 or 8 end,
        max_stack = 1,
    },
    
    -- Utility
    horn_of_winter = {
        id = 57330,
        duration = function() return glyph.horn_of_winter.enabled and 3600 or 120 end,
        max_stack = 1,
    },
    path_of_frost = {
        id = 3714,
        duration = 600,
        max_stack = 1,
    },
    
    -- Tier bonuses and procs
    sudden_doom = {
        id = 81340,
        duration = 10,
        max_stack = 1,
    },
    
    -- Runic system
    blood_tap = {
        id = 45529,
        duration = 30,
        max_stack = 10,
    },
    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
    },    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
    },
    
    -- Missing important auras for Blood DK
    scarlet_fever = {
        id = 81132,
        duration = 30,
        max_stack = 1,
        type = "Magic",
    },
    
    -- Mastery: Blood Shield (passive)
    mastery_blood_shield = {
        id = 77513,
        duration = 3600, -- Passive
        max_stack = 1,
    },
    
    -- Blade Barrier (from Blade Armor talent)
    blade_barrier = {
        id = 64859,
        duration = 3600, -- Passive
        max_stack = 1,
    },
    
    -- Death and Decay ground effect
    death_and_decay = {
        id = 43265,
        duration = 10,
        max_stack = 1,
    },
} )

-- Blood DK core abilities
spec:RegisterAbilities( {    
     death_strike = {
        id = 49998,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 1}, -- 0 Blood, 1 Frost, 1 Unholy
        
        gain = 20,
        gainType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Death Strike heals based on damage taken in last 5 seconds
            local heal_amount = min(health.max * 0.25, health.max * 0.07) -- 7-25% of max health
            heal(heal_amount)
            
            -- Apply Blood Shield absorb
            local shield_amount = heal_amount * 0.5 -- 50% of heal as absorb
            applyBuff("blood_shield")
            
            -- Mastery: Blood Shield increases absorb amount
            if mastery.blood_shield.enabled then
                shield_amount = shield_amount * (1 + mastery_value * 0.062) -- 6.2% per mastery point
            end
        end,
    },
      heart_strike = {
        id = 55050,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {1, 0, 0}, -- 1 Blood, 0 Frost, 0 Unholy
        
        gain = 10,
        gainType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            -- Heart Strike hits multiple targets and spreads diseases
            if active_enemies > 1 then
                -- Spread diseases to nearby enemies
                if debuff.blood_plague.up then
                    applyDebuff("target", "blood_plague")
                end
                if debuff.frost_fever.up then
                    applyDebuff("target", "frost_fever")
                end
            end
        end,
    },
      dancing_rune_weapon = {
        id = 49028,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        spend = 60,
        spendType = "runicpower",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            local duration = glyph.dancing_rune_weapon.enabled and 17 or 12
            applyBuff("dancing_rune_weapon", duration)
        end,
    },
    
    vampiric_blood = {
        id = 55233,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("vampiric_blood")
        end,
    },
    
    bone_shield = {
        id = 49222,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("bone_shield", nil, 10) -- 10 charges
        end,
    },
    
    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "runicpower",
        
        startsCombat = true,
        texture = 237518,
        
        usable = function() return buff.blood_presence.up end,
        
        handler = function ()
            -- Rune Strike: Enhanced weapon strike with high threat
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier for tanking
            
            -- High threat generation for Blood tanking
            -- Main-hand + off-hand if dual wielding
        end,
    },
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        cast = 0,
        cooldown = function() return glyph.anti_magic_shell.enabled and 60 or 45 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("anti_magic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 120 or 180 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("icebound_fortitude")
        end,
    },
    
    -- Utility
    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_grip")
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        
        handler = function ()
            if active_enemies > 1 and talent.asphyxiate.enabled then
                -- potentially apply interrupt debuff with talent
            end
        end,
    },
      death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = function() return buff.crimson_scourge.up and 0 or 1 end,
        spendType = function() return buff.crimson_scourge.up and nil or "unholy_runes" end,
        
        startsCombat = true,
        
        usable = function() 
            return buff.crimson_scourge.up or runes.unholy.count > 0 or runes.death.count > 0
        end,
        
        handler = function ()
            -- If Crimson Scourge is active, don't consume runes
            if buff.crimson_scourge.up then
                removeBuff("crimson_scourge")
            end
            
            -- Death and Decay does AoE damage in targeted area
            gain(15, "runicpower") -- Generates more RP for AoE situations
        end,
    },
    
    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("horn_of_winter")
            if not glyph.horn_of_winter.enabled then
                gain(10, "runicpower")
            end
        end,
    },
    
    raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs
        end,
    },
      army_of_the_dead = {
        id = 42650,
        cast = function() return 4 end, -- 4 second channel (8 ghouls @ 0.5s intervals)
        cooldown = 600, -- 10 minute cooldown
        gcd = "spell",
        
        spend = function() return 1, 1, 1 end, -- 1 Blood + 1 Frost + 1 Unholy
        spendType = "runes",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237302,
        
        handler = function ()
            -- Summon 8 ghouls over 4 seconds, each lasting 40 seconds
            -- Generates 30 Runic Power
            gain( 30, "runic_power" )
        end,
    },
    
    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("path_of_frost")
        end,
    },
    
    -- Presence switching
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("frost_presence")
            removeBuff("unholy_presence")
            applyBuff("blood_presence")
        end,
    },
    
    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("unholy_presence")
            applyBuff("frost_presence")
        end,
    },
    
    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("frost_presence")
            applyBuff("unholy_presence")
        end,
    },
    
    -- Rune management
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = function() return glyph.blood_tap.enabled and 15 or 0 end,
        spendType = function() return glyph.blood_tap.enabled and "runicpower" or nil end,
        
        startsCombat = false,
        
        handler = function ()
            if not glyph.blood_tap.enabled then
                -- Original functionality: costs health
                spend(0.05, "health")
            end
            -- Convert a blood rune to a death rune
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            -- Refresh all rune cooldowns and generate 25 runic power
            gain(25, "runicpower")
        end,
    },
} )

-- Add state handlers for Death Knight rune system
do
    -- Legacy rune type expressions for SimC compatibility (kept, but simplified and NOT shadowing resource tables).
    -- Provide blood/frost/unholy/death counts directly via API so they are self-contained and cannot recurse through
    -- the resource tables (which might themselves reference these expressions during evaluation).
    spec:RegisterStateExpr( "blood", function()
        local count = 0
        for i = 1, 2 do
            local _, _, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    end )
    spec:RegisterStateExpr( "frost", function()
        local count = 0
        for i = 3, 4 do
            local _, _, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    end )
    spec:RegisterStateExpr( "unholy", function()
        local count = 0
        for i = 5, 6 do
            local _, _, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    end )
    spec:RegisterStateExpr( "death", function()
        local count = 0
        for i = 1, 6 do
            local _, _, ready = GetRuneCooldown( i )
            if ready and GetRuneType( i ) == 4 then count = count + 1 end
        end
        return count
    end )

    -- Convert runes to death runes (Blood Tap, etc.)
    spec:RegisterStateFunction( "convert_to_death_rune", function( rune_type, amount )
        amount = amount or 1
        
        if rune_type == "blood" and state.blood_runes.current >= amount then
            state.blood_runes.current = state.blood_runes.current - amount
            state.death_runes.count = state.death_runes.count + amount
        elseif rune_type == "frost" and state.frost_runes.current >= amount then
            state.frost_runes.current = state.frost_runes.current - amount
            state.death_runes.count = state.death_runes.count + amount
        elseif rune_type == "unholy" and state.unholy_runes.current >= amount then
            state.unholy_runes.current = state.unholy_runes.current - amount
            state.death_runes.count = state.death_runes.count + amount
        end
    end )
    
    -- Add function to check runic power generation
    spec:RegisterStateFunction( "gain_runic_power", function( amount )
        -- Logic to gain runic power
        gain( amount, "runicpower" )
    end )
end

-- Unified DK Runes interface across specs (matches Unholy/Frost implementation)
-- Duplicate unified runes state table removed; resource(5) provides state.runes.

-- State Expressions for Blood Death Knight
spec:RegisterStateExpr( "blood_shield_absorb", function()
    return buff.blood_shield.v1 or 0 -- Amount of damage absorbed
end )

spec:RegisterStateExpr( "diseases_ticking", function()
    local count = 0
    if debuff.blood_plague.up then count = count + 1 end
    if debuff.frost_fever.up then count = count + 1 end
    return count
end )

spec:RegisterStateExpr( "bone_shield_charges", function()
    return buff.bone_shield.stack or 0
end )

spec:RegisterStateExpr( "total_runes", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end )

spec:RegisterStateExpr( "runes_on_cd", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return 6 - total
end )

-- Removed duplicate rune_deficit (defined later with extended context) to prevent re-registration recursion.

-- MoP-specific rune state expressions for Blood DK
-- Removed shadowing expressions blood_runes/frost_runes/unholy_runes/death_runes that returned numeric counts and
-- replaced with direct API-based blood/frost/unholy/death expressions above. This prevents state table name clashes
-- and potential recursive evaluation leading to C stack overflows.

-- MoP Blood-specific rune tracking
spec:RegisterStateExpr( "death_strike_runes_available", function()
    -- Death Strike requires one pair of runes (in MoP any pair of Blood/Death for Blood spec) – simplify: need at least 2 usable runes of any kind.
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total >= 2
end )

spec:RegisterStateExpr( "blood_tap_charges", function()
    return buff.blood_tap.stack or 0
end )

spec:RegisterStateExpr( "blood_tap_available", function()
    local charges = (buff.blood_tap and buff.blood_tap.stack) or 0
    local blood = (state.blood_runes and state.blood_runes.current) or 0
    return talent.blood_tap.enabled and (charges >= 5 or blood > 0)
end )

-- MoP Death Rune conversion for Blood
spec:RegisterStateFunction( "blood_tap_convert", function( amount )
    amount = amount or 1
    if state.blood_runes.current >= amount then
        state.blood_runes.current = state.blood_runes.current - amount
        state.death_runes.count = state.death_runes.count + amount
        return true
    end
    return false
end )

-- Rune state expressions for MoP 5.5.0
-- Simplified rune count expression; unique name 'rune_count' to avoid collisions with any internal engine usage.
-- Unify with Unholy: provide 'rune' expression for total ready runes.
spec:RegisterStateExpr( "rune", function()
    local total = 0
    for i = 1, 6 do
        local _, _, ready = GetRuneCooldown( i )
        if ready then total = total + 1 end
    end
    return total
end )

-- Provide rune_regeneration (mirrors Unholy) representing rune deficit relative to maximum.
spec:RegisterStateExpr( "rune_regeneration", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return 6 - total
end )

-- Consolidated rune_deficit definition (single source).
spec:RegisterStateExpr( "rune_deficit", function()
    -- Pure API-based calculation to avoid referencing other state expressions.
    local ready = 0
    for i = 1, 6 do
        local _, _, isReady = GetRuneCooldown( i )
        if isReady then ready = ready + 1 end
    end
    return 6 - ready
end )

-- Stub for time_to_wounds to satisfy Unholy script references when Blood profile loaded.
-- Avoid referencing spec.State (not defined in MoP module context).
spec:RegisterStateExpr( "time_to_wounds", function() return 999 end )

spec:RegisterStateExpr( "rune_current", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end )

-- Alias for APL compatibility
spec:RegisterStateExpr( "runes_current", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end )



spec:RegisterStateExpr( "rune_max", function()
    return 6
end )





spec:RegisterStateExpr( "death_strike_heal", function()
    -- Estimate Death Strike healing based on recent damage taken
    local base_heal = health.max * 0.07 -- Minimum 7%
    local max_heal = health.max * 0.25 -- Maximum 25%
    -- In actual gameplay, this would track damage taken in last 5 seconds
    return math.min(max_heal, math.max(base_heal, health.max * 0.15)) -- Estimate 15% average
end )

-- Register default pack for MoP Blood Death Knight
spec:RegisterPack( "Blood", 20250809, [[Hekili:9IvBVTTnq4FlfbWjzRtts2onTi2anRdBnBTOaof7BsIwIoMlsIEuuXldg63(os9gjTOJBtr)qBsOoY75EHp3DmWl42Gfjioo4J(U(tDV091oEtg755hSG)4gCWInO47r3b)sokd()LPuAsvehxWfF7XukkrCgf0swm8DqIssk)95blh6GDNEbi7gCmS8u3GfRjjj4AzXfXblUDnPOks8puvuJQRIORG)oMtO5vrPKco85vuwv0VJVNKsCcwixuAk4vOYuo8RFuAA17kyrgjpjCfdJ)paJ4C0YuCsW1bCagcX6xzrmJWXmckybjpMc77UWeugaJWPGANpRkAngLYx7KH(3QOFOkY1zSBv0OQOyknnHUn3bLZjWoiXHfRXPPomCgIKd7g2SBpMmetaMXgGPv0emIVoSGZi3JRDvmYM6p9wqKhaF0hiCYDOAF0Nyekygp(vznxmTkA3UUpSjMxfDvveeTaaoXQ3sfIHSYCCri6bejviQ09CgexpwmmzymCb4Op3Ixba3ulEpel7Xq6Qq(ACiSNedp4hq)Tiz6xAcFfQw1YYvRCwsZXqmIGttCk3ing56jO8yH1iS2WTy0gAUJ4eey5INFAvBGaCCCe7om3bYxWHCAycbl9htC7bJjiv9t7JtbeF1ZhIwItJN2R8hqzBimijxYCi07LpF9oEy96RC7IeJxslf36PmoHxMitrE9Zx3(w0TInlD0C0gHg9CTKvQeWmsiVg(sv0c5NGl2a3bh2FUGE9azMTzEEEwTXgYBaTEYeNvmAbx5VlZxttFSEHEGIZ2q3IzMPpEMmNA2WTms(9y4W)CHs1dE9QEQGQJ2uptPN1uGg3AFENSdD1tFd94VtPcqBJHTri)VlitZz4lXLDIvokfNZDKQwKu50iLYvF5NIxlijCk4qvZ6uxp3wIxTaVaUArEXcQHEnYJo9kHPjf73cyovkYHQFydnMKSTsrl5lzy09g5KVJuGrfIALOCiPmdWRQf8cae0wlytk6UsmW4gFpenR9rnci9DHRWpGzTFxIg78Pn037XsAeEMBgEMVx4zUz4b67kneS1nyMee2jxpG51FC1RRut1ZoJ5bChkSWpcfSkJxlB1YgvyDShbK1j4y0JMD4q)vO9VCWb9UpTOk6TlHE(4eSwDAKSlOqCood(sDEL8ILVD2WJlJZSjdF7nmomimYDxsjYw98nzI2JMEUglmK8W4Q4yIA)TkNTr7T2VX(IM7LRPSCr7rBf1zyYMhePCd9nvImL6D6sjvR9(FapnWKklPiTXlDnD2X1UiXagmmuvEjQVH(bYEm0UXDEXjwf9h5K7wZFtv011(2RbEa4hIML)l6wW3MCkyvFG(jOpWuurbjUk63kjjazXN3igJrwigUa6F5lf9ziAc4O8LDJyOhPadRalRORfTgRjPAdcAIPf6ziGwRPVwvPKoWTiwoCHSqmzfyleOuoJ3m90PndlDAved)pLeMWilOzGCOsonR2Qb(687Wfov38NerBj(Gt8Z5fLBeNKqGACahNX8mN2TLxBDlTnk1lR3fwfULvxr4xzvyfErf5V0Q8AeFk7Wo27O26L23UZP)cQI4t(Ye3URP)EJqCzOEfnnLUvw7cvYqq2nCHdwVuM4tGDXfI1EeIjOf5W8w5YPY8KYCnPtsecdxiqlHBqVP6MQOFQP(vtL92L6tEBwr)QbS4ndKs2DH)ytk)UBR7BgVpRnE4B8mfa(G7PLCypblwKvUcsUeKA0verjMtGkAdspDZjFjmucPTssja4jNiEsGghluavcXIQBQXAHtNt)hN9Z6M3ljRM9clfjgC76SBwKrn1yib6z0Ar)7QzQ6XUisClk)((36O7OGdq51Eux2GGsyC7p138z9t89dI32z0t9UoZCLWSgC2EkgvCO2sXrbIlMUBxFZJxn19qN2HARz0zpPUMORRlCpVX6mFMenpRXlSiWXaVkXOd(SjAg1(YC0EQZ2)1sUAI7ObWZ5QQuFiVJsBg(kOHELZB)hG4OoZX6NPVwSUTE5rDs(gN00MaP1NxqvtkoQbdMMbSbEKa5(e(YR8gjhsa(z9Cmx51af9xjq98aQ7qO5QSxkMvEw7i8IJ8jMk)kp3D7oMPXbbFsf6)nxH18zdXuupHt)iQdhwAN)vamBJCpYY42ZN55o6SMqYUDnXKD7AdkN)nutthDWheUo8pWa5QqOTHpzviBZUUB3lSmfQ6rP0oyT9ymqoC3TXZmV1ZmVZZmx3ZO1Q4bXMoDqt7ID7yqixxiXYeV7t73nZS4urXQZFoFM)xBzI9ZdeDI(KQqDe1Ul)Z9g(0024X20XUDhyQ0RMUV9g3GBLHoNFPRC2OG))]]  )

