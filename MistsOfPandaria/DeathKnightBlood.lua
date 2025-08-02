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
spec:RegisterResource( 5 ) -- Runes = 5 in MoP

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

spec:RegisterResource( 5, { -- Runes
    -- Blood Tap rune generation
    blood_tap = {
        aura = "blood_tap",
        last = function ()
            local app = state.buff.blood_tap.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.talent.blood_tap.enabled and 1 or 0 -- Converts Blood Charges to runes
        end,
    },
    
    -- Death Pact rune efficiency
    death_pact = {
        aura = "death_pact",
        last = function ()
            local app = state.buff.death_pact.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.talent.death_pact.enabled and 0.5 or 0 -- Slight rune efficiency bonus
        end,
    },
}, {
    -- Enhanced base rune regeneration
    base_regen = function ()
        local base = 10 -- 10 second base rune regeneration
        local presence_bonus = 1
        local talent_bonus = 1
        
        -- Presence bonuses
        if state.buff.unholy_presence.up then
            presence_bonus = 0.85 -- 15% faster rune regeneration
        elseif state.buff.blood_presence.up then
            presence_bonus = 1.0 -- Normal rune regeneration
        end
        
        -- Talent bonuses
        if state.talent.improved_blood_presence.enabled then
            talent_bonus = talent_bonus * 0.95 -- 5% faster rune regeneration
        end
        
        return base * presence_bonus * talent_bonus
    end,
} )

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
    local runes = {}
    
    spec:RegisterStateExpr( "rune", function ()
        return runes
    end )
    
    -- Blood Runes
    spec:RegisterStateExpr( "blood_runes", function ()
        return state.runes.blood
    end )
    
    -- Frost Runes
    spec:RegisterStateExpr( "frost_runes", function ()
        return state.runes.frost
    end )
    
    -- Unholy Runes
    spec:RegisterStateExpr( "unholy_runes", function ()
        return state.runes.unholy
    end )
    
    -- Death Runes
    spec:RegisterStateExpr( "death_runes", function ()
        return state.runes.death
    end )
      -- Initialize the rune tracking system for MoP
    spec:RegisterStateTable( "runes", {
        blood = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        frost = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        unholy = { count = 2, actual = 2, max = 2, cooldown = 10, recharge_time = 10 },
        death = { count = 0, actual = 0, max = 6, cooldown = 10, recharge_time = 10 }, -- Death runes created from conversions
    } )
    
    -- Rune regeneration mechanics for MoP
    spec:RegisterStateFunction( "spend_runes", function( rune_array )
        if type(rune_array) == "table" then
            local blood_cost, frost_cost, unholy_cost = rune_array[1], rune_array[2], rune_array[3]
            
            -- Spend Blood runes
            if blood_cost and blood_cost > 0 then
                if runes.blood.count >= blood_cost then
                    runes.blood.count = runes.blood.count - blood_cost
                elseif runes.death.count >= blood_cost then
                    runes.death.count = runes.death.count - blood_cost
                end
            end
            
            -- Spend Frost runes
            if frost_cost and frost_cost > 0 then
                if runes.frost.count >= frost_cost then
                    runes.frost.count = runes.frost.count - frost_cost
                elseif runes.death.count >= frost_cost then
                    runes.death.count = runes.death.count - frost_cost
                end
            end
            
            -- Spend Unholy runes
            if unholy_cost and unholy_cost > 0 then
                if runes.unholy.count >= unholy_cost then
                    runes.unholy.count = runes.unholy.count - unholy_cost
                elseif runes.death.count >= unholy_cost then
                    runes.death.count = runes.death.count - unholy_cost
                end
            end
        else
            -- Legacy support for single rune type spending
            local rune_type, amount = rune_array, 1
            
            if rune_type == "blood" and runes.blood.count >= amount then
                runes.blood.count = runes.blood.count - amount
            elseif rune_type == "frost" and runes.frost.count >= amount then
                runes.frost.count = runes.frost.count - amount
            elseif rune_type == "unholy" and runes.unholy.count >= amount then
                runes.unholy.count = runes.unholy.count - amount
            elseif rune_type == "death" and runes.death.count >= amount then
                runes.death.count = runes.death.count - amount
            end
        end
        
        -- Handle Runic Empowerment and Runic Corruption procs
        if talent.runic_empowerment.enabled then
            -- 45% chance to refresh a random rune
            if math.random() < 0.45 then
                applyBuff("runic_empowerment")
            end
        end
        
        if talent.runic_corruption.enabled then
            -- 45% chance to increase rune regeneration by 100% for 3 seconds
            if math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end
    end )
    
    -- Convert runes to death runes (Blood Tap, etc.)
    spec:RegisterStateFunction( "convert_to_death_rune", function( rune_type, amount )
        amount = amount or 1
        
        if rune_type == "blood" and runes.blood.count >= amount then
            runes.blood.count = runes.blood.count - amount
            runes.death.count = runes.death.count + amount
        elseif rune_type == "frost" and runes.frost.count >= amount then
            runes.frost.count = runes.frost.count - amount
            runes.death.count = runes.death.count + amount
        elseif rune_type == "unholy" and runes.unholy.count >= amount then
            runes.unholy.count = runes.unholy.count - amount
            runes.death.count = runes.death.count + amount
        end
    end )
    
    -- Add function to check runic power generation
    spec:RegisterStateFunction( "gain_runic_power", function( amount )
        -- Logic to gain runic power
        gain( amount, "runicpower" )
    end )
end

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
    return runes.blood.count + runes.frost.count + runes.unholy.count + runes.death.count
end )

