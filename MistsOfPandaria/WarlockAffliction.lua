-- WarlockAffliction.lua
-- Updated May 30, 2025 


-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Affliction Warlock
local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end



local spec = Hekili:NewSpecialization( 265 ) -- Affliction spec ID for MoP

-- Affliction-specific combat log event tracking
local afflictionCombatLogFrame = CreateFrame("Frame")
local afflictionCombatLogEvents = {}

local function RegisterAfflictionCombatLogEvent(event, handler)
    if not afflictionCombatLogEvents[event] then
        afflictionCombatLogEvents[event] = {}
    end
    table.insert(afflictionCombatLogEvents[event], handler)
end

afflictionCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = afflictionCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

afflictionCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Provide safe state expression shims so loader doesn't warn before events populate these.
spec:RegisterStateExpr( "last_dot_tick", function()
    return rawget( state, "last_dot_tick" ) or 0
end )

spec:RegisterStateExpr( "last_target_death", function()
    return rawget( state, "last_target_death" ) or 0
end )

spec:RegisterStateExpr( "target_died", function()
    return rawget( state, "target_died" ) or false
end )

-- Safety shims to prevent unknown key warnings in parser/emulator.
spec:RegisterStateExpr( "last_ability", function()
    return rawget( state, "last_ability" ) or ""
end )

spec:RegisterStateTable( "last_cast_time", setmetatable( {}, { __index = function() return 0 end } ) )

spec:RegisterStateExpr( "tick_time", function()
    return 0
end )

-- (Do not alias soul_shards; let the resource table exist at state.soul_shards for APL access.)

-- Pet management system for Affliction Warlock
local function summon_demon(demon_type)
    -- Track which demon is active
    -- Note: These state changes only work within ability handlers
    -- This function is for reference/documentation purposes
end

-- Pet stat tracking
local function update_pet_stats()
    local pet_health = UnitHealth("pet") or 0
    local pet_max_health = UnitHealthMax("pet") or 1
    local pet_health_pct = pet_max_health > 0 and pet_health / pet_max_health or 0
    state.pet_health_pct = pet_health_pct
end

spec:RegisterStateExpr("pet_health_pct", function()
    return state.pet_health_pct or 0
end)

-- DoT snapshot tracking for percent_increase logic (now after spec and RegisterAfflictionCombatLogEvent)
local dot_snapshot = {
    agony = { value = 0 },
    corruption = { value = 0 },
    unstable_affliction = { value = 0 },
}

-- Helper to get current snapshot value (spell power + haste + mastery)
local function get_dot_snapshot_value()
    -- MoP: Use UnitStat for spell power (stat 5 = Intellect)
    local spell_power = select(2, UnitStat("player", 5)) or 0
    local haste = UnitSpellHaste and UnitSpellHaste("player") or 0
    local mastery = GetMastery and GetMastery() or 0
    -- Weighted sum, adjust as needed for MoP
    return spell_power + haste + mastery
end

-- Calculate percent increase for a DoT
local function get_dot_percent_increase(dot)
    local last = dot_snapshot[dot] and dot_snapshot[dot].value or 0
    local current = get_dot_snapshot_value()
    if last == 0 then return 0 end
    return math.floor((current - last) / last * 100)
end

-- Register state expressions for percent_increase with safe aura access
for _, dot in ipairs({"agony", "corruption", "unstable_affliction"}) do
    spec:RegisterStateExpr("dot." .. dot .. ".percent_increase", function()
        -- Safe access to avoid nil aura errors
        local aura_table = state.debuff and state.debuff[dot]
        if aura_table and aura_table.up then
            return get_dot_percent_increase(dot)
        end
        return 0
    end)
end

-- Alias for wowsims APL: dotPercentIncrease(spellId)
spec:RegisterStateFunction("dotPercentIncrease", function(spellId)
    local dot
    if spellId == 980 then
        dot = "agony"
    elseif spellId == 172 then
        dot = "corruption"
    elseif spellId == 30108 then
        dot = "unstable_affliction"
    end
    if not dot then return 0 end

    -- Safe access to avoid nil aura errors
    local aura_table = state.debuff and state.debuff[dot]
    if aura_table and aura_table.up then
        local v = get_dot_percent_increase(dot)
        if v == nil then return 0 end
        return v
    end
    return 0
end)

-- Hook DoT application to update snapshot
local dot_spell_ids = {
    agony = 980, -- Agony
    corruption = 172, -- Corruption
    unstable_affliction = 30108, -- Unstable Affliction
}

RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(_, _, _, _, _, _, _, destName, _, _, _, spellID)
    for dot, id in pairs(dot_spell_ids) do
        if spellID == id and destName == UnitName("target") then
            dot_snapshot[dot].value = get_dot_snapshot_value()
        end
    end
end)

-- Soul Shard generation tracking
RegisterAfflictionCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 686 then -- Shadow Bolt
        -- Shadow Bolt can generate Soul Shards
    elseif spellID == 1120 then -- Drain Soul
        -- Drain Soul generates Soul Shards when target dies
    elseif spellID == 48181 then -- Haunt
        -- Haunt generates a Soul Shard when it fades
    end
end)

-- DoT application and tick tracking with pandemic refresh
RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 172 then -- Corruption
        -- Track Corruption application for pandemic refresh
        local remaining = select(6, FindUnitDebuffByID("target", 172, "PLAYER"))
        if remaining then
            -- Pandemic refresh: if remaining duration is less than 30% of base duration, extend it
            local base_duration = 18 -- Corruption base duration in MoP
            if remaining < (base_duration * 0.3) then
                -- Note: Extension handled by default aura system
            end
        end
    elseif spellID == 30108 then -- Unstable Affliction
        -- Track UA application for pandemic refresh
        local remaining = select(6, FindUnitDebuffByID("target", 30108, "PLAYER"))
        if remaining then
            -- Pandemic refresh: if remaining duration is less than 30% of base duration, extend it
            local base_duration = 15 -- UA base duration in MoP
            if remaining < (base_duration * 0.3) then
                -- Note: Extension handled by default aura system
            end
        end
    elseif spellID == 980 then -- Agony
        -- Agony application (stack building handled in aura system elsewhere)
        -- Ensure internal tracking starts
    elseif spellID == 48181 then -- Haunt
        -- Track Haunt application for Soul Shard generation
        -- Note: Haunt tracking handled by default aura system
    end
end)

-- DoT tick damage tracking for Malefic Grasp and Soul Shard generation
RegisterAfflictionCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if (spellID == 172 or spellID == 30108 or spellID == 980) and state and state.soul_shards then
        -- Deterministic expected shard gain model: average proc chance converted to fractional value.
        -- Approximate: baseline 2% per tick, criticals double contribution.
        local critical = select(21, CombatLogGetCurrentEventInfo())
        local base = 0.02
        if spellID == 30108 then base = 0.025 end -- UA slightly higher
        if spellID == 980 then
            -- Agony ramps: use stack-based scaling up to ~4% at 10 stacks.
            local stacks = select(3, FindUnitDebuffByID("target", 980, "PLAYER")) or 1
            base = 0.01 + 0.003 * stacks
        end
        if critical then base = base * 2 end
        -- Record last DoT tick time for state consumers.
        state.last_dot_tick = timestamp or state.query_time or GetTime()
        -- Soul shard generation is handled by the resource system automatically
    end
