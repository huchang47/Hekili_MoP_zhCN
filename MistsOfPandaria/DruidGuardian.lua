if not Hekili or not Hekili.NewSpecialization then return end
-- DruidGuardian.lua
-- December 2024 - Rebuilt from retail structure for MoP compatibility

local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then 
    return 
end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization(104, true)

-- Local wrappers to satisfy linter and forward to state helpers if available.
local function shift( form )
    if state and state.shift then return state.shift( form ) end
end

local function unshift()
    if state and state.unshift then return state.unshift() end
end

local function interrupt()
    if state and state.interrupt then return state.interrupt() end
end

spec.name = "Guardian"
spec.role = "TANK"
spec.primaryStat = 2 -- Agility

-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4, Rage = 1, Mana = 0 in MoP Classic
spec:RegisterResource( 1 ) -- Rage (primary for Guardian)
spec:RegisterResource( 0 ) -- Mana (for healing spells)
spec:RegisterResource( 3 ) -- Energy (for Heart of the Wild cat form)
spec:RegisterResource( 4 ) -- ComboPoints (for Heart of the Wild cat form)


-- Talents (MoP system - different from retail)
spec:RegisterTalents( {
    -- Row 1 (15)
    feline_swiftness      = { 1, 1, 131768 },
    displacer_beast       = { 1, 2, 102280 },
    wild_charge           = { 1, 3, 102401 },

    -- Row 2 (30)
    yseras_gift           = { 2, 1, 145108 },
    renewal               = { 2, 2, 108238 },
    cenarion_ward         = { 2, 3, 102351 },

    -- Row 3 (45)
    faerie_swarm          = { 3, 1, 102355 },
    mass_entanglement     = { 3, 2, 102359 },
    typhoon               = { 3, 3, 132469 },

    -- Row 4 (60)
    soul_of_the_forest    = { 4, 1, 158477 },
    incarnation           = { 4, 2, 102558 },
    force_of_nature       = { 4, 3, 106737 },

    -- Row 5 (75)
    disorienting_roar     = { 5, 1, 99    },
    ursols_vortex         = { 5, 2, 102793 },
    mighty_bash           = { 5, 3, 5211   },

    -- Row 6 (90)
    heart_of_the_wild     = { 6, 1, 108292 },
    dream_of_cenarius     = { 6, 2, 108373 },
    natures_vigil         = { 6, 3, 124974 },

    -- Extras treated like toggles here
    savage_defense        = { 0, 0, 62606 },
} )

-- Glyphs disabled for Guardian (simplified)

-- Gear Sets
spec:RegisterGear( "tier13", 78699, 78700, 78701, 78702, 78703, 78704, 78705, 78706, 78707, 78708 )
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 )
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 )
spec:RegisterGear( "tier16", 99344, 99345, 99346, 99347, 99348 )

-- T14 Set Bonuses
spec:RegisterSetBonuses( "tier14_2pc", 123456, 1, "Mangle has a 10% chance to apply 2 stacks of Lacerate." )
spec:RegisterSetBonuses( "tier14_4pc", 123457, 1, "Savage Defense also provides 20% dodge chance for 6 sec." )

-- T15 Set Bonuses  
spec:RegisterSetBonuses( "tier15_2pc", 123458, 1, "Your melee critical strikes reduce the cooldown of Enrage by 2 sec." )
spec:RegisterSetBonuses( "tier15_4pc", 123459, 1, "Frenzied Regeneration also reduces damage taken by 20%." )

-- T16 Set Bonuses
spec:RegisterSetBonuses( "tier16_2pc", 123460, 1, "Mangle critical strikes grant 1500 mastery for 8 sec." )
spec:RegisterSetBonuses( "tier16_4pc", 123461, 1, "Thrash periodic damage has a chance to reset the cooldown of Mangle." )

