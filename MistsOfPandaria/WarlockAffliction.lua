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

-- Alias numeric soul_shards for APLs that expect a number and ensure key exists early.
spec:RegisterStateExpr( "soul_shards", function()
    return ( state.soul_shards and state.soul_shards.current ) or 0
end )

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

-- Register state expressions for percent_increase
for _, dot in ipairs({"agony", "corruption", "unstable_affliction"}) do
    spec:RegisterStateExpr("dot." .. dot .. ".percent_increase", function()
        return get_dot_percent_increase(dot)
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
    local v = get_dot_percent_increase(dot)
    if v == nil then return 0 end
    return v
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
    },
    
    curse_of_elements = {
        id = 1490,
        duration = 300,
        max_stack = 1,
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
            if buff.soulburn.up then return false, "soulburn active" end
            local shards = ( state.soul_shards and state.soul_shards.current ) or 0
            if shards < 1 then return false, "requires 1 soul shard" end
            return true
        end,

        handler = function()
            applyBuff( "soulburn" )
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
spec:RegisterStateExpr( "soul_shards_deficit", function() return state.soul_shards and ( state.soul_shards.max - state.soul_shards.current ) or 0 end )
spec:RegisterStateExpr( "current_soul_shards", function() return state.soul_shards and state.soul_shards.current or 0 end )

-- Minimal safety shims for malformed imports that may reference unit "focus" or bare ticking/remains.
-- These prevent compiler errors without changing behavior.
spec:RegisterStateTable( "focus", setmetatable({ current = 0 }, { __index = function() return 0 end }) )
spec:RegisterStateExpr( "ticking", function() return 0 end )
spec:RegisterStateExpr( "remains", function() return 0 end )

-- Movement shim used by some imported APLs
spec:RegisterStateExpr( "movement", function()
    -- Provide a minimal structure with remains for conditions like movement.remains>0
    return setmetatable({ remains = 0 }, { __index = function(_, k) if k == "remains" then return 0 end return 0 end })
end )

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
    
    potion = "jade_serpent",
    
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
spec:RegisterPack( "Affliction", 20250824, [[Hekili:D3ZAVnoos(BjybmC6K2NTCC60lscWCtV3UtdStV4CV3(nlRitNOnYs(KKt3zrG)TFfjLO4JIKs2UpmZIEE0rISQIfR3SOYIjl(6I5RIQil(1GXbZgFtWvJcMo9dZcwmV61TKfZ3gf)C0JWFjlAd8F)P1RttIRsYZOV6108OvuquMVRigE9I5pSljT6xYw8agCdcMTyE0UQNYlwmF(MDRlsEEX8NswTIWNbPmEX8V(us5(L0)nA)YA8VFz(A4NzyE)Y0KYk41RZl2V8VqEojnzeqof5RtsbI4pSF5)iQinp(5)4(LTe8(LVF)Y)(wkvTcMBr(gyC5)J5jBk3)zoKlhTTGeNV5HOQlU7)yvuXZHjzvKSk8buUBZM8SWTKQlH)nKYWUBnj9PDWCkUmz9DNvfLcZE0JfjBYtkiH5RdlJIlswNetgrYIEiLSAWzWKhrH)lK9Fgi()A(FB)YVwKK9mPA)Y)NOIe64G17WKSKQKO0K)fDfiOKAgr(wsgb()rFlQa(BLLNJt1VudWlP7O3vXXt4KWh2TED5L5BVRewpVeLUJC34(aHGJgctclFnlwfanJCKgH2h4g0f4g0F4ojCtu2UO0JyjhC8Gysi57XP7wrocyeCcGbFJjC1UIi6uuHuqVavWPduBlsYlsQEvdguTtBIadofYC44DcZQWVDqCn8hyLKSy4lFx6d7kYOaTkzd52GXdoJo(r03esF1ODBhW(HYNIkwvE)DtWb12C2omBj8pJwrcljfGHmyDWEb(KEkcmXkq(KrxRIQG9FMzivY0jZcz5MOcWAzA(JjXcadGloknnK)JHuxlCQ5fXS9o08hJx5FujvKnDayKSvu)eRtE8PQllH9J4k(23d5LLdQIkEeCxqx4Hv5HRsOm)617xQ9amuX525GxW51ByGpW75)e8F)w0wWRrwm4CL6ePSIXDQYHFC720x3V8t5FvHEl2LHS2zivHqz7k3ntsQAvEvziIebJS)Bf5XWous5tjzpwVvvlgc7CeWvoqljz0HaSeVeeehqCyn0APMjnsOmV6m6ytciR9kiOwth)3rXGZ1AjY9l3vYI7Gghsmiqw043LsjvpbV5l)5F(t8yr2V8bsA(3QHZNam0WKLaYtrzRsBaW8VUF53sQEQwOKURb0jD9ZHXFnIokT4DG4xs2alVxOqby47IR2vq8Yq2atGYiG)pdb(eaJtjr8zqF1lKqydEtcP8UG3Et9j3h0AYIpRWOTP(Xquoc4bGDgk0ymK)ugW)IPlCkRRiVkIZAKyIW(uE2QegQ9tdWU2N5)XueSK8)UJWumG)izbQvWca7gi2oioUWhlIk3EjnoXIIDBRvbSkRnOrC0kCLnU6ZOQe)VrfRLhYSsc2rZt7gsdlblcmdngi1al(bip24v55BEChqSM733ovs4zvzi)T8OHftRoU4g8f4dFjzRjfzq8uMIx3HJVwiZKeMdGlf2452zLL0EVSqOpXUrLk(PuT7HVhzWJhUIW2jyJbE63YE7n1Nvq2a2jkVD2BV1o7sqIlpBa6aV58Zr8GCp2yVywdhHXzlBwZebpOXGLYsUt77dhITtOYKo)T3q81nD254i09g)rIqnuQRwRemPy3JXsFinpFv6UYkql6T34pIuat6zG1j9m6WcxVJzIaLocG9yf6vsAM8Ds8Uks42NIkjN3STj5KVXEwjQu8dKkMdiRIX9XI0euLmt7hMcHYgteOTl2KCGNAEXVSE)s6tapQG)YLWUwjn4aQp5IvVVoAhWN(gE4pnrcrDYtYEmjJOrzrpMNX21pdG6i2pblL4NnvhIZzofGhigE7JSmNDzabalIWirTletg5DTqH7OCdbyTzXVQkc8TNiGnSmy19PV81sEOfVOVU63gTz4D4(Eo(T6Jdt8GYM)EwHryr1cM1jRliLGW)Wn8WP4Hm)yA(drP6MyeB3T72Bjf0GcbZoXfeqRd4hGcA77Bm4cowg4AwZCkVOjUyhPsdsG5poW701XUfjpBcE2PhSrliSpmO7aSXj0pVdmAYtmjjUj0VArAQhy6RxPZlPpKMkfjLSbaBjxlI7RZ4LJWTknD8GnrzrJ2gxDVirRwlOGqeR0NGrfyupYaLU3IcyzZCxOhKydGV9oi)zmCljMRyJxddPjRH5WvEetiJqwrFODyWxk8NTFj)HQb28PcwAim7iDDrHJnSL31MUfKSWC7voz8GvmjT4DLS42FkkD97BQAe86DPnlZFAf31weyq8VqTyisnRJ(afHY5pqc8qVUgJfCtNcy8QbXG5nAaGMzuud(7NmRxW3YUKwYfOlKRWq0v2qedaz0e3xdPHrvYo1CNP4od6fA42yazRmciGuULKMkc4TnLBRchotf003fprCu2yRm)uDFKYA5clhFCMih2FMLYSCglddAYJbwm0QQSEhFbUjFfeNOASGQvfRob8l0RYieXFi3Dy(w6pC5kY6ODPv3nUUqJgUara5V1JF2GG7xCrMbHIcWUeARDi4uKRfIuCmYnjes(oy3KCz8RW7cRLx6oCqflHabqgAVshgv)DQhZecuXLrrwsdndzxnUnMhfkX0Ulie6VDYOz4jqRl1Fb26xk4oRuMz2bir4jOrReJzaHOuewaFwjnh5E4kQp)eRJOfrP6JtDCa3PTOCekfQUva0PwRtDfrwl(Y2RvWWisvee03ixdgJ7m5WuhptrF0Fg8DZqLvFJkuEtmC5)jfVBtVqY9g1xD(UQgFC6E3ucRLpjLTIO8tRVoo88BBKpUETtCqgg54PpkobdkHyIbMee(rECy5wiJSvA6o3F31E0D44noQSkSKMqci262ky3qANv26mB5uQxZHkUlOnrFpu9zZ4k36ELqvWcA4fIHFRHWKvxFE8T1K307gpAMjAqJCwUE8hIewNKDCkUCwd3AOUqY06qdLXpQhidXbhy0C37gXUx3e(KTrwJUFeg)H0bfMqVYaL42BW3p6KLFdEypRKKSO5XfKah9NeNoSwX6fEjDA97iWeTWHwTXl3Kk1dSxm9UN59ngiYr1PrlrPCZl0aJov3A71EedKhyzT7qbfrxaNII)zleQAC4ukRU1)Eoj9FgrwrYkdJHitOzT203F2ZYRg(RjPHRtHqr6e8mMoVgDu5Zon)bprIsREIj)(bZfRGymBUgisR58iRGnjATeRkI0Cj2SwlnIYAfDPR2SsS9i0(0OtGJE8NQa0B5ZK9IAh2Tv8ZsVeYwlV92Hx6IZ7czOuUcvkPwgwANu2qKdUgxcufyMHKyXnNhn4UqahtS22HARbv1v2q5Dm2PLlztgmEFoShkgI1kKshyxOIMkXRsdcFf0ZmHDkuulrI652A5b2cb08hQ9gjoQkr)W9hfDlvDpgXkfo8x2Vm2SNCCjElgTkLQhzvtRsW7)PFIdxMvGVSE9(L)z2zOTF5pxR010gtLQDtdTN5UWB))P4VUv)d)O6dmGERcxFa0KRmbKqlTxa6dgakQiokJoGIccpCaX(8nJvp)dJ5snLZiK(qdYgaQHZoW5hTzeVSmnV6oQmdZ7OWkz5RzrBHXaPFXsfJMe2RdWAHcly8CXX1SI34()xSo3B5xa7gBs(xAbsj3WJxOE0sg9oYvdgIGXzdmoMbJQ9ImTBo3krGgS2emGinG3bS3rqkcx0yYGoolHYzfZwctcbZxnWxStnT)aRXtzkOzV)VxsKBVs1Z)Ed78(OnjNeRH13QgIn1GqnIA9MqwU8B(75yrNSxx8FKqaE7To4lh36W4ZrrjV)774QfVVXfR2aZvBGJoS()3xTbN0vlYE7VNxTEKKr2B)9SKCVVqaTlPJg3b44UlcpU2Lv6b(2w4vRB4L8gYg6f9ROvtSmF7NM3I5VarHaZqCx4MSy(3IkO5EvUy(VSzBEb7kPnjqRJVhT)ZlMxULedZ86zlMZEi962XXm83(v2f4RobUf)NlMZNp7c5Xws87uxrYw(J9YDwmhgmKhBs0I5NTFPXIz)YbWSBzi7xE)DaLVOcirnsPfqiSez6KX6aiuTyo1zKRLvtXw0wwMLPrg9nbyTF5TaTgm2nXAS4cyRzGzie9Kkwj9vyo4bCTF5vSxBQbdWD)YBAxvSzsPQPwPQZynWOwRgU8T3KFClQbQUouKwKWgdfjx5djiL2wGjZI9ybDTdKIZz(WPRGyei3rrGSqfiZGsox7KCSxJix7NqC2032kSbpB6yjgIo8OeYhSsiElxddBcrY6e4BrNsTPwmxuCQfZzkR3C4iUfhIscrH4hpCiYwkT1SGP78bjwxBHSOiAYykMmPbjKZSLWtNfZAsoWq2KK1cKg2i7VfMXGMOIeuBnSArSy(yn7oNIwUHItilBaY6kYUTtPV1ZyIdRnzlx7jU(Jz9NKFUCnO4phtkh2wcMXFTHvYPQYJQTA4YZL2m1c2XRDVU6dYJcHWJOttG4iZnuB8F5WkxlyRBKMoROQBQYaX1TVJhSPCKsuncNgFu9yozgIdyN2qSS5Ci(qN2xFO62Hu9)jrKdzeuh8QkoAkvzbHbcgDozeOzCUlIfXr9f7xodFVHBKdzzi5xfDT0zN3sRkVKnMxFh0UTO3W8gJUioIOb6ZYYz8eowF2nkFSMRypKYUAl5fxhCMdfiCBCt0nQAAYYRDpRYuwym62vTh7Zp0qUqPn7gN7V1QZ0my5MmNmgXm1e7XGIkuCgnec2931zuMU9MuX(kPiU2KyXgzklJDqCSvlSmRDqmwdt2ihLGNCCNBDh5t3vYcSRK5y3vDHHPBzpELUf)Gh0icOWECkg2imIaRTi9nRxSlwRoLeirjA3Kt3r4OtqiXeQrroXAZ15Kl0wwHjQQQtPkCDCxJ3JZ6GTiZnUoVCFz6Vro6N6OTBHi)4kzq06KUH56ZT3p05YC5HO6zvIqJN7(Ic3jX3HS)XMid2EX5oZxzknQm3QS2LC)Xqmoe1DOW)VtP7PBfXWeRMCv(HFtMpm)gtCA4c3AUvF)oR3Kh)fEWSf3g6j2PLcKcZ9OVA06HYPNpL7mfDeHjsgpolZK)ChCNjIRSUSiz2R7A9XikE2befJlbsJu08jrEsjaCPwJ0QCj22RRZT8YRv(u)YgxZVN5SS6t4Hu6dkZqZatLkCCZSnjfB1D)JcYXl4MztLYiTnv6SlxuBtc2BT6)GGY7ocM5xd2MVfKuqvlLBxUG5NM0wNIK2k)uPCKuO(Hy5ebgQMk(NTLSwBJ3OBMZ51DNr42RLOGgAAdoFexd5ixQXj29Gylge7SNRT7fxX8R4e803P6n)RJ3XE2k1w9lXYY5aUo8hWnHhLB3HGHh4ihLRDTbDdljeDFXosjJVn5TFk4(FM5g1MLQjWUZshcFwkgXHDyXxHrwEoWD5UH7O2mqqTDpBwYu4qk9F)jREM(KAn1SX6nnbm9GQ3vp(8cWwm2R1IKVaica8tNbOReAp44QWjnTceSRLMxj)Zimo9gIA)sZeL06IiJDEJEjInIHUk0inEIoOy3wReB5EpUPKi4eeVjI0to6qACsxvqPPbO6ohoaNdh4Hdh8BnoCGGdRiRfGvBMdNBzrE8FR4w2oKL(R9Ar263XAVA2XCuRjmUfoS7dZOVuNTt3htYhxoPpc29usRQTZxqCIOyO01xAzPCW0(qSY7OX6(TPHYqB7Lobb6TBWL5eNtM7S0zjyPF)LTgPWT8md4FgKPCRUHw5M)htCfT7npLFFNBPtTVDWkRLwMq7P2yEK0wZKI3JOk7v8oyfrfW1ze65tdTJ1c2cyY4MvGndykKSYjNIuLvfc)4)wsFKFgP7Zxq6oX34rkRWryDRRZY7YZqS9Sv4oDOg61FZ9gUJAVoADuxQUH)CwKyRO9SJbZr5sDMOnrIE(fSUJOUSAr956xFDa9ARUN)UrrQ(gT)(qbZgTINQU8l(Kg(E7V(tAXv7VAvGLgH)7wfwZEY)LRcMzEAxDwsKmc0SFk6Ws9238K9lAf5(gvlWbmxkDIsnHyqle1Dt4hI2cSbN0P)(sbZ48bGNa74jqGhDBP(XdkhseQfIrPdeKbsGu3SYbcsriJO2moqGgOauSoE2nqdSqQ0npXViwyWwxV)qHDacS7VoT7KdLJpUpAanPjXiQ(R(6nRItcD1FJaEPlFz74qzwH0SFog1HFjocJECsOsEhYL6ZrDBhCYc5UK3o)6FUY5bliO0jJUgNIKABPMAqwXdg4h5Lo40)zqtiFyCONU9Z3T2eVh1k2BRvD6AtCN3cQokrYJCe5lwg75gHAExtjTXxG4I3wppt8pPAkS3Ety4R7ZS3z5o55yTHR3RZWc9JXO7Kdog90mmgtzUX34RfZNPjFy0KlU4e1TmqnxxmvEvVWIurNcfyUJxfH2t87D7xoE0m7O35jSq7ktmgQZoWPxAo9rpONxicAkisBndXL6Nk1uCQeTZUN0IST179Gcj2f5TBqK36N6xDB(yToA)yAi)6Zwv5WYUYwd53d)cEVcUN1RgYhZFWb0em6QJwWM3UH5IdQXwqI61(zBE43xaLcu64SeD08i2)gWSWrLzehj(qRfCDwRtl1d72rlRAbu3u3MWD9EH3eRIfWPm43jUyYS9A5pommyyVLaqKtTR1yHuUs2P5r0CKvTcAOhQS)SpSxLvBNLG1pSCYXmZ(ORHT35NI64rtPHnAh4JTv4hFTAQC9062)NXyoUE4wPeuT9MdwKU(jZAjjTBKTAw8QnTfsGQ(rdEuuo815vcwABQUbPrc50zIywsdsjBmS01qc00pdq(YfiFZouSECl3)35cPfXu80ZrntuMGLIYcjWt)uSsNN00UNdzUAu(81XSqQ3MJ1j9RqqnnfiwGL(jhSy6cu0eARKpZcg7ic9vG8d57ANZYoG4QwU95CDU3sLyOTOfD4JcqhH)ejxmTwAC7NP344ds4qy1YDo4kcn3mgr4wX7O6hvpmRrho5hifTK4dWNRuzzFp9KXO7VREnX40F6IPkXp1EooRe)zX)h]] )