end)

-- Track target death time to support drain_soul_death modeling and guard UI loader warnings.
RegisterAfflictionCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    if destGUID and destGUID == UnitGUID("target") then
        state.last_target_death = timestamp or state.query_time or GetTime()
        state.target_died = true
    end
end)

-- Nightfall proc tracking
RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 17941 then -- Nightfall
        -- Track Nightfall proc for instant Shadow Bolt
    elseif spellID == 74434 then -- Soulburn
        -- Track Soul Burn application for enhanced spells
    end
end)

-- Enhanced Mana resource system for Affliction Warlock
spec:RegisterResource( 0 )

-- Soul Shards resource system for Affliction
spec:RegisterResource( 7, {
    -- Soul Shard generation from DoT ticks
    dot_generation = {
        last = function ()
            return state.last_dot_tick or 0
        end,
        interval = 3, -- DoT tick interval
    value = function()
            -- Corruption, Agony, and UA ticks can generate Soul Shards
            local shards_generated = 0
            if state.debuff.corruption.up then shards_generated = shards_generated + 0.1 end
            if state.debuff.agony.up then shards_generated = shards_generated + 0.15 end
            if state.debuff.unstable_affliction.up then shards_generated = shards_generated + 0.2 end
            return shards_generated
        end,
    },
    
    -- Drain Soul generation when target dies
    drain_soul_death = {
        last = function ()
            return state.last_target_death or 0
        end,
        interval = 1,
        value = function()
            -- Drain Soul generates 1 Soul Shard when target dies
            local la = rawget( state, "last_ability" )
            return ( la == "drain_soul" ) and state.target_died and 1 or 0
        end,
    },
    
    -- Haunt Soul Shard generation
    haunt_generation = {
        last = function ()
            return state.last_cast_time.haunt or 0
        end,
        interval = 1,
        value = function()
            -- Haunt generates 1 Soul Shard when it fades
            local la = rawget( state, "last_ability" )
            return ( la == "haunt" ) and 1 or 0
        end,
    },
}, {
    -- Soul Shard generation modifiers
    nightfall_bonus = function ()
        return state.talent.nightfall.enabled and 0.1 or 0 -- 10% bonus from Nightfall
    end,
    
    soul_harvest_bonus = function ()
        return state.talent.soul_harvest.enabled and 0.2 or 0 -- 20% bonus from Soul Harvest
    end,
} )