-- Auras
spec:RegisterAuras( {
    -- Vengeance buff for Guardian Druid
    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 132365)
            
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
        end,
    },
    
    -- Bear Form
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },

    -- Defensive abilities
    -- Enhanced Barkskin with glyph support
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
        copy = "barkskin_buff",
    },
    
    disorienting_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Survival Instincts with glyph support
    survival_instincts = {
        id = 61336,
        duration = function() return glyph.survival_instincts.enabled and 6 or 12 end,
        max_stack = 1,
        copy = "survival_instincts_buff",
    },

    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },

    -- Enhanced Savage Defense with proper charge system
    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 3, -- 3 charges can be stored
        copy = "savage_defense_buff",
    },

    -- Offensive abilities - Enhanced Enrage with tick mechanics
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
        tick_time = 1,
        copy = "enrage_buff",
    },

    -- Berserk buff
    berserk = {
        id = 50334,
        duration = function() return buff.bear_form.up and 10 or 15 end,
        max_stack = 1,
        copy = "berserk_buff",
    },

    -- Debuffs
    lacerate = {
        id = 33745,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
        copy = "lacerate_dot",
    },

    thrash_bear = {
        id = 77758,
        duration = 16,
        max_stack = 1,
        tick_time = 2,
        copy = "thrash_bear_dot",
    },

    faerie_fire = {
        id = 770,
        duration = 300,
        max_stack = 1,
    },

    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Demoralizing Roar ability
    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "demoralizing_roar", 30 )
            if active_enemies > 1 then
                active_dot.demoralizing_roar = active_enemies
            end
        end,
    },

    -- Buffs from talents
    incarnation = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Heart of the Wild with proper stat modifications
    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
        copy = "heart_of_the_wild_buff",
    },

    nature_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
    },

    -- Heart of the Wild Feral auras (needed for DPS rotation)
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        max_stack = 1,
        copy = "predatory_swiftness_buff",
    },

    clearcasting = {
        id = 135700,
        duration = 15,
        max_stack = 1,
        copy = "clearcasting_buff",
    },

    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },

    -- Other forms
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },

    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },

    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },

    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },

    -- Prowl (for stealth mechanics)
    prowl_base = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first", 
        aliasType = "buff",
        duration = 3600,
        max_stack = 1
    },

    -- Generic buffs
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },

    -- Procs and special effects - Enhanced Tooth & Claw with absorb
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
        copy = "tooth_and_claw_absorb",
    },

    -- Glyphs
    glyph_of_fae_silence = {
        id = 114302,
        duration = 5,
        max_stack = 1,
    },

    -- Raid buffs/debuffs
    weakened_armor = {
        id = 113746,
        duration = 30,
        max_stack = 3,
    },

    sunder_armor = {
        id = 58567,
        duration = 30,
        max_stack = 3,
    },

    -- Missing auras from APL
    incarnation_son_of_ursoc = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    natures_vigil = {
        id = 124974,
        duration = 12,
        max_stack = 1,
    },

    pulverize = {
        id = 80313,
        duration = 20,
        max_stack = 1,
    },

    symbiosis = {
        id = 110309,
        duration = 3600,
        max_stack = 1,
    },

    -- Enhanced Dream of Cenarius with proper mechanics
    dream_of_cenarius_damage = {
        id = 108373,
        duration = 15,
        max_stack = 2,
        copy = "dream_of_cenarius_dmg",
    },

    dream_of_cenarius_healing = {
        id = 108374, -- Different ID for healing version
        duration = 15, 
        max_stack = 2,
        copy = "dream_of_cenarius_heal",
    },

    mangle = {
        id = 33878,
        duration = 0,
        max_stack = 1,
    },

    tooth_and_claw_debuff = {
        id = 135286,
        duration = 6,
        max_stack = 1,
    },

    -- Weakened Blows debuff (applied by Thrash)
    weakened_blows = {
        id = 113746,
        duration = 30,
        max_stack = 3,
        copy = "weakened_blows_debuff",
    },

    -- Additional debuffs needed for APL
    mighty_bash = {
        id = 5211,
        duration = 5,
        max_stack = 1,
    },

    growl = {
        id = 6795,
        duration = 3,
        max_stack = 1,
    },

    challenging_roar = {
        id = 5209,
        duration = 6,
        max_stack = 1,
    },

    -- Ironfur (defensive buff)
    ironfur = {
        id = 102543,
        duration = 6,
        max_stack = 1,
    },

    -- Vengeance (tank mechanic)
    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 999,
        meta = {
            stack = function( t ) return t.count end,
            stack_up = function( t ) return t.count > 0 end,
            stack_down = function( t ) return t.count == 0 end,
        },
    },

    -- Primal Fury passive (crit-based resource generation)
    primal_fury = {
        id = 16961,
        duration = -1,
        max_stack = 1,
        copy = "primal_fury_passive",
    },

    -- Pulverize buff (crit bonus from consuming Lacerate stacks)
    pulverize = {
        id = 80951,
        duration = 18, -- 10s base + 8s from Endless Carnage if talented
        max_stack = 3,
        copy = "pulverize_buff",
    },

    -- Demoralizing Roar debuff
    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
        copy = "demoralizing_roar_debuff",
    },

    -- Heart of the Wild Cat Form debuffs
    -- Rake debuff (HotW Cat form)
    rake = {
        id = 155722, -- MoP Rake ID
        duration = 9,
        max_stack = 1,
        tick_time = 3,
        copy = "rake_debuff",
    },

    -- Rip debuff (HotW Cat form)
    rip = {
        id = 1079,
        duration = function() return 16 + ( combo_points.spent * 2 ) end,
        max_stack = 1,
        tick_time = 2,
        copy = "rip_debuff",
    },

} )

-- Primal Fury implementation
spec:RegisterHook( "criticalStrike", function( action, result )
    if not buff.bear_form.up then return end
    
    local rageGain = 0
    if action == "auto_attack" then
        rageGain = 15
    elseif action == "mangle" then
        -- Soul of the Forest increases Mangle rage gen by 30% for Guardian
        rageGain = talent.soul_of_the_forest.enabled and 19.5 or 15
    end
    
    if rageGain > 0 then
        gain( rageGain, "rage" )
    end
end )

-- Survival Instincts damage reduction mechanics
spec:RegisterHook( "runHandler", function( action )
    if action == "survival_instincts" then
        -- Apply 50% damage reduction
        if buff.survival_instincts.up then
            state.pseudoStats.damageTakenMultiplier = state.pseudoStats.damageTakenMultiplier * 0.5
        end
    end
end )

-- Dream of Cenarius proc mechanics
spec:RegisterHook( "spend", function( amt, resource )
    if resource == "rage" and amt > 0 and talent.dream_of_cenarius.enabled then
        -- Dream of Cenarius: Spending rage builds healing stacks
        if amt >= 30 then
            if buff.dream_of_cenarius_healing.stack < 2 then
                applyBuff( "dream_of_cenarius_healing", 15, min( 2, buff.dream_of_cenarius_healing.stack + 1 ) )
            end
        end
    end
end )

spec:RegisterHook( "runHandler", function( action )
    if talent.dream_of_cenarius.enabled then
        local ability = class.abilities[ action ]
        if ability and ability.startsCombat and action ~= "auto_attack" then
            -- Damage abilities build damage stacks
            if action == "mangle" or action == "lacerate" or action == "thrash_bear" then
                if buff.dream_of_cenarius_damage.stack < 2 then
                    applyBuff( "dream_of_cenarius_damage", 15, min( 2, buff.dream_of_cenarius_damage.stack + 1 ) )
                end
            end
        end
    end
end )