spec:RegisterStateExpr( "runes_on_cd", function()
    return 6 - total_runes -- How many runes are on cooldown
end )

spec:RegisterStateExpr( "rune_deficit", function()
    return 6 - total_runes -- Same as runes_on_cd but clearer name
end )

spec:RegisterStateExpr( "death_strike_heal", function()
    -- Estimate Death Strike healing based on recent damage taken
    local base_heal = health.max * 0.07 -- Minimum 7%
    local max_heal = health.max * 0.25 -- Maximum 25%
    -- In actual gameplay, this would track damage taken in last 5 seconds
    return math.min(max_heal, math.max(base_heal, health.max * 0.15)) -- Estimate 15% average
end )

-- Register default pack for MoP Blood Death Knight
spec:RegisterPack( "Blood", 20250803, [[Hekili:9EvBpUPrq4FlNIKVK0ukGTVEjY2sn6(qZ1MOk5KVcSgwSxzGLcl31RcXV9oZYB7IHZo6IQIsYDSZlp7SZ8mZ4y58vNTbeb15l2M2lnV1CUHP5CZfoBfpLsD2Ms8ps2d)qcjg(3DrCEi(1NI4Kau5CErMpCcCwbls8PeNDJAX53cYMs9HpV00z7bwqaTwwAUVZ2VEGLx5H)Lu5140kpEi87(cgpPYlILlGJd5zvE)o9ilIz4Sv(r5DGgskIeWp(f5DQwlNTXSKa3Wmk9Fbmsti7IOboF0raWafR)lB9ZycAgJ4SLL4Zb927gqIby4UeC7M1vEhOKiXbJyY)u592kptJ5MvEZQ8858Oa(JjgKebd0G57MFGgfzKrJjSeqBqzZEmnqmemZF5G5MLvELLDhK6lQ8wv5TuXXbuI4GBUiJDKIEDXKEDxryOXoEcfGiJgfyuKkVQYVhqs8reLvaN)iLKYtmW7VYnml(jxEOR4a1fCAa6SL)4UIVUYtqY2tfgqGK6k4UbmQ82UWShMdH)BuceNEdqiEZlhIlg)vy(YEN)ajoLLbV(yXKm08RVC)oFC)AR86Z8P74fy5aptWefbYCGBF5(2EcFRCNLbAbjf947V8So9SkLtq7yzoTHWiReewY8HWmEUq53lsoWJEQ(d92NgNYFKMnmRWYAGFALhQJsosfwQEUJlq)vUNkaDPzD8Qt2XkO0vOL)TZLiUgYGnax2))JlBjUMMmtqIOjcdPRX0bJgPukALh5FalVnYfqJG6KoR6cBOYx7TfHR2Jl(b1xxTY(o)kH50SFxv5fWBHzAezFbfyA8pcXIAp0iG0ZUH0hOzTN37mEHyxgLCu6RPj)AiYoHVyW1DZWR7MtUUBgEDHwZrUaesPzsqmn92ZCH7nx93vAFynnV1LeGy(pbu3f(hK2AAEiu(hOU0eAmJ2WbzpSPgb41cO(KNKg79QJaO11BWmattHCgVwhQ2XzY232dPioHkAJgtd8ANjuIK22QawX2dG70vwx1u)CGNLGDEFKLaNi77H5iJDMALScvTUus3oDLcWmaujsAt5D82tM2WVoejG8Nmk0qzhPFiTr4Ug4D50HzS06dVdTyL3FKW2Fq8HkVpwhBX)8TuCMt4x(mbkfSV9DyVpSX0ffK6Mhu)jaqConXFywZCnjvAkPl2cvXYiS8MzH0KsgzEKKLaLg54yWWCmmOpuMOzu3RBMS96kVm6FxWYWlzopgKJui4X13AGWmzpn3O6()KLahTeIoFljVifTekq7u0xpcN(1DQDZKQP32OxJBNuJ2w(9Y((jLvji2lUT50Y3vHOiU1KIRwUPOG93N9NpT91YNqvKVJH8Oi(JYMgKImcuPbLjW3lYrTzGMcuSwZG7YGjOIw5s4YKayKnvPdcqHHSDYoso9dv3x59ZGA9rWMVmYdnCY9JKH1vy(9LJ9mX7tIhnHWZeWBR361y6y(GuMQ7)uCRm2dwAeogkeleaSC2UnUieYdq6iEilcQTFvL30el3)QNHBbDlibiYF1gcR8(nPRZRUVgd5gDH3FA9VOhzEhlC9vtqBpQ66HPjKrntymb6PIAr)D1umNIDqALfOv)8GDyXBYP7lSzD)UcVfxxE25wvETPQtu7CFrE4MLLL9tsTAPM1gUukAXrwuC2ZUJRg8ovMlgLV(0fyxTWC2i45nQUuNg(I82c9ycmzPI9oDNWlYMZ1TPTwCUL4)ISK9alPHoLaXOpwdFqgzboPEySAL1m50OW)xpW8klvvbozxymH43H7ZSUDnlu7ZS50klZYYlzJjqWZ6q7F4oSUahRRFaOt)mtW2tQPgjyBL7aQaOlcsTHmpjevALocNMhZP2EB2eBUTzTL5Sx3e9llBc)LLTXFTm721LKCItTmsz5vtSwHQPu27Pg2d2WcQbAG1MwyTPdwB0HL2sppl20lRAwTPtJZa5blXGQr8vxazZA7Pygp99chC5SMqDOOUQKnwJBnnfV0EyLLpZAhRwE69XVb3kBvSb2OaNr25)(]]  )