-- Comprehensive Tier Sets with all difficulty levels
spec:RegisterGear( "tier14", { -- Tier 14 (Heart of Fear) - Sha-Skin Regalia
    85316, 85317, 85318, 85319, 85320, -- LFR
    85943, 85944, 85945, 85946, 85947, -- Normal
    86590, 86591, 86592, 86593, 86594, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_affliction", {
    id = 105843,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_affliction", {
    id = 105844,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( "tier15", { -- Tier 15 (Throne of Thunder) - Vestments of the Faceless Shroud
    95298, 95299, 95300, 95301, 95302, -- LFR
    95705, 95706, 95707, 95708, 95709, -- Normal
    96101, 96102, 96103, 96104, 96105, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_affliction", {
    id = 138129,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_affliction", {
    id = 138132,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterGear( "tier16", { -- Tier 16 (Siege of Orgrimmar) - Horrorific Regalia
    99593, 99594, 99595, 99596, 99597, -- LFR
    98278, 98279, 98280, 98281, 98282, -- Normal
    99138, 99139, 99140, 99141, 99142, -- Heroic
    99828, 99829, 99830, 99831, 99832, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_affliction", {
    id = 144912,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_affliction", {
    id = 144915,
    duration = 8,
    max_stack = 3,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009,
    duration = 4,
    max_stack = 1,
} )

-- Notable Trinkets
spec:RegisterGear( "kardris_toxic_totem", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "black_blood_of_yshaarj", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "assurance_of_consequence", 104736, {
    trinket1 = 104736,
    trinket2 = 104736,
} )

spec:RegisterGear( "bloodtusk_shoulderpads", 105564, {
    shoulder = 105564,
} )

-- Meta Gems
spec:RegisterGear( "burning_primal_diamond", 76884, {
    head = 76884,
} )

spec:RegisterGear( "chaotic_primal_diamond", 76895, {
    head = 76895,
} )

-- PvP Sets
spec:RegisterGear( "grievous_gladiator", { -- Season 14 PvP
    -- Head, Shoulder, Chest, Hands, Legs
} )

spec:RegisterGear( "prideful_gladiator", { -- Season 15 PvP
    -- Head, Shoulder, Chest, Hands, Legs
} )

-- Challenge Mode Set
spec:RegisterGear( "challenge_mode", {
    -- Challenge Mode Warlock set
} )

-- Comprehensive Talent System (MoP Talent Trees)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Self-Healing
    dark_regeneration         = { 1, 1, 108359 }, -- Instantly restores 30% of your maximum health. Restores an additional 6% of your maximum health for each of your damage over time effects on hostile targets within 20 yards. 2 min cooldown.
    soul_leech                = { 1, 2, 108370 }, -- When you deal damage with Malefic Grasp, Drain Soul, Shadow Bolt, Touch of Chaos, Chaos Bolt, Incinerate, Fel Flame, Haunt, or Soul Fire, you create a shield that absorbs (45% of Spell power) damage for 15 sec.
    harvest_life              = { 1, 3, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec. Lasts 6 sec. 2 min cooldown.

    -- Tier 2 (Level 30) - Crowd Control
    howl_of_terror            = { 2, 1, 5484 },   -- Causes all nearby enemies within 10 yards to flee in terror for 8 sec. Targets are disoriented for 3 sec. 40 sec cooldown.
    mortal_coil               = { 2, 2, 6789 },   -- Horrifies an enemy target, causing it to flee in fear for 3 sec. The caster restores 11% of maximum health when the effect successfully horrifies an enemy. 30 sec cooldown.
    shadowfury                = { 2, 3, 30283 },  -- Stuns all enemies within 8 yards for 3 sec. 30 sec cooldown.

    -- Tier 3 (Level 45) - Survivability
    soul_link                 = { 3, 1, 108415 }, -- 20% of all damage taken by the Warlock is redirected to your demon pet instead. While active, both your demon and you will regenerate 3% of maximum health each second. Lasts as long as your demon is active.
    sacrificial_pact          = { 3, 2, 108416 }, -- Sacrifice your summoned demon to prevent 300% of your maximum health in damage divided among all party and raid members within 40 yards. Lasts 8 sec. 3 min cooldown.
    dark_bargain              = { 3, 3, 110913 }, -- Prevents all damage for 8 sec. When the shield expires, 50% of the total amount of damage prevented is dealt to the caster over 8 sec. 3 min cooldown.

    -- Tier 4 (Level 60) - Utility
    blood_fear                = { 4, 1, 111397 }, -- When you use Healthstone, enemies within 15 yards are horrified for 4 sec. 45 sec cooldown.
    burning_rush              = { 4, 2, 111400 }, -- Increases your movement speed by 50%, but also deals damage to you equal to 4% of your maximum health every 1 sec. Toggle ability.
    unbound_will              = { 4, 3, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - Demon Enhancement
    grimoire_of_supremacy     = { 5, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons with enhanced abilities.
    grimoire_of_service       = { 5, 2, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. The demon uses its special ability immediately. 2 min cooldown.
    grimoire_of_sacrifice     = { 5, 3, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon sacrificed, and increases your damage by 15%. Lasts until you summon a demon.

    -- Tier 6 (Level 90) - DPS/Utility
    archimondes_vengeance     = { 6, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec recharge.
    kiljaedens_cunning        = { 6, 2, 108507 }, -- Your Malefic Grasp, Drain Life, Drain Soul, and Harvest Life can be cast while moving. When you stop moving, their damage is increased by 15% for 5 sec.
    mannoroths_fury           = { 6, 3, 108508 }, -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown, cost no Soul Shards, and their damage is increased by 500%. They also no longer apply a damage over time effect.
} )

-- Comprehensive Glyph System (40+ Glyphs)
spec:RegisterGlyphs( {
    -- Major Glyphs - Combat Enhancement
    [56232] = "dark_soul",              -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56249] = "drain_life",             -- When using Drain Life, your Mana regeneration is increased by 10% of spirit and you gain 2% of your maximum health per second.
    [56235] = "drain_soul",             -- You gain 30% increased movement speed while channeling Drain Soul, and Drain Soul channels 50% faster.
    [56212] = "fear",                   -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented and takes 20% more damage for 8 sec.
    [56218] = "health_funnel",          -- Health Funnel heals your demon for 50% more but costs 20% less health.
    [56228] = "healthstone",            -- Increases the amount of health restored by your Healthstone by 20% and reduces its cooldown by 30 sec.
    [63302] = "howl_of_terror",         -- Reduces the cooldown of your Howl of Terror by 8 sec and its radius is increased by 5 yards.
    [56240] = "life_tap",               -- Life Tap generates 20% additional mana and no longer costs health.
    [56214] = "malefic_grasp",          -- Malefic Grasp channels 20% faster and increases the damage of your damage over time spells by an additional 10%.
    [56229] = "shadowburn",             -- Shadowburn generates a Soul Shard when it deals damage, rather than only when it kills the target.
    [58070] = "shadow_bolt",            -- Shadow Bolt has a 15% chance to not consume a Soul Shard when empowered by Soul Burn.
    [56226] = "soul_swap",              -- Soul Swap can now affect up to 2 additional nearby targets when used on a target with Corruption, Agony, and Unstable Affliction.
    [56248] = "unstable_affliction",    -- Unstable Affliction can be applied to 3 targets, but its damage is reduced by 25%.
    [63320] = "voidwalker",            -- Increases your Voidwalker's health by 30% and its Taunt now affects up to 3 enemies.
    
    -- Major Glyphs - Resource Management
    [56233] = "demon_training",         -- Your demons deal 10% more damage and take 10% less damage.
    [70947] = "eternal_resolve",        -- Reduces the cooldown of Unending Resolve by 60 sec.
    [56241] = "imp_swarm",              -- Your Wild Imp demons have 30% increased damage and summoning them costs 50% fewer resources.
    [70946] = "dark_regeneration",      -- Dark Regeneration heals you for an additional 25% over 8 sec.
    [56244] = "soul_link",              -- Soul Link spreads 5% of damage taken to all party and raid members within 20 yards.
    [58054] = "burning_rush",           -- Burning Rush increases movement speed by an additional 20% but the health cost is increased by 2%.
    [56239] = "harvest_life",           -- Harvest Life affects 2 additional targets and heals you for 50% more.
    [58079] = "sacrificial_pact",       -- Reduces the cooldown of Sacrificial Pact by 60 sec and increases its absorption by 50%.
    
    -- Major Glyphs - Utility Enhancement
    [56224] = "banish",                 -- Increases the duration of your Banish by 5 sec and allows it to be used on Aberrations.
    [56231] = "create_healthstone",     -- You can have up to 5 Healthstones in your bags, and creating them grants you one immediately.
    [56230] = "create_soulstone",       -- Reduces the mana cost of Create Soulstone by 70% and allows you to have 2 in your bags.
    [63311] = "curse_of_elements",      -- Your Curse of the Elements also increases all damage dealt to the target by 5%.
    [56213] = "enslave_demon",          -- Reduces the cast time of Enslave Demon by 50% and its duration is increased by 10 sec.
    [56223] = "eye_of_kilrogg",         -- Increases the movement speed of your Eye of Kilrogg by 50% and extends its duration by 45 sec.
    [56217] = "unending_breath",        -- Your Unending Breath spell also grants water breathing and increases swim speed by 50%.
    
    -- Minor Glyphs - Visual and Convenience
    [58081] = "verdant_spheres",        -- Your Soul Shards appear as green orbs instead of purple.
    [63310] = "soul_stone",             -- Reduces the mana cost of your Soulstone by 50%.
    [70945] = "floating_shards",        -- Your Soul Shards float around you instead of being contained.
    [58080] = "dark_apotheosis",        -- Changes the visual of your Metamorphosis to be more shadow-themed.
    [63312] = "felguard",               -- Your Felguard appears larger and more intimidating.
    [70944] = "wrathguard",             -- Your Wrathguard dual-wields larger weapons.
    [58077] = "observer",               -- Your Observer has an improved visual effect and tracking abilities.
    [58078] = "abyssal",                -- Your Infernal and Abyssal have enhanced fire effects.
    [63313] = "imp",                    -- Your Imp appears in different colors based on your current specialization.
    [63314] = "succubus",               -- Your Succubus has an improved seduction animation and visual effects.    [63315] = "voidlord",               -- Your Voidwalker appears as a more intimidating Voidlord when using Grimoire of Supremacy.
    [63316] = "shivarra",               -- Your Succubus appears as a Shivarra when using Grimoire of Supremacy.
    [70948] = "terrorguard",            -- Your Felguard appears as a Terrorguard when using Grimoire of Supremacy.
    [70949] = "doomguard",              -- Enhances the visual effects of your Doomguard summon.
    [58076] = "infernal",               -- Your Infernal has enhanced meteor impact and fire aura effects.
      -- Minor Glyphs
    [57259] = "conflagrate",       -- Your Conflagrate spell no longer consumes Immolate from the target.
    [57260] = "demonic_circle",     -- Your Demonic Circle: Teleport spell no longer clears your Soul Shards.
    [56246] = "eye_of_kilrogg",     -- Increases the vision radius of your Eye of Kilrogg by 30 yards.
    [58068] = "falling_meteor",     -- Your Meteor Strike now creates a surge of fire outward from the demon's position.
    [58094] = "felguard",           -- Increases the size of your Felguard, making him appear more intimidating.
    [57261] = "health_funnel",      -- Increases the effectiveness of your Health Funnel spell by 30%.
    [57262] = "hand_of_guldan",     -- Your Hand of Gul'dan creates a shadow explosion that can damage up to 5 nearby enemies.
    [57263] = "shadow_bolt",        -- Your Shadow Bolt now creates a column of fire that damages all enemies in its path.
    [45785] = "verdant_spheres",    -- Changes the appearance of your Shadow Orbs to 3 floating green fel spheres.
    [58093] = "voidwalker",         -- Increases the size of your Voidwalker, making him appear more intimidating.
} )

-- Advanced Aura System with sophisticated generate functions
spec:RegisterAuras( {
    -- Core Affliction DoTs with enhanced tracking
    corruption = {
        id = 146739,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 146739 )
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
            else
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                t.duration = 18
            end
            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("corruption") or 0
            t.refreshable = (t.expires - (state.query_time or GetTime())) <= (t.duration * 0.3)
        end,
    },
    
    agony = {
        id = 980,
        duration = 24,
        tick_time = 2,
        max_stack = 10,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 980 )
            if name and caster == "player" then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
            else
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                t.duration = 24
            end
            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("agony") or 0
            t.refreshable = (t.expires - (state.query_time or GetTime())) <= (t.duration * 0.3)
        end,
    },
    
    unstable_affliction = {
        id = 30108,
        duration = 14,
        tick_time = 2,
        max_stack = 1,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 30108 )
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
            else
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                t.duration = 14
            end
            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("unstable_affliction") or 0
            t.refreshable = (t.expires - (state.query_time or GetTime())) <= (t.duration * 0.3)
        end,
    },

    haunt = {
        id = 48181,
        duration = 8,
        max_stack = 1,
        debuff = true,
    },
    
    curse_of_elements = {
        id = 1490,
        duration = 300,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 1490 )
            
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 300
        end,
    },
    
    seed_of_corruption = {
        id = 27243,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 27243 )
            
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 18
        end,
    },
    
    -- Player buffs (using default aura tracking)
    nightfall = {
        id = 17941,
        duration = 12,
        max_stack = 1,
    },
    
    soul_burn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
    },
    
    -- Dark Soul forms with enhanced tracking
    dark_soul_knowledge = {
        id = 113858,
        duration = 20,
        max_stack = 1,
    },
    
    dark_soul_misery = {
        id = 113860,
        duration = 20,
        max_stack = 1,
    },
    
    -- Channeled abilities
    malefic_grasp = {
        id = 103103,
        duration = 3,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 103103 )
            
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 3
        end,
    },
    
    drain_soul = {
        id = 1120,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 1120 )
            
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 6
        end,
    },
    
    -- Defensive and utility auras (using default tracking)
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
    },
    
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
    },
    
    sacrificial_pact = {
        id = 108416,
        duration = 8,
        max_stack = 1,
    },
    
    -- Movement and utility
    burning_rush = {
        id = 111400,
        duration = 3600,
        max_stack = 1,
    },
    
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
    },
    
    -- Armor buffs
    fel_armor = {
        id = 28176,
        duration = 1800,
        max_stack = 1,
    },
    
    demon_armor = {
        id = 687,
        duration = 1800,
        max_stack = 1,
    },
    
    -- Talent-based auras
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
    },
    
    -- Tier set bonuses (using default tracking)
    tier14_2pc_affliction = {
        id = 105843,
        duration = 30,
        max_stack = 1,
    },
    
    tier14_4pc_affliction = {
        id = 105844,
        duration = 8,
        max_stack = 1,
    },
    
    tier15_2pc_affliction = {
        id = 138129,
        duration = 15,
        max_stack = 1,
    },
    
    tier15_4pc_affliction = {
        id = 138132,
        duration = 6,
        max_stack = 1,
    },
    
    tier16_2pc_affliction = {
        id = 144912,
        duration = 20,
        max_stack = 1,
    },
    
    tier16_4pc_affliction = {
        id = 144915,
        duration = 8,
        max_stack = 3,
    },
    
    -- Legendary cloak proc
    legendary_cloak_proc = {
        id = 148009,
        duration = 4,
        max_stack = 1,
    },
    
    -- Missing auras referenced in action lists (using default tracking)
    dark_soul = {
        id = 113860,
        duration = 20,
        max_stack = 1,
    },
    
    soulburn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
    },
    
    haunting_spirits = {
        id = 157698, -- Custom tracking ID
        duration = 8,
        max_stack = 1,
        generate = function( t )
            -- This is typically generated from Haunt expiration
            local haunt_expired = state.debuff.haunt.remains == 0 and state.debuff.haunt.applied > 0
            
            if haunt_expired then
                t.name = "Haunting Spirits"
                t.count = 1
                t.expires = state.query_time + 8
                t.applied = state.query_time
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    drain_life = {
        id = 689,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 689 )
            
            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 5
        end,
    },
    
    soul_swap = {
        id = 86211,
        duration = 20,
        max_stack = 1,
        
    },
    
    soul_swap_exhale = {
        id = 86213,
        duration = 0.1, -- Very short duration, just for state tracking
        max_stack = 1,
        generate = function( t )
            -- This is a state tracker for when Soul Swap has been exhaled
            if state.prev_gcd[1] and state.prev_gcd[1].soul_swap_exhale then
                t.name = "Soul Swap Exhale"
                t.count = 1
                t.expires = state.query_time + 0.1
                t.applied = state.query_time
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Dark Intent aura
    dark_intent = {
        id = 109773,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Affliction Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities (Shadow Bolt is not used by MoP Affliction)
    haunt = {
        id = 48181,
        cast = function() return 1.5 * haste end,
        cooldown = 8,
        gcd = "spell",
        
        spend = 1,
        spendType = "soul_shards",
        
        startsCombat = true,
        texture = 236298,
        
    handler = function() applyDebuff( "target", "haunt" ) end,
    },
    
    agony = {
        id = 980,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136139,
        
        aura = "agony",
        
        handler = function()
            applyDebuff( "target", "agony" )
        end,
    },
    
    corruption = {
        id = 172,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136118,
        
        aura = "corruption",
        
        handler = function()
            applyDebuff( "target", "corruption" )
        end,
    },
    
    cast_unstable_affliction = {
        id = 30108,
        cast = function() return 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136228,
        
        aura = "unstable_affliction",
        
        handler = function()
            applyDebuff( "target", "unstable_affliction" )
        end,
    },
    
    cast_malefic_grasp = {
        id = 103103,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.04, -- Per tick
        spendType = "mana",
        
        startsCombat = true,
        texture = 136217,
        
        handler = function()
            applyDebuff( "target", "malefic_grasp" )
        end,
        
        finish = function()
            removeDebuff( "target", "malefic_grasp" )
        end,
    },
    
    drain_soul = {
        id = 1120,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.04, -- Per tick
        spendType = "mana",
        
        startsCombat = true,
        texture = 136163,
        
        handler = function()
            applyDebuff( "target", "drain_soul" )
        end,
        
        finish = function()
            removeDebuff( "target", "drain_soul" )
            -- Target died while channeling?
            if target.health.pct <= 0 then
                gain( 1, "soul_shards" )
            end
        end,
    },
    
    cast_seed_of_corruption = {
        id = 27243,
        cast = function() return 2 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136193,
        
        handler = function()
            applyDebuff( "target", "seed_of_corruption" )
        end,
    },
    
    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            -- Costs 15% health, returns 15% mana
            local health_cost = health.max * 0.15
            local mana_return = mana.max * 0.15
            
            spend( health_cost, "health" )
            gain( mana_return, "mana" )
        end,
    },
    
    fear = {
        id = 5782,
        cast = function() return 1.5 * haste end,
        cooldown = function() return glyph.nightmares.enabled and 15 or 23 end,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136183,
        
        handler = function()
            applyDebuff( "target", "fear" )
        end,
    },
    
    curse_of_elements = {
        id = 1490,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136130,
        
        handler = function()
            applyDebuff( "target", "curse_of_elements" )
        end,
    },
    
    -- Soul Shards spenders
    soul_swap = {
        id = 86121,
        cast = 0,
        cooldown = function() return glyph.soul_swap.enabled and 0 or 30 end,
        gcd = "spell",
        
        spend = function() return glyph.soul_swap.enabled and 1 or 0 end,
        spendType = "soul_shards",
        
        startsCombat = false,
        texture = 460857,
        
        usable = function()
            -- Check if there are DoTs on the target
            if not (debuff.agony.up or debuff.corruption.up or debuff.unstable_affliction.up) then
                return false, "target has no affliction DoTs to swap"
            end
            return true
        end,
        
        handler = function()
            -- Store target's DoTs
            applyBuff( "soul_swap" )
            
            -- Remove DoTs from target if not using Exhale
            if buff.soul_swap_exhale.down then
                removeDebuff( "target", "agony" )
                removeDebuff( "target", "corruption" )
                removeDebuff( "target", "unstable_affliction" )
            end
        end,
    },
    
    soul_swap_exhale = {
        id = 86213,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = true,
        texture = 460857,
        
        usable = function()
            return buff.soul_swap.up, "soul_swap buff not active"
        end,
        
        handler = function()
            -- Apply DoTs from Soul Swap to target
            applyDebuff( "target", "agony" )
            applyDebuff( "target", "corruption" )
            applyDebuff( "target", "unstable_affliction" )
            
            removeBuff( "soul_swap" )
            applyBuff( "soul_swap_exhale" )
        end,
    },
    
    -- Cooldowns
    dark_soul_misery = {
        id = 113860,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 463284,
        
        handler = function()
            applyBuff( "dark_soul_misery" )
        end,
    },

    -- Dark Intent (precombat self-buff in APL imports)
    dark_intent = {
        id = 109773, -- Using MoP era raid-wide spellpower/haste buff ID
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = 463285,
        handler = function()
            applyBuff( "dark_intent" )
        end,
        usable = function()
            if buff.dark_intent.up then return false, "dark_intent active" end
            return true
        end,
    },

    
    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 1,
        spendType = "soul_shards",
        
        startsCombat = false,
        texture = 615103,
        
        handler = function()
            -- Summon pet
        end,
    },
    
    -- Defensive and Utility
    dark_bargain = {
        id = 110913,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538038,
        
        handler = function()
            applyBuff( "dark_bargain" )
        end,
    },
    
    unending_resolve = {
        id = 104773,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136150,
        
        handler = function()
            applyBuff( "unending_resolve" )
        end,
    },
    
    demonic_circle_summon = {
        id = 48018,
        cast = 0.5,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            applyBuff( "demonic_circle" )
        end,
    },
    
    demonic_circle_teleport = {
        id = 48020,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607512,
        
        handler = function()
            -- Teleport to circle
        end,
    },
    
    -- Talent abilities
    howl_of_terror = {
        id = 5484,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607510,
        
        handler = function()
            -- Fear all enemies in 10 yards
        end,
    },
    
    mortal_coil = {
        id = 6789,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607514,
        
        handler = function()
            -- Fear target and heal 11% of max health
            local heal_amount = health.max * 0.11
            gain( heal_amount, "health" )
        end,
    },
    
    shadowfury = {
        id = 30283,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 457223,
        
        handler = function()
            -- Stun all enemies in 8 yards
        end,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 538443,
        
        handler = function()
            applyBuff( "grimoire_of_sacrifice" )
        end,
    },
    
    -- Missing abilities referenced in action lists
    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 651447,
        
        handler = function()
            -- Instant damage spell
        end,
    },

    -- (removed legacy generic summon_pet; use explicit summons or alias below)
    
    summon_infernal = {
        id = 1122,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 1,
        spendType = "soul_shards",
        
        startsCombat = false,
        texture = 136219,
        
        handler = function()
            -- Summon infernal
        end,
    },

    drain_life = {
        id = 689,
        cast = function() return 5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.04, -- Per tick
        spendType = "mana",
        
        startsCombat = true,
        texture = 136169,
        
        handler = function()
            applyDebuff( "target", "drain_life" )
        end,
        
        finish = function()
            removeDebuff( "target", "drain_life" )
        end,
    },
    
    soulburn = {
        id = 74434,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "soul_shards",
        
        startsCombat = false,
        texture = 463286,
        
        usable = function()
            if buff.soul_burn.up then return false, "soul burn active" end
            local shards = ( state.soul_shards and state.soul_shards.current ) or 0
            if shards < 1 then return false, "requires 1 soul shard" end
            return true
        end,

        handler = function()
            applyBuff( "soul_burn" )
        end,
    },
    
    -- Summon demons (MoP: cost 1 Soul Shard, 6s cast)
    summon_imp = {
        id = 688,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136218,
        handler = function()
            -- Summon Imp
        end,
    },
    summon_voidwalker = {
        id = 697,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136221,
        handler = function()
            -- Summon Voidwalker
        end,
    },
    summon_succubus = {
        id = 712,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136220,
        handler = function()
            -- Summon Succubus
        end,
    },
    summon_felhunter = {
        id = 691,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136217,
        handler = function()
            -- Summon Felhunter
        end,
    },

    -- (dispatcher version removed; alias mapping provided in aliases section)
} )