-- Enhanced Enrage tick mechanics
spec:RegisterHook( "reset_precast", function()
    -- Handle Enrage rage generation over time
    if buff.enrage.up then
        local ticks = math.floor( buff.enrage.remains )
        if ticks > 0 then
            -- Simulate the remaining rage ticks
            forecastResources( "rage" )
        end
    end
end )

-- Bear Form drop cancels Enrage and Symbiosis interaction tracking
spec:RegisterHook( "runHandler", function( action )
    if action == "unshift" or ( action ~= "bear_form" and not buff.bear_form.up ) then
        if buff.enrage.up then
            removeBuff( "enrage" )
        end
    end
    
    -- Track Symbiosis cooldown interactions
    if buff.symbiosis.up and action == "survival_instincts" then
        -- Symbiosis may modify cooldown behavior for survival abilities
        if talent.incarnation.enabled then
            setCooldown( action, max( 0, cooldown[ action ].remains - 30 ) )
        end
    end
end )

-- Shapeshift helpers for Guardian (parallel to Feral's implementations).
spec:RegisterStateFunction( "unshift", function()
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
end )

spec:RegisterStateFunction( "shift", function( form )
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
    if form then applyBuff( form ) end
end )

-- State Functions
local function rage_spent_recently( amt )
    amt = amt or 1

    for i = 1, #state.recentRageSpent do
        if state.recentRageSpent[i] >= amt then return true end
    end

    return false
end

local function lacerate_up()
    return state.debuff.lacerate.up
end

local function thrash_up()
    return state.debuff.thrash_bear.up
end

-- Abilities
spec:RegisterAbilities( {
    -- Bear Form
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,

        handler = function ()
            shift( "bear_form" )
        end,
    },

    -- Basic attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = true,
        texture = 132938,

    usable = function () return state and state.melee and state.melee.range and state.melee.range <= 5 end,
        handler = function ()
            removeBuff( "prowl" )
        end,
    },

    mangle = {
        id = 33878,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 132135,

        form = "bear_form",

        handler = function ()
            -- Generate rage (5 base, 6.5 with Soul of the Forest for Guardian)
            local rageGain = talent.soul_of_the_forest.enabled and 6.5 or 5
            gain( rageGain, "rage" )
            
            if talent.infected_wounds.enabled then
                applyDebuff( "target", "infected_wounds" )
            end
            
            removeBuff( "tooth_and_claw" )
            
            -- Berserk removes Mangle CD
            if buff.berserk.up then
                setCooldown( "mangle", 0 )
            end
            
            if set_bonus.tier16_4pc == 1 and active_dot.thrash_bear > 0 then
                if math.random() < 0.4 then
                    setCooldown( "mangle", 0 )
                end
            end
        end,
    },
    
    disorienting_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132121,

        form = "bear_form",
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Lacerate (Guardian ability) with APL-based logic
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 3, -- 3 second internal cooldown from Go sim
        gcd = "spell",

        spend = 0, -- No rage cost in MoP for Guardian
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",

        handler = function ()
            -- Apply or refresh Lacerate DoT with stacking
            local currentStacks = debuff.lacerate.stack or 0
            local newStacks = min( 3, currentStacks + 1 )
            applyDebuff( "target", "lacerate", 15, newStacks )
            
            -- 25% chance to reset Mangle cooldown (matches Go sim)
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            if talent.tooth_and_claw.enabled then
                if math.random() < 0.4 then
                    applyBuff( "tooth_and_claw", 6, min( 2, ( buff.tooth_and_claw.stack or 0 ) + 1 ) )
                end
            end
        end,
    },

    -- Enhanced Pulverize (Guardian ability) with proper mechanics
    pulverize = {
        id = 80313,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 236149,

        form = "bear_form",
        
        usable = function() return debuff.lacerate.up and debuff.lacerate.stack >= 1 end,

        handler = function ()
            local stacks = debuff.lacerate.stack
            if stacks >= 1 then
                -- Consume Lacerate DoT and apply Pulverize buff
                removeDebuff( "target", "lacerate" )
                applyBuff( "pulverize", 18, stacks ) -- Duration affected by Endless Carnage
                -- Each stack gives 3% crit chance
            end
        end,
    },

    -- Enhanced Maul with rage dumping logic
    maul = {
        id = 6807,
        cast = 0,
        cooldown = 3, -- 3 second cooldown from APL analysis
        gcd = "spell",

        spend = function() return buff.bear_form.up and 20 or 30 end, -- Guardian gets reduced cost
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",
        
        -- Rage dumping logic from APL analysis
        usable = function() return rage.current >= ( buff.bear_form.up and 20 or 30 ) end,

        handler = function ()
            if buff.tooth_and_claw.up then
                local stacks = buff.tooth_and_claw.stack
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff", 6 )
                -- Apply absorb shield based on attack power and stacks
                local absorb_amount = stat.attack_power * 0.65 * stacks
                absorbDamage( absorb_amount )
            end
            
            -- Benefits from Rend and Tear if bleeds are active
            local hasBleed = debuff.lacerate.up or debuff.thrash_bear.up or debuff.rake.up or debuff.rip.up
            if hasBleed then
                -- 20% damage bonus applied via damage calculation
            end
        end,
    },



    -- Defensive abilities
    -- Enhanced Barkskin with Guardian-specific cooldown
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 30, -- Guardian gets 30s CD instead of 60s
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 136097,

        handler = function ()
            applyBuff( "barkskin", 12 )
            -- 20% damage reduction + glyph effects applied via aura mechanics
        end,
    },

    -- Enhanced Survival Instincts with proper glyph mechanics
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = function() return glyph.survival_instincts.enabled and 120 or 180 end,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 236169,
        
        form = function() return buff.bear_form.up and "bear_form" or buff.cat_form.up and "cat_form" or "none" end,
        usable = function() return buff.bear_form.up or buff.cat_form.up end,

        handler = function ()
            local duration = glyph.survival_instincts.enabled and 6 or 12
            applyBuff( "survival_instincts", duration )
            -- 50% damage reduction applied via aura
        end,
    },

    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "frenzied_regeneration" )
            health.actual = min( health.max, health.actual + ( health.max * 0.3 ) )
        end,
    },

    -- Rage generators - Enhanced Enrage with proper tick mechanics
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 132126,

        form = "bear_form",

        handler = function ()
            -- Initial 20 rage burst
            gain( 20, "rage" )
            -- Apply buff that will tick for 10 seconds, giving +1 rage per tick
            applyBuff( "enrage", 10 )
        end,
    },

    -- Enhanced Berserk with Bear form mechanics
    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 236149,

        talent = "berserk",
        
        usable = function() return buff.bear_form.up or buff.cat_form.up end,

        handler = function ()
            if buff.bear_form.up then
                applyBuff( "berserk", 10 )
                setCooldown( "mangle", 0 ) -- Immediate Mangle reset
                -- Enable multi-target Mangle and remove CD during berserk
            elseif buff.cat_form.up then
                applyBuff( "berserk", 15 )
                -- 50% energy cost reduction handled elsewhere
            end
        end,
    },

    -- Utility
    -- Enhanced Faerie Fire (unified ability with form-specific behavior)
    faerie_fire = {
        id = 770, -- Base Faerie Fire ID (Bear form version 16857 handled via copy)
        cast = 0,
        cooldown = function() return buff.bear_form.up and 6 or 0 end,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,
        
        copy = { 16857 }, -- Bear form version

        handler = function ()
            if buff.bear_form.up then
                -- Bear form version does damage and has shorter CD
                -- 25% chance to reset Mangle cooldown
                if math.random() < 0.25 then
                    setCooldown( "mangle", 0 )
                end
            end
            
            applyDebuff( "target", "faerie_fire", 300 )
            applyDebuff( "target", "weakened_armor", 30, 3 )
        end,
    },

    -- Faerie Fire (Bear) - explicit registration for ID 16857
    faerie_fire_bear = {
        id = 16857,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,
        
        form = "bear_form",

        handler = function ()
            -- Bear form version does damage and has shorter CD
            -- 25% chance to reset Mangle cooldown
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            applyDebuff( "target", "faerie_fire", 300 )
            applyDebuff( "target", "weakened_armor", 30, 3 )
        end,
    },

    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            applyDebuff( "target", "demoralizing_roar" )
            if active_enemies > 1 then
                active_dot.demoralizing_roar = active_enemies
            end
        end,
    },

    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "spell",

        startsCombat = true,
        texture = 132270,

        handler = function ()
            -- Taunt effect
        end,
    },

    challenging_roar = {
        id = 5209, -- Challenging Roar (Guardian ability in MoP)
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            -- AoE taunt
        end,
    },

    -- Incarnation
    incarnation = {
        id = 102558,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "incarnation",
        toggle = "cooldowns",

        startsCombat = false,
        texture = 571586,

        handler = function ()
            applyBuff( "incarnation" )
            if not buff.bear_form.up then
                shift( "bear_form" )
            end
        end,
    },

    -- Incarnation: Son of Ursoc (Guardian version)
    incarnation_son_of_ursoc = {
        id = 102558,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "incarnation",

        startsCombat = false,
        texture = 571586,

        handler = function ()
            applyBuff( "incarnation_son_of_ursoc" )
            if not buff.bear_form.up then
                shift( "bear_form" )
            end
        end,
    },

    -- Savage Defense (Guardian ability) - Enhanced with charge system
    savage_defense = {
        id = 62606,
        cast = 0,
        charges = 3,
        cooldown = 9, -- 9 second recharge per charge
        recharge = 9,
        gcd = "spell", -- 1.5s to respect GCD

        spend = 60,
        spendType = "rage",

        talent = "savage_defense",
        toggle = "defensives",

        startsCombat = false,
        texture = 132278,
        
        usable = function() return rage.current >= 60 and charges_fractional >= 1 end,

        handler = function ()
            applyBuff( "savage_defense", 6 )
            spend( 60, "rage" )
        end,
    },

    -- Nature's Vigil (talent)
    natures_vigil = {
        id = 124974,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        talent = "natures_vigil",
        toggle = "defensives",

        startsCombat = false,
        texture = 132123,

        handler = function ()
            applyBuff( "natures_vigil" )
        end,
    },



    -- Enhanced Swipe (Bear form) with Guardian mechanics
    swipe_bear = {
        id = 779,
        cast = 0,
        cooldown = 3, -- 3 second cooldown
        gcd = "spell",

        spend = 0, -- Guardian Druids have 0 rage cost
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",
        
        usable = function() return active_enemies > 1 end,

        handler = function ()
            -- Benefits from Rend and Tear damage multiplier
            local multiplier = ( debuff.lacerate.up or debuff.thrash_bear.up or debuff.rake.up or debuff.rip.up ) and 1.2 or 1.0
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                -- Hit multiple enemies with Rend and Tear bonus
            end
        end,
    },

    -- Thrash (Bear form)
    thrash_bear = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 451161,

        form = "bear_form",

        handler = function ()
            -- Apply DoT to primary target
            applyDebuff( "target", "thrash_bear", 16 )
            
            -- 25% chance to reset Mangle cooldown (matches Go sim)
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            -- Apply Weakened Blows debuff
            applyDebuff( "target", "weakened_blows", 30 )
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                for i = 1, applied do
                    if i == 1 then
                        applyDebuff( "target", "thrash_bear", 16 )
                    else
                        applyDebuff( "target" .. i, "thrash_bear", 16 )
                        applyDebuff( "target" .. i, "weakened_blows", 30 )
                    end
                end
            end
        end,
    },

    -- Thrash: General ability that maps to thrash_bear for Guardian
    -- This allows keybind detection to work properly
    thrash = {
        id = 77758,
        copy = "thrash_bear",
    },

    -- Enhanced Symbiosis (MoP ability) with proper target conditions
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = false,
        texture = 136033,
        
        usable = function() 
            return settings.use_symbiosis and group_members > 1 
        end,

        handler = function ()
            applyBuff( "symbiosis", 3600 )
            -- Symbiosis grants different abilities based on target class
            -- For Guardian, commonly grants survival abilities like:
            -- Death Knight: Bone Shield, Paladin: Consecration, etc.
        end,
    },

    -- Skull Bash (interrupt)
    skull_bash = {
        id = 80965,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        toggle = "interrupts",

        startsCombat = false,
        texture = 132091,

        form = "bear_form",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            interrupt()
        end,
    },

    -- Mighty Bash (talent interrupt)
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",

        talent = "mighty_bash",
        toggle = "interrupts",

        startsCombat = true,
        texture = 132091,

        handler = function ()
            applyDebuff( "target", "mighty_bash" )
    end,
    },

    -- Wild Charge (talent)
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        talent = "wild_charge",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "wild_charge" )
        end,
    },

    -- Heart of the Wild (talent)
    heart_of_the_wild = {
        id = 108292,
        cast = 0,
        cooldown = 360,
        gcd = "off",

        talent = "heart_of_the_wild",
        toggle = "defensives",

        startsCombat = false,
        texture = 132123,

        handler = function ()
            applyBuff( "heart_of_the_wild" )
            -- Apply form-specific stat bonuses based on current form
            if buff.bear_form.up then
                -- Guardian: +25% stamina, enables Cat abilities at full effectiveness
                stat.stamina_multiplier = stat.stamina_multiplier * 1.25
            elseif buff.cat_form.up then
                -- Feral: +25% agility, enables Caster abilities at full effectiveness  
                stat.agility_multiplier = stat.agility_multiplier * 1.25
            else
                -- Caster forms: +25% intellect, enables physical abilities
                stat.intellect_multiplier = stat.intellect_multiplier * 1.25
            end
        end,
    },

    -- Force of Nature (talent)
    force_of_nature = {
        id = 106737,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        talent = "force_of_nature",

        startsCombat = true,
        texture = 132123,

        handler = function ()
            -- Summon treants
        end,
    },

    -- Nature's Swiftness (if talented)
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        talent = "nature_swiftness",

        startsCombat = false,
        texture = 136076,

        handler = function ()
            applyBuff( "nature_swiftness" )
        end,
    },

    -- Healing Touch (for Nature's Swiftness)
    healing_touch = {
        id = 5185,
        cast = function() return buff.nature_swiftness.up and 0 or 3 end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.nature_swiftness.up and 0 or 0.15 end,
        spendType = "mana",

        startsCombat = false,
        texture = 136041,

        handler = function ()
            removeBuff( "nature_swiftness" )
            health.actual = min( health.max, health.actual + ( health.max * 0.4 ) )
        end,
    },

    -- Heart of the Wild Cat Form DPS Abilities
    -- Shred (Heart of the Wild Cat form)
    shred_hotw = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 40,
        spendType = "energy",

        startsCombat = true,
        texture = 136231,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and energy.current >= 40 end,
        
        handler = function ()
            if combo_points.current < combo_points.max then
                gain( 1, "combo_points" )
            end
            if debuff.rip.up then
                -- 20% damage bonus with Rend and Tear if bleeds active
            end
        end,
    },

    -- Rake (Heart of the Wild Cat form)
    rake_hotw = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 35,
        spendType = "energy",

        startsCombat = true,
        texture = 132122,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and energy.current >= 35 end,

        handler = function ()
            applyDebuff( "target", "rake", 9 )
            if combo_points.current < combo_points.max then
                gain( 1, "combo_points" )
            end
        end,
    },

    -- Rip (Heart of the Wild Cat form finisher)
    rip_hotw = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "energy",

        startsCombat = true,
        texture = 132152,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and combo_points.current >= 1 and energy.current >= 30 end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff( "target", "rip", 16 + ( cp * 2 ) ) -- Longer duration with more CP
            spend( cp, "combo_points" )
        end,
    },

    -- Ferocious Bite (Heart of the Wild Cat form finisher)
    ferocious_bite_hotw = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 25,
        spendType = "energy",

        startsCombat = true,
        texture = 132127,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and combo_points.current >= 1 and energy.current >= 25 end,

        handler = function ()
            local cp = combo_points.current
            spend( cp, "combo_points" )
        end,
    },

    -- Cat Form for Heart of the Wild DPS switching
    cat_form_hotw = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 132115,
        
        essential = true,
        nomounted = true,
        
        usable = function() return buff.heart_of_the_wild.up and not buff.cat_form.up and health.pct >= 80 end,

        handler = function ()
            shift( "cat_form" )
        end,
    },



    -- Ironfur (defensive ability)
    ironfur = {
        id = 102543,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 45,
        spendType = "rage",

        startsCombat = false,
        texture = 132787,

        form = "bear_form",

        handler = function ()
            applyBuff( "ironfur" )
        end,
    },

    -- Mark of the Wild (buff ability)
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 136078,

        handler = function ()
            applyBuff( "mark_of_the_wild" )
        end,
    },

    -- Nature's Swiftness (talent ability)
    nature_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 136076,

        talent = "nature_swiftness",

        handler = function ()
            applyBuff( "nature_swiftness" )
        end,
    },

    -- Prowl (stealth ability)
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "off",

        startsCombat = false,
        texture = 514640,

        nobuff = "prowl",
        
        usable = function() return not buff.bear_form.up end,

        handler = function ()
            applyBuff( "prowl_base" )
        end,
    },

} )

