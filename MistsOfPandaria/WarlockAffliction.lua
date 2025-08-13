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
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

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

-- Pet management system for Affliction Warlock
local function summon_demon(demon_type)
    -- Track which demon is active
    if demon_type == "imp" then
        applyBuff("grimoire_of_sacrifice_imp")
    elseif demon_type == "voidwalker" then
        applyBuff("grimoire_of_sacrifice_voidwalker")
    elseif demon_type == "succubus" then
        applyBuff("grimoire_of_sacrifice_succubus")
    elseif demon_type == "felhunter" then
        applyBuff("grimoire_of_sacrifice_felhunter")
    elseif demon_type == "felguard" then
        applyBuff("grimoire_of_sacrifice_felguard")
    end
end

-- Pet stat tracking
local function update_pet_stats()
    local pet_health = UnitHealth("pet") or 0
    local pet_max_health = UnitHealthMax("pet") or 1
    local pet_health_pct = pet_health / pet_max_health
    
    -- Update pet health state for Dark Pact calculations
    if state then
        state.pet_health_pct = pet_health_pct
    end
end

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
                -- Extend duration by base duration
                applyDebuff("target", "corruption", base_duration)
            end
        end
    elseif spellID == 30108 then -- Unstable Affliction
        -- Track UA application for pandemic refresh
        local remaining = select(6, FindUnitDebuffByID("target", 30108, "PLAYER"))
        if remaining then
            -- Pandemic refresh: if remaining duration is less than 30% of base duration, extend it
            local base_duration = 15 -- UA base duration in MoP
            if remaining < (base_duration * 0.3) then
                -- Extend duration by base duration
                applyDebuff("target", "unstable_affliction", base_duration)
            end
        end
    elseif spellID == 980 then -- Agony
        -- Agony application (stack building handled in aura system elsewhere; remove manual addStack call)
        -- Ensure internal tracking starts
    elseif spellID == 48181 then -- Haunt
        -- Track Haunt application for Soul Shard generation
        applyDebuff("target", "haunt", 12) -- Haunt duration in MoP
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
        state.soul_shards.generate( base )
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
spec:RegisterResource( 0, {
    -- Life Tap mana restoration (Warlock signature mechanic)
    life_tap = {
        last = function ()
            return state.last_cast_time.life_tap or 0
        end,
        interval = 1.5, -- Life Tap GCD
        value = function()
            -- Life Tap converts health to mana (30% max mana in MoP)
            return (state.last_ability and state.last_ability == "life_tap") and state.mana.max * 0.30 or 0
        end,
    },
    
    -- Dark Pact mana return (from demon health)
    dark_pact = {
        last = function ()
            return state.last_cast_time.dark_pact or 0
        end,
        interval = 1.5, -- Dark Pact GCD
        value = function()
            -- Dark Pact converts demon health to mana
            return (state.last_ability and state.last_ability == "dark_pact") and state.mana.max * 0.25 or 0
        end,
    },
}, {
    -- Base mana regeneration for Affliction
    base_regen = function ()
        local base = state.mana.max * 0.01 -- 1% base (Warlocks have low base regen)
        local spirit_bonus = (state.stat.spirit or 0) * 0.4 -- Spirit is less effective for Warlocks
        
        -- Fel Armor bonus to mana regeneration
        if state.buff.fel_armor.up then
            base = base * 1.20 -- 20% bonus
        end
        
        return (base + spirit_bonus) / 5 -- Convert to per-second
    end,
    
    -- Improved Life Tap talent bonus
    improved_life_tap = function ()
        return state.talent.improved_life_tap.enabled and 0.2 or 0 -- 20% spell power as mana efficiency
    end,
} )

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
            return (state.last_ability and state.last_ability == "drain_soul") and state.target_died and 1 or 0
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
            return (state.last_ability and state.last_ability == "haunt") and 1 or 0
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
        id = 172,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        pandemic = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 172 )
            
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
                t.count = count > 0 and count or 1
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
            t.duration = 24
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
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 14
        end,
    },
    
    cast_haunt = {
        id = 48181,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 48181 )
            
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
            t.duration = 8
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
    
    -- Proc auras with sophisticated tracking
    nightfall = {
        id = 17941,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 17941 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    soul_burn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 74434 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Dark Soul forms with enhanced tracking
    dark_soul_knowledge = {
        id = 113858,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 113858 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    dark_soul_misery = {
        id = 113860,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 113860 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
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
    
    -- Defensive and utility auras
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 104773 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 110913 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    sacrificial_pact = {
        id = 108416,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108416 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Movement and utility
    burning_rush = {
        id = 111400,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 111400 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108482 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Armor buffs
    fel_armor = {
        id = 28176,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 28176 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    demon_armor = {
        id = 687,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 687 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Talent-based auras
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108415 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108503 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Tier set bonuses
    tier14_2pc_affliction = {
        id = 105843,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 105843 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    tier14_4pc_affliction = {
        id = 105844,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 105844 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    tier15_2pc_affliction = {
        id = 138129,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 138129 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    tier15_4pc_affliction = {
        id = 138132,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 138132 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    tier16_2pc_affliction = {
        id = 144912,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 144912 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    tier16_4pc_affliction = {
        id = 144915,
        duration = 8,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 144915 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Legendary cloak proc
    legendary_cloak_proc = {
        id = 148009,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 148009 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Missing auras referenced in action lists
    dark_soul = {
        id = 113860,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 113860 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    soulburn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 74434 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
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
    
    dark_intent = {
        id = 80398,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 80398 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
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
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 86211 )
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
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
} )

-- Affliction Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities
    shadow_bolt = {
        id = 686,
        cast = function() return 2.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.075,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136197,
        
        handler = function()
            -- Deterministic shard model handled via resource generator; remove RNG here.
            if state.soul_shards and state.soul_shards.generate then state.soul_shards.generate( 0.15 ) end
        end,
    },
    
    cast_haunt = {
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
    
    cast_agony = {
        id = 980,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136139,
        
        handler = function()
            applyDebuff( "target", "agony" )
            -- Set initial stacks to 1
            debuff.agony.stack = 1
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
    dark_soul = {
        id = 113860,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538042,
        
        handler = function()
            applyBuff( "dark_soul_misery" )
        end,
    },

    -- Dark Intent (precombat self-buff in APL imports)
    cast_dark_intent = {
        id = 109773, -- Using MoP era raid-wide spellpower/haste buff ID
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = 463286,
        handler = function()
            applyBuff( "dark_intent" )
        end,
        usable = function()
        if buff.dark_intent.up then return false, "dark_intent active" end
            return true
        end,
    },
    dark_intent = { id = 109773, alias = "cast_dark_intent" },
    
    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 1,
        spendType = "soul_shards",
        
        startsCombat = false,
        texture = 603013,
        
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
    
    dark_intent_legacy = { -- renamed to avoid duplicate key; kept for older imports referencing spellID 80398
        id = 80398,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = false,
        texture = 463286,
        
    handler = function() applyBuff( "dark_intent" ) end,
    },
    
    summon_pet = {
        id = 688, -- Imp
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.64,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136218,
        
        handler = function()
            -- Summon demon pet
        end,
    },
    
    cast_summon_infernal = {
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
    -- Ability name aliases to avoid aura/ability key collision while satisfying imports.
    haunt = { id = 48181, alias = "cast_haunt" },
    agony = { id = 980, alias = "cast_agony" },
    unstable_affliction = { id = 30108, alias = "cast_unstable_affliction" },
    malefic_grasp = { id = 103103, alias = "cast_malefic_grasp" },
    seed_of_corruption = { id = 27243, alias = "cast_seed_of_corruption" },
    summon_infernal = { id = 1122, alias = "cast_summon_infernal" },
    
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
        texture = 460957,
        
        handler = function()
            applyBuff( "soul_burn" )
        end,
    },
} )

-- State Expressions for Affliction
spec:RegisterStateExpr( "soul_shards", function() return state.soul_shards and state.soul_shards.current or 0 end )
spec:RegisterStateExpr( "soul_shards_deficit", function() return state.soul_shards and ( state.soul_shards.max - state.soul_shards.current ) or 0 end )
spec:RegisterStateExpr( "current_soul_shards", function() return state.soul_shards and state.soul_shards.current or 0 end )

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

-- Range
spec:RegisterRanges( "shadow_bolt", "agony", "fear" )

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

-- Default pack for MoP Affliction Warlock
spec:RegisterPack( "Affliction", 20250811, [[Hekili:fNvBVXTns4FlgfyTDRVTRw71XU1RbYHCaxmAkcUnf3houjXvIAxwljQtuk(mWc9B)MH6fsjrPv2jT5dXXwA4mKZ8mpZWr2w2FYEJpjJA)RlxSC1IBSSMBD5QBwDT9MSNtO2BsiEps2b)smjc(5BdcczEzmEm(QNd5eFufcEEQh8A7nBZzHzVp2ERz9UeKnH6bp(6v2B2Z89PLYsfE2B(0EMOWf)hPWTYYfU8a4VL2SWnKjYGxhWtlC)N0hzHS52BKpuEsObK8Wm4x)v5jJgt2gs9T)72BivB6Suw8J0ml7nEPSmAkJa)gNh6ZFkEUpj9rh4SeopLgryXGLURWDv9HVzTzW(VJ(vABBEqGMMYtugpHl)Fy5x(Aw(wAQGM(ilEhQIREvQiKZ9DcYtFgvXQbvXjfUzKqAC2CsQ3EwepgIqoFMgVJsI9OZRwuH7HdfUn(pZY24lVVW1ALAV0SdXTY1dUvI4FMgH7eD9SqPM08yNYF3bbcLWbNYigUwu7VzqTJR8ZuhAmnIrrDVwgWNIYjCPUVzY6(UjRA4pbnFlQz4iGbCaqxzeNQNObQdOHobHYvQ2iOk2KKs94rBjgZjWKUuwsPo(3K0qU3J)uHRkhVW9S36tsYWaDqkpQW9j(tcweCw(a)JGKF8xoVt8KfNbXQMmKeAMtjrcSh3NdVmvTarEeawCazAVV7MDmkyVcMUlfaESuQdpWrqGxhWuWuLjnk24PczSiGecGflkCN1KwG42T5PX9nr9BghvR0QAL7j5LUojCTdPr3ilI(met1YBiXK5jEzsC3vAMjKfqDYijMOXQLHSJh)CB3C6oA288ygOWtwJuWE5cPhrNRmJ59OdE2G1(SxiAhCDcCJAG2R2CE8008kG4xBBEuOtDaZrqP(iWqTBu8CGnborjZAtOxNyvpQ3fl1itp93LYfojqQT0ANvw0Rf3uH7LLmUD3hfUNB(WpmaSJ5qL5i2ts9RibTgcxAuB(CmojYKeuKgcK56MaLrIR69unhE1RugpccsqsQZUuIiPHVTXLUNavEC2YdZ6LHigTrGYdvBoWpayQm4FqVf4BHnhf90xanJaL4aNuL)r2(X7a6Uc3nGFdOf3tHfHWuS5fGXvE64bbQIJqe9oRfIZlCZJdPcrJnIbuHar0bPuXEqSkS9DxD(CDxC)iunorIgKNhWSoIegSgX8sJ2Gw69E9uORqa0OD1OAiyuMw5wA86EvS((CE0UC40mE7qFj2TtT8kdZIdOPXKWxe3WXicgihQoc1bK3QJOfDsog4LMYU0f9gjhWuOJuhsfeyTgnAjOrhECBvLpjDmkItg3XNrl3J30TSXO8ot1MVzuBQfwn4ygNRAQ7GvJUdwAS61O9dEMbiYvL2TYk7PKWS9nvTxUWmUAjeR)MbTA12(TVa213LhL0W69h5c4NBPavk9hbdX8PTPurk2moKu)zods7Gg5t9ijjsI1s62yEwjXm8S5JE)NHQWbhaRfdgUmfRMPDBhd3wu6xnu406lSnnRHjMhf50f1QH2)EzZetebC9iaPRnvgVLaAyNu4PLGNn4nfKYBVPmsmCrG)c7UWA4scVQDXyMA1u7KrEn2V(n7BIsSv709O1hoeDen0MI8OLDFKf(heQpnw44LhhJj41I3Os1LEh)6BtxJLOt0J1ucRVX6eBGOZtKuuFcC(vqIflkHNMv1K4PvJK6uS0Y)nhAFXhzIWeqsEgpIiVBT3Es8oQyEXd)clgE1k4w4)wSipb1ekq52avxnNZPGWsZfWdd5pjXFKCaAbSJ0u455cCHyVSzOy1AahYa2(swTCsw0aEEClP99rH9jayNiO)uXdfU)n8VRSo83py4W2mTHx2X1A8JB5ifoTr8LdkUAGckPVAqPn2qPAHxp4cL06OGgDcWfZFzh)HppY8o1o6YbfuLED6ear9Vh6l6uxk4BguWweDd6MeF1ajD2yhfE0CZJP4z7CPHP4E7e1g2JAOyYu8VMcB3mngJsHVDQUsRftwYH9G9GdvRy4eZER4Bkrh(3DV88ayASo9ldv)xEUVQgxDMjoXIKuEalKwo(IiMqiDZvRV60TdUxDkZdCCLFge4q4w4((QzEiz(JOX(O1Y2tGhtHw2Fg1nJd(SNrVUxyUpEZCkd8(P1E7)ZVjOOMOrIF)cS7EM3EDPjXpRSAvGK()sGugwwOsV6X1AJ(ZYlsuzMpvQca797Os91F0snl)elmu7evPYSArLEd5JIZJ2sld0HqJFfp8(OAh(Q2irmIJtJx6MT38DfUV25Tx8W3bR(J1vAlEO0mI5nfF)H1)OwDtZcOQuEr9i6x3mH(bwsmjrSNN5aKwygGjzmws9cwW6jndhZMTAsgsTa9uUEXSHMnJX1ltDvl2SqLZyhZhqN77k7zRr01afJd0pz0f4xNzD9Nbev6Wxg8UvnRVXa4k6F5unXuFHVJlAZxY7OI28CuYtMY317WHP9n9U3Q1PSZN0Q0DHKIOH7(D8UFXrxk0kfUs85Q56D)6JBtrw)11oG00q)fLFoT1w1rF4IP7qQWpjVyDH7)Id4Dj6aE5ati(N)MnHyfEwKTUbRRn6I7xBn7SHNq8HdJoDyWe6wqXC00eLoMA007zdgoAP46oTET6vhEuPyDgeZuhZoP7aDN11fAEah3BTywVXIu)WrMQY9301Vk1aUfR98RBUg9Hd1p72z9hh59w30rvgS7Xu8BmQ4UEs15)y6BLr9TSJ(ArmDwlp(vho0BYw3TCr7WYYZ)tjUGLa(ZCwLD8cnzT9iX7achADTDCZgUMe4a6OJ6XdjjORMH0Dx1vk1y7UOzQDRTkZNmeJ0J5nyJV)YJ67V2qiR8zgcWx3zp26sd4w7iJRBwVr111s1Z17RTD6spPg8xDjO3Y)hA1DCpB1pu)fceA0gq1XPeblfRKEP1NiwpcEYA53wFwD(RAqXD0JgfWxUYgHzEKpgFFY6E6T3AnTzpPocDwNkixwvuuZc9C7njFnAzOC1s5)YHnhfEwD27dN(qvNx69YuViSRSPGIQKRxvkdX2krnxSyy5vDKPqddp12ElxDX2x361MWlCF998u7nBIYdszpkNYR9)p]] )

-- Register pack selector for Affliction