-- Ability aliases for action list compatibility
spec:RegisterAbilities( {
    unstable_affliction = { id = 30108, alias = "cast_unstable_affliction" },
    malefic_grasp = { id = 103103, alias = "cast_malefic_grasp" },
    seed_of_corruption = { id = 27243, alias = "cast_seed_of_corruption" },
    -- Generic import alias used by APLs like summon_pet,pet_type=felhunter
    summon_pet = { id = 691, alias = "summon_felhunter" },
} )

-- State Expressions for Affliction
-- Avoid naming collision with the soul_shards resource table; rely on resource access or the alias below.
spec:RegisterStateExpr( "soul_shards_deficit", function()
    local r = class and class.resources and class.resources.soul_shards and class.resources.soul_shards.state
    if r then
        local max_val = r.max or 0
        local cur = r.current or 0
        return max_val - cur
    end
    return 0
end )
spec:RegisterStateExpr( "current_soul_shards", function()
    local r = class and class.resources and class.resources.soul_shards and class.resources.soul_shards.state
    if r then
        return r.current or 0
    end
    return 0
end )

-- Rely on the resource system to create `state.soul_shards`; avoid shadow proxy tables that can mask initialization.

-- Provide minimal movement table for APL references like movement.remains
spec:RegisterStateTable( "movement", setmetatable( { remains = 0 }, { __index = function() return 0 end } ) )