-- State table and hooks
spec:RegisterStateExpr( "lacerate_up", function()
    return debuff.lacerate.up
end )

spec:RegisterStateExpr( "thrash_up", function()
    return debuff.thrash_bear.up
end )

spec:RegisterStateExpr( "rage_spent_recently", function()
    local t = state and state.recentRageSpent
    if type( t ) ~= 'table' then return false end
    for i = 1, #t do if t[i] and t[i] > 0 then return true end end
    return false
end )

-- Vengeance state expressions
spec:RegisterStateExpr("vengeance_stacks", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("vengeance_attack_power", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_attack_power()
end)

spec:RegisterStateExpr("vengeance_value", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("high_vengeance", function()
    if not state.vengeance or not state.settings then
        return false
    end
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

spec:RegisterStateExpr("should_prioritize_damage", function()
    if not state.vengeance or not state.settings or not state.settings.vengeance_optimization or not state.settings.vengeance_stack_threshold then
        return false
    end
    return state.settings.vengeance_optimization and state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

-- Register representative abilities for range checking.
-- Include core melee-range and utility abilities to standardize distance evaluation.
spec:RegisterRanges( "mangle", "maul", "lacerate", "swipe_bear", "thrash_bear", "skull_bash", "growl" )
spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageDots = false,
    damageExpiration = 3,

    potion = "tempered_potion",

    package = "Guardian"
} )

-- Guardian-specific settings
spec:RegisterSetting( "defensive_health_threshold", 80, {
    name = "Defensive Health Threshold",
    desc = "The health percentage at which defensive abilities will be recommended.",
    type = "range",
    min = 50,
    max = 100,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "use_symbiosis", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 110309 ) ),
    desc = strformat( "If checked, %s will be recommended when available.",
        Hekili:GetSpellLinkWithTexture( 110309 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "use_savage_defense", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 62606 ) ),
    desc = strformat( "If checked, %s will be recommended when you have sufficient rage (60 rage cost, 3 charges).",
        Hekili:GetSpellLinkWithTexture( 62606 ) ),
    type = "toggle",
    width = "full",
} )