spec:RegisterStateExpr( "nightfall_proc", function()
    return buff.nightfall.up and 1 or 0
end )

spec:RegisterStateExpr( "soul_harvest_active", function()
    return buff.soul_harvest.up and 1 or 0
end )

spec:RegisterStateExpr( "haunt_debuff_active", function()
    return debuff.haunt.up and 1 or 0
end )

spec:RegisterStateExpr( "malefic_grasp_bonus", function()
    return buff.malefic_grasp.up and 0.25 or 0 -- 25% damage bonus
end )

spec:RegisterStateExpr( "dark_soul_bonus", function()
    return buff.dark_soul.up and 0.3 or 0 -- 30% damage bonus
end )

spec:RegisterStateExpr( "spell_power", function()
    return GetSpellBonusDamage(6) -- Shadow school
end )

-- Expose options to APL via state expressions
spec:RegisterStateExpr( "soc_spread", function()
    return state.settings and state.settings.soc_spread and 1 or 0
end )

-- Pet management settings exposure
spec:RegisterStateExpr( "auto_resummon_pet", function()
    return state.settings and state.settings.auto_resummon_pet and 1 or 0
end )

spec:RegisterStateExpr( "need_pet", function()
    -- Returns 1 if auto-resummon is enabled and we need to summon or swap to preferred pet.
    if not ( state.settings and state.settings.auto_resummon_pet ) then return 0 end
    if not ( pet and pet.alive ) then return 1 end
    local pref = ( state.settings and state.settings.preferred_pet ) or "felhunter"
    local fam = UnitCreatureFamily and UnitCreatureFamily( "pet" ) or nil
    if not fam then return 1 end
    local desired = ({ imp = "Imp", voidwalker = "Voidwalker", succubus = "Succubus", felhunter = "Felhunter" })[ pref ] or "Felhunter"
    return fam ~= desired and 1 or 0
end )