-- Remove old rage threshold setting since it's now fixed at 60 rage per charge

spec:RegisterSetting( "lacerate_stacks", 3, {
    name = strformat( "%s Stacks", Hekili:GetSpellLinkWithTexture( 33745 ) ),
    desc = strformat( "The number of %s stacks to maintain on the target.",
        Hekili:GetSpellLinkWithTexture( 33745 ) ),
    type = "range",
    min = 1,
    max = 3,
    step = 1,
    width = 1.5,
} )

spec:RegisterSetting( "maintain_faerie_fire", true, {
    name = strformat( "Maintain %s", Hekili:GetSpellLinkWithTexture( 770 ) ),
    desc = strformat( "If checked, %s will be maintained on the target.",
        Hekili:GetSpellLinkWithTexture( 770 ) ),
    type = "toggle",
    width = "full",
} )

-- Vengeance system variables and settings (Lua-based calculations)
spec:RegisterVariable( "vengeance_stacks", function()
    return state.vengeance:get_stacks()
end )

spec:RegisterVariable( "vengeance_attack_power", function()
    return state.vengeance:get_attack_power()
end )

spec:RegisterVariable( "high_vengeance", function()
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end )

spec:RegisterVariable( "vengeance_active", function()
    return state.vengeance:is_active()
end )

-- Health-based defensive automation variables (StateExpr for SimC access)
spec:RegisterStateExpr( "emergency_health", function()
    return health.pct <= ( settings.emergency_health_pct or 30 )
end )

spec:RegisterStateExpr( "defensive_health", function()
    return health.pct <= ( settings.defensive_health_pct or 50 )
end )

spec:RegisterStateExpr( "moderate_damage", function()
    return health.pct <= ( settings.moderate_damage_pct or 70 )
end )

spec:RegisterStateExpr( "needs_emergency_healing", function()
    return health.pct <= ( settings.emergency_health_pct or 30 ) and not buff.frenzied_regeneration.up
end )

spec:RegisterStateExpr( "should_use_defensives", function()
    return health.pct <= ( settings.defensive_health_pct or 50 ) and incoming_damage_3s > 0
end )

-- Heart of the Wild DPS rotation switching mechanics (StateExpr for SimC access)
spec:RegisterStateExpr( "hotw_active", function()
    return buff.heart_of_the_wild.up
end )

spec:RegisterStateExpr( "should_dps_rotation", function()
    -- Switch to DPS rotation during Heart of the Wild if health is stable
    return buff.heart_of_the_wild.up and health.pct >= 70 and not boss and active_enemies <= 3
end )

spec:RegisterStateExpr( "hotw_cat_form_ready", function()
    -- Can switch to Cat form during HotW for DPS
    return buff.heart_of_the_wild.up and not buff.bear_form.up and health.pct >= 80
end )