-- Range
spec:RegisterRanges( "agony", "fear" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = nil,
    
    package = "Affliction",
} )

-- Settings
spec:RegisterSetting( "soc_spread", true, {
    name = strformat( "Enable %s Spread", Hekili:GetSpellLinkWithTexture( 27243 ) ),
    desc = strformat( "When enabled, the APL may use %s with %s to spread DoTs in AoE. Disable to avoid SoC spread on cleave.",
        Hekili:GetSpellLinkWithTexture( 27243 ), Hekili:GetSpellLinkWithTexture( 74434 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "preferred_pet", "felhunter", {
    name = "Preferred Demon (Precombat)",
    desc = "Which demon to keep active outside combat.",
    type = "select",
    width = 1.5,
    values = function()
        return {
            imp = "Imp",
            voidwalker = "Voidwalker",
            succubus = "Succubus",
            felhunter = "Felhunter",
        }
    end,
} )

spec:RegisterSetting( "auto_resummon_pet", true, {
    name = "Auto Resummon Preferred Pet (OOC)",
    desc = "If enabled, precombat recommendations will summon or swap to your preferred demon.",
    type = "toggle",
    width = 1.5,
} )

-- Default pack for MoP Affliction Warlock
spec:RegisterPack( "Affliction", 20250904, [[Hekili:D3ZAVnoos(BjybmCM0TpB540PxehG5MEVDNgyNEX5EV9BwwrMorBKL8jjNEYIa)B)kskrXhfjLSDFyMf98OJezvflwVzrLLtw(1Llwhvrw(lbJdMn(JJVEuW0GBd(WYfvVUJSCXUO4NJEe(lzrBH)7pUztAsCvsEg9vVMMhTMcIY89fXWRxU4H9jPv)C2YhuG7TbxVCr0(QNYlwUyX29BksEE5INswVMWhkPmE5IV(us5Hv0)n6WQAeFyv(g4NzO8WQ0KYk41BYloS6VqEojnzeqhf5BssbS)hoS6FevKMh)8F8WQwk9WQ3Fy1FFhLCwdZTiFlmU8)XIKTLh(mhYLJ2vqIZ3(qu1vZ)pwhv8CyswfjRcFaL73UnplChP6DW)gs5uZ3qsFApmNI3LSz(fvrPWSh9yrY28Kcsy(MWYO4IKnjXKrKSOhsjRhCbm5ru4)c5WNbI)VM)3oS6RfjzptQoS6)jQiHooy9omjlPkjkn5FrxbckPMrKVJKrG)F03IkG)wz5L4u9l1a8D0TY5vC8eoj8H9B2u(U8DZlH1ZlrP7jZh3hieCYqysy5RzXQaOzKJ0i0(a3GUa3G(d3jHBJY2hLEcl5Gthetcj)AC6(1KtagbNbyW3ycxVViIofvif0lqfC(a1UIK8IKQx1Gbv70MiWGZHmhoENWSk8Bhexd)bwjjlg(Y3N(W(ImkqRs2sUly8GlOJFe9nH0xnA)UbSFO8POI1L3pFcoO2LZ2HzlH)z0AsyjPamKbRd2lWN0trGjwbYNm6gvufC4ZmdPsMozwil3gvawltZFmjwayaCXrPPH8FmK6AHtnViMT3HM)y8A)JkPISTdaJKTM6NytYJpv9Usy)iUIV99qEz5GQOIhb3f0fEyvE46ekZVE9(LApadvCUDj4fCr9gg4d8E(pb)3VfTd8AKfdoxPorkRyCNQC4h3Tl91dR(u(xvO3I9ziRDgsviu2UY8zssvRZRkdrKiyK9FRipg2HskFkj7X6TQAXqyNJaUYbAjjJoeGL4LGG4aIdRHwl1mPrcL5vNrhBtazTxbb1A64)okgCUwlrEy1(swCh04qIbbYIg)UukP6j4nF5p)tFIhlYHvpqsZ)wnC(eGHgMSeqEkkBDAdaw81dR(ws1t1cL0DnGoPRFom(Rr0rPfVde)sYwy59cfkadFFC1(cIxgYwycugb8)ziWNayCkjIpd6REHecBWBtiLZdE7n1NCFqRjl(ScJ2L6hdr5iGha2fOqJXq(tza)lMUWPSUI8QioRrIjc7t5zRtyO2pna7AFM)htrWsY)7EctXa(JKfOwblaSBHy7G44cFSiQC37OXjwuSFxTkGvzTbnIJwHRSXvFgvL4)nQyT8qMvsWoAEA3qAyjyrGzOXaPgyXpa5XgVopF7J7bI1C)(UPscpRld5VLhnSyA1Xf3GVaF4ljBdPidINYu8Aoo(AHmtsybaUuyJNBNvws79YcH(e7gvQ4Ns1Uh(EKbpE4AcBNGng4PFl7T3uFwbzlyNO8UzV9w7SlbjU8SbOd82lVeXdY9yJ9QznCegNTSznte8Ggdwkl5oTVpCi2oHkt6Y3EdXx30zxIJq3B8Nic1qPUATsWKIDpgl9H0881P7lRaTO3EJ)isbmPNbwN0ZOdlCZEMjcu6ia2JvOxjPzYVsI3xrc39uuj5YMTnjN8n2ZkrLIFGuXCazvmUpwKMGQKzA)Wuiu2yIaTDXMKd8uZl(5nhwrFc4rf8xUc21kPbhq9jxS(91r7a(03Yd)PjsiQtEs2Jjzenkl6X8m2U(fauhX(jyPe)SP6qCoZPa8aXWBFKL5SpdiayregjQDHyYiVRfkChLBjaRnl(vvrGV9ebSHLbRUp9LVwYdT4f91v)2OndVd33ZPVvFAyIhu2I3ZkmclQwWSoztbPee(hULhofpK5htZFikv3eJy7UD3EhPGguiy2jUGaADa)auqBFFJbxWXYaxZAMt5fnXf7ivAqcm)XbENUo2Ti5ztWZo9GnAbH9HbDhGnoH(P9GrtEIjjXnH(vlst9atF9ADEj9H0uPiPKTayl5ArCFDgVCeUvPPJhSnklA0U4Q7fjA1AbfeIy18emQaJ6rgO09wualBM7c9GeBa8DZH8NXWTKyUInEnmKMSbMdx5rmHmczn9H2HbFPWF2Hv8hQgyZNkyPHWSJ01ffo2WwE3y6wqYcZDx7KXdwXK0I3xYIB)PO0nVVPQrWR3N2Sm)X1CxBrGbX)c1IHi1So6duekN)ajWd96gmwWTDkGXRhedM3ObaAMrrn4VFYSEbFl7sAjxGUqUgdrxBdrmaKrtCFdKggvj7CZDMI7mOxOHBJbKTYiGas5osAQiG32uUTkC4mvqtFx8eXrzJTY8t19rkRLlSC8XzICy)jwkZYzSmmOjpgyXqRQYM98f4281qCIQXcQwvS6eWVsVkJqe)HC3H57O)W7wt2eTpTA(46cnA4cebK)wp(zdcUFXfzgekka7sOT2HGtrUwisXXi3Kqi5xb7MK3f)k8UWA5LUdhuXsiqaKH2R0Hr1FN6XmHavCzuKL0qZq2vJBJ5rHsmT7ccH(7MmAgEc06s9xHT(LcUZkLzMDaseEcA0kXygqikfHfWNvsZrUhUI6ZpX6iAruQ(0uhhWDAlkhHsHQBfaDQ16uxrK1IVS9AfmmIufbb9nY1GX4otoo1Xlu0h9NbF3muz13OcL3edx(FsX720RKCVr9vNVVQXhNU3nLWA5tszRik)86RJdp)2g5JRx7ehLHroE6JItWGsiMyGjbHFKhhwUdYiBTMUZ9ZVXJUdhVXrLvHL0esaXw3wb7gs7SYwNzlNt9AouXDbTn6xdvF2mUYTUxjufSGgEHy43zimz11NhFBn5n9dJhnZenOrolxp(JrcRtYoofxUOHBnuxizADOHY4h1dKH4GdmAU7DRy3RBcFY2iRr33dJ)q6GctOxBGsC7n47hDYYVbpSNvssw080csGJ(ZIthwRy9cVKoT(DeyIw4qR24LBsL6b2lME3Z8(wde5O60OLOuU5fAGrNQBT9ApIbYJSS2DOGIOlGZrX)SfcvnoCkLv36FpNK(pJiRjzLHXqKj0SwB67p7z5vd)nK0WnPqOiDcEgtNxJoQ8zNM)GNirPvpXKF)G5IvqmMnxdeP1cEKvWMeTwIvfrAUeBwRLgrzTMU0vBwj2EeAFA0jWrp(tva6T8zYErTd72k(zPxczRL3E74lDXLDHmukxHkLuldlTtkBiYbxJlbQcmZqsS4MZJgCxiGtjwB7qT1GQ6kBO8og70YLSjdgVVe2dfdXAfsPdSlurtL4vPbHVc6zMWofkQLir9CBT8aBHaA(d1EJehvLOF4(JIULQUhJyLch(lhwfB2toUeVfJwLs1JSQPvj49)0pYHlZkWx2S5WQ)m7m0oS6NQv6AAJPs1UPH2ZCx5T))u8x3Q)HFu9bgqVvHRpaAY1MasOL2la9bdafvehLrhqrbHhoGyF(2XQN)HXCPMYzesFObzda1Wzp48J2mIVRmnVAovMH5DuyLS81SODWyG0VyPIrtc71byTqHfmEP44AwZBC))lwN7T6lGDJTj)lTaPKB4XRupAjJEh56bdrW4SbghZGr1ErM2TxALiqdwBcgqKgWpaS3rqkcx1yYGoolHYzfZwctcbZxpWxStnT)aRXtzkOzV)VxsKBVs1Z)El78(OnjNeRH13QgIn1GqnIA9MqwU8B(75yrNSxx8FKqaE7To4lh36W4lrrjV)774QfVVXfR2aZvBGJoS()3xTbN1vlYE7VNxTEKKr2B)9SKCVVqaTlPtg3b44UlcpU2Lv6b(2w4vRB4L8gYg6v9ROvtSmF7NM3YfVarHaZq(sW9TOcAUxLlx8ZB3LxWUsAtc0647rh(8YfL7iXWmVz2YfShsVNDCmd)TFHDZ9QtGB5)5Yf85ZUjESLe)o1vKSJ)yVCNLlGbd5XMeTCXfhwzSyoSAam7wgYHv3phO8LvajQrkTacHLitNmwhaHQLlOoJCTSAk2I2YYSmnYOVjaRdRUdO1GXUjwJfxaBndmdHONuXkPVcZbpGRdRUM9AtnyaUhwDB7QIntkvn1kvDbRbg1A1WvV9M8JBrnq11HI0Ie2yOi5AFibP02cmzwShlORDGuCoZhoDfeJa5okcKfQazguY5gNKJ9Ae5A)eIZM(2wHn4zthlXq0HhLq(aLqefoA5IjTJxP4sYKO3c5WOdHWADQ9YRxaX3ALd4f8TKOOKqui(XJhImcUTMfmDNpiX6AlKffrtgtXKjnOSabEjpDwmRj5a3yBswlqAywS)wygdAIksqT1WQfXYfJ1S7CoA5gkoHSSbiRRi72oL(gmJjoS2KTCTN46pM1Fs(5Y1GI)CmPCyBjyg)1gwjNQk1P2QHRUuAZulyhV296QpilI9gEeDAcehzUHAJ)lUvUEQn3IW6wSrtrv3uLbIRBFhpWu5iLOAengFq5cQEmNmdXbStBiw2CogFOt7RpuD7qQ()KiYHmcQdEvfhnLQSGWabJoNmc0mU0fXI4O(QdRMHV3WnYHSmK8RIUw6SZBPvLxYgZRVdA3w0ByEJrxeNq0a9zz5mEchRp7gLpvZvShszxTL8IRdoZHceUnUj6gvnnz51UNvzklmgD7Q2J957AixO0M9qq7V1Ql0my5MmNmgXm1KBocNfOIlxqdUGDZErzgArfjFTjXInYuwg7G4yRwyzw7GyChxjkbp54o36oYNURKfyxjZXUR6cdt3YE8kDl(bpOreqH94umSryebwBr6BwVyxSwDkjqIs0UjNUZJtNGqIjuJICI1MRZjxOTSctuvvNsv460UgVNM1bBrMBCDE5(Y0FJC0p1rB3cr(XvYGO1jDlZ1NBVFOZL5Ydr1ZQeHgp39ffUtIVdz)JnrgS9IlDMVYuAuzUvzTl5(9HyCiQ7qH)FNs3t3kIHjwn5Q8J)MmFC(nM40WfU1CR((DwVjp(l8GzlUn0tStlfifM7jF1O1dLtpFk3zk6ictKmECwMj)5o4otexzDzrYSx316tru8IJikgxcKgPO5tI8Ssa4sTgPv5sSTxxNB5LxR8P(LnUMFpZzz1NWdP0huMHMbMkv44MzBsk2Q7(hfKJxWnZMkLrABQ0zxUO2MeS3A1)bbL3DemZVgSnFliPGQwk3UCbZppPTofjTv(PsnXUJc9dXYjcmunv8pBlzT2gVr3mNZR7oJWTxlrbn00gC(iUgYrUuJtS7bXwmi2zp3y3lUI5xXj4PVt1B(xhVJ9SvQT6xILLZrCD4pIBcpk3UdbdpWrok34Ad6wwsi6(IDKsgFBYB)uW9)mZnQnlvtGDNLoe(SumIJ7WIVgJS8CG7YDd3jTzGGA7E2SKPWXu6)(tw9m9j1kNzJ1BAcy6rvVRE85fGTySxRfjFbqea4Nodqxj0EWXvHtAAfiyxlnVs(NryC6ne1HvMjkP1frg78g9seBedDvOrA8eDqXUTwj2Y9ECtjrWjiEtePNC0X04KUQGstdq1DoCaohoWdho43AC4abhwrwlaR2mhp3YI84)wXTSDil9x71IS1VJ1E1SJ5OwtyClCy3hMrFPoBNUpMKpUCsFeS7PKwvBNVG4erXqPRV0Ys5GP9HyL3rJ19BtdLH22lDcc0B3GlZjoNm3zPZsWs)(lBnsH74zgW)mit5wDdTYn)pM4kA3BEo)(o3sNAF7GvwlTmH2tTX8iPTMjfVhrv2R4DWkIkGRZi0ZNgAhRfSfWKXnRaBgWuizLtofPkRke(P)TK(e)ms3NVG0DIVXJuwHJW6wxNL3LNHy7zRWD6qn0R)M7nCh1ED06OUuDd)5SiXwr7fNcMJYL6mrBIe98lyDhrDz1Y6Z1V(6a61wDp)DJIu9nA)9HIWgDZV3tynIj)x8jTtO93pkA(X6YVwuA2vA)LJI8scXmpTRoljsgbA2pfDyPE7BE2(fTICFJQf4aMlLorPMqmOfI6Uj8drBb2Gt60FFPGzC(iWtGD8eiWJUTu)4bLdjc1cXO0rcYajqQBw5ibPiKruBghjqduakwhp7gObwiv6MN4xelmyRhB2Xc7aey3FDA3jhkhFCF0aAstIru9x91BwfNf6Q)gb8sx(Y2XHYScPz)CmQd)sCeg94KqLCSKl1NJ62o4KfYDjVD(1)CLZdwqqPtgDdofj12sn1GSIhmW3ZlDW5)ZGMq(W4qpXYfdToKZT3M49OwXEBTQZxBI78wq1rjsEKJiFXYyp3iuZ5nL0gFbIlEB98mX)KQPWE7nHHVUVWENL7KNJ1gUEVodl1pgJUto4y0tZWymLfgFJVwUyMM8HrtU4Itu3Ya1CDXu5v9clsfDkuG5oEveApXVF4WQXJMzh9opHfAxzIXqD2bo9sZPp6b98crqtYqARziUu)uPMItLOD29KwKTTEVhuiXUiVDlI8w)u)QBZhR1r77td5xF2Qkhw212Ai)E4xW7vW9IE1q(y(doIMGrxD0c282nmx19gBPtN6is8W2p1tF3xaLcu64SeD08i2)gWS0rLzehj(qRfCDwRtl1d72rlRAbu3w3MWD9EH3eRIfWPm4FqCXKz71YFCyyWWElbGiNAxRXcPCTStZtO5iRAfNqpuz)zFyVkR2olbRFy5KJzM9rxdBVZpf1XJMsdB0oWhBRWp(A1h5AJ1T)pJXCA9WTsjOA7nhSiD9tM1ssA3iB1S4vBAlKav9Jg8OOC4RZReS02uDdsJeYPZeXSKgKs2yyPRHeOPFgG8Llq(MDOy94oU)VlfslIP4PNJAMOmblfLfsGN(PyLopPPDphYCOO85RJzHuVnhRt6xHGAAkqSal9toyX0fOOj0wjFMfm2re6WlwtHcup2TJ47ChQxy5EMZ1HDh4QigoDs1xunrYftRLg3(z6no(GeoewTCNdUIqZTJreUv8oQ(r1dZA0Xt(bs9RU4dWNRuzzFp9KXO7VREnX40F6IPkXp1EooRe)z5)h]] )