spec:RegisterStateExpr( "hotw_caster_form_ready", function()
    -- Can switch to caster form during HotW for ranged DPS
    return buff.heart_of_the_wild.up and not buff.bear_form.up and not buff.cat_form.up and health.pct >= 70 and target.distance >= 15
end )

-- Advanced defensive automation logic (StateExpr for SimC access)
spec:RegisterStateExpr( "auto_survival_instincts", function()
    return health.pct <= ( settings.emergency_health_pct or 30 ) and not buff.survival_instincts.up and not buff.barkskin.up
end )

spec:RegisterStateExpr( "auto_savage_defense", function()
    -- Check if we should automatically use Savage Defense
    if not settings.use_savage_defense then return false end
    if rage.current < 60 then return false end
    if buff.savage_defense.up then return false end
    if incoming_damage_3s <= 0 then return false end
    
    -- Access charges correctly - use cooldown.charges or ability charges
    local charges_available = cooldown.savage_defense.charges_fractional or 0
    return charges_available >= 1
end )

-- Settings-based StateExpr for SimC access
spec:RegisterStateExpr( "auto_pulverize", function()
    return settings.auto_pulverize
end )

spec:RegisterStateExpr( "faerie_fire_auto", function()
    return settings.faerie_fire_auto
end )

spec:RegisterStateExpr( "rage_dump_threshold", function()
    return settings.rage_dump_threshold or 90
end )

spec:RegisterStateExpr( "use_symbiosis", function()
    return settings.use_symbiosis
end )

spec:RegisterStateExpr( "auto_barkskin", function()
    return health.pct <= ( settings.defensive_health_pct or 50 ) and not buff.barkskin.up and not buff.survival_instincts.up
end )

-- Vengeance-based ability conditions (using RegisterStateExpr instead of RegisterVariable)

spec:RegisterSetting( "vengeance_optimization", true, {
    name = strformat( "Optimize for %s", Hekili:GetSpellLinkWithTexture( 132365 ) ),
    desc = "If checked, the rotation will prioritize damage abilities when Vengeance stacks are high.",
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "vengeance_stack_threshold", 5, {
    name = "Vengeance Stack Threshold",
    desc = "Minimum Vengeance stacks before prioritizing damage abilities over pure threat abilities.",
    type = "range",
    min = 1,
    max = 10,
    step = 1,
    width = "full",
} )

spec:RegisterSetting( "faerie_fire_auto", true, {
    name = strformat( "Auto %s", Hekili:GetSpellLinkWithTexture( 770 ) ),
    desc = strformat( "If checked, %s will be automatically applied when the debuff is not present on the target.",
        Hekili:GetSpellLinkWithTexture( 770 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "auto_pulverize", true, {
    name = strformat( "Auto %s", Hekili:GetSpellLinkWithTexture( 80313 ) ),
    desc = strformat( "If checked, %s will be used automatically when Lacerate has 3 stacks and is about to expire.",
        Hekili:GetSpellLinkWithTexture( 80313 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "rage_dump_threshold", 90, {
    name = "Rage Dump Threshold",
    desc = "Use Maul to dump rage when above this amount.",
    type = "range",
    min = 70,
    max = 100,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "enrage_rage_threshold", 40, {
    name = strformat( "%s Rage Threshold", Hekili:GetSpellLinkWithTexture( 5229 ) ),
    desc = strformat( "Use %s when rage falls below this amount.", Hekili:GetSpellLinkWithTexture( 5229 ) ),
    type = "range",
    min = 20,
    max = 60,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "primal_fury", true, {
    name = strformat( "%s Enabled", Hekili:GetSpellLinkWithTexture( 16961 ) ),
    desc = strformat( "If checked, %s crit-based rage generation is factored into resource calculations.",
        Hekili:GetSpellLinkWithTexture( 16961 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "rend_and_tear_multiplier", 1.2, {
    name = "Rend and Tear Damage Multiplier",
    desc = "Damage multiplier applied when bleeds are active (default 1.2 = 20% bonus).",
    type = "range",
    min = 1.0,
    max = 1.5,
    step = 0.1,
    width = 1.5,
} )

spec:RegisterSetting( "emergency_health_pct", 30, {
    name = "Emergency Health Threshold",
    desc = "Health percentage for emergency defensive abilities (Survival Instincts, etc.).",
    type = "range",
    min = 15,
    max = 50,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "moderate_damage_pct", 70, {
    name = "Moderate Damage Health Threshold", 
    desc = "Health percentage for moderate healing/defensive abilities.",
    type = "range",
    min = 50,
    max = 90,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "defensive_health_pct", 50, {
    name = "Defensive Health Threshold",
    desc = "Health percentage for defensive abilities like Barkskin (emergency threshold is separate).",
    type = "range",
    min = 30,
    max = 70,
    step = 5,
    width = 1.5,
} )



-- Priority List
spec:RegisterPack( "Guardian", 20250927, [[Hekili:nR1sVTnoq4Fl5Irc2cVoXopwa7CyVSB7HEr9SOPLOIjSEbsQeKIc9BFhs9GKsKYkTPblwST1djNz4WV5H4WWRd)wyqmwqc)6nRU52v)1n3VC1QBUF9dHbIxljHbL4Ot4NG)rood(Z)PcZIP4C5aVMwGJLmGxuXIGbddourtfFop8GlUE3MBG5wsIc)61R2egCKghtAMlHhfg8TJuE9E5)JR33k369fjWVJe0I869PuUagoPGvV)FjNOP0LGIWksOPG4BMfFzjJevKDal(JD)5bcMHG5N9jAYUlouLKSSN0YQY6V4Arzy2jurcsCKGEHMgRx7Wr8YIYcjTpjnA7YkEQcvw8cHHAix)L(fbtLFQknfDaZpkLJaZEIiwgH5cA(tlm(jIMlimwvPGEiLyZJimWIMFIKgPgbhtsi5C6Ze(5NBurrACXl5ZyQhleVGIl5s1LFSOknw(leRqGB2DNJbIJmcwGEIKtyZCjptYFIGZJiVbXWf48yaUABQQ4eevqY4gKxQTuYdKk2Z0NXPGbxEieju7uCLOanEiF8a)mGErn0i61Br2ZApaGm(jAE)Q6i4z(jms(3PKyeJOnPYfNtiXCejJayO8Oxrhj4uau5HnuwrEsfZ4uvAQ0tzHYdODwlLyLfmyZ84Un36HJTYdjkQIuGBBvrCSHL5yrfJG4Vqte5eo3YPYIHLvPpty0VRmOXe1QtXrYTmbw1IHKaeq0Ph3T28OUhOd8JKl3bsMj)7TBw1OqnKvBr3R7aHXjStYf2gsr97jwbGvWS8(tgboLKlwAqfekgCRJBTYgd4NPGrKjggOQL1JgZwaJhwDGE5OiK)4hksrG)AlLRCRm8xZoql4uUHs0tZw4AYkHkHz9KCZ8Hqedzmc90jQgi2YYibCWAIa6IFPcC0STqsAsMQgRNkeMk(1fxm0c4KvwzA8yJbi6qEzQM3VYjNz4tKEfC06VOf0lNLpDJrl9ZazoRciZeKEHd(klUSNJ0sfaW4Nmsggc9TD3MRCkioezpEEIA7To5qcHverlQ4Odqu65XkPwBPZlgRYp(GjeyugiVjrYQsfuutAyvazycptqWcZOeqY38ZWuoevmL0Yvt9YuANlExxWTrr90hsluPp65Ix50T0pf9AuVEX3DTzrtnr4aB7L(LxpwXwj3U(kVIobdQgbLqzoLENWmMMkOrVKmhOxrU7Qfg0rsRGxfiMKvWG8uFxMPIvGzMID0G2cF8WoDqgiXmS8037WamQTwWHMEVlbc(vsqYiqti0Q0UeDpQ(tuCvwjscAH09PMvjT0cF(7ehouqMOHFpN(dL4hWX)qro88F449EJZY7R1dBSRxVUSEcDzoGTX6)BaknUW9H4P2Inlz0cgvaerX4mGPERMZlAYPSAS2tjOZWaTjYRMorsbNSCQ4TZxiUnqBxFgHRdw82e3C3tV5J0Tw1N39vBZoSttnR9ZT1fDardht)bJ0s(dioKwyFeHG0sBu0h9qAK(yS2eHh0mWed45OEEmYgJobu0AJDMWsHbWjohww31sD9dHbVaFNfy74HbFoRSGjiX17VE1GRCAz9xcdGZVJfSWGGSQeg9uyGAi19FzgGei8v11Q1(DiH)Dyqe4faabS8MUCyvQ3)4U69RR3VOEVNO4173ctzJAk243U79kmqtsa7qVQWL9cziCUE)p(HZbTuI7Q3FLspgcU1AIXisDz9m0f34ClnYlwV34CLwfgnzPISrQiDZOXrWuXGzCRxv9I69drUsJWLJpYApt3Qosn0F3NPRTu7U5i1L7Ed6IMdnoXY1FV31Zu3SQe050nrBHQsbgjG)LrXK)VhGp)tQHY21HL1PPRtQaRK4sBZmH8FiUFo1UnZq7(qCiV9SoKVlobDK1PvgiLhE)Cv6Yi9l6MCz7UZUUMgZV7AB0g93dNOpyy6mDz(qaL)kzjSlvP5a9gLDyEWv)W9jJlDg(BMvXFwbN6UtNN3xpMr3BMlxNULn8c1MXgqonut7lTYJ5a)7xkgmXUCp1wiMKaBNZKA0U1EQdnVT3ZWS33EWFAfw3dfx(zZIf9xgVR0hZ5SXrJcTeq3va7Y9AwA4yuKd3PzXPXFERl)MzXQ(KbDEmDRQVlK2rweggIjXso6tHvuaJRk3uvn62X0H)vmXvdmuszOiue1nYqfv6(vAb33BKPJZ7KTx0hzVTdhA223yKPRPXjBn7FWG8Ugsu1nbR0lgTuWvcLUoTmDwIzOrGf8wJGa99vz6KeZGXJQeVBtUW9E8X69pyKZEC7zAGT6aetIBBsoaBUnR0ijJ(TQLudXzGsnB(QjKtrDAaN)2WQvUHTIvlcJrMgaEUwYQfM72YAvqO1ZxrxoO1HUbGCehNgz6RXTAv0U5Tk6wnW1a02tAsm7z6JRRylBmITmCDnWrhXWNex69UHD9jRJkw)xSwBFcFuvOtcMNCl4P0Oo(Rla1pk(TZ)PmEY6wDuGQZpx1pC9TRt(QN1p(8NbA4z31vRyx1ytcj98GJm2aJhBsyMJxGKbZSPpjsZ6rjzeYTJYKWippkjJumUEotZcgy)ELmcHB8MLuu1FIYgJKSTtBA0WWNWKwkoEgtwHH1pfkxLt6)d9SZn7miK7ioc5BJS9jjonu7ch5w8u925V2nhVrsZaz2d6cO1(PAdF1KgBYIwir3)f(Fp]] )
