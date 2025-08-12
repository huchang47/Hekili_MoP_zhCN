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
    -- Bear Form
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },

    -- Defensive abilities
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },

    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1,
    },

    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },

    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 1,
    },

    -- Offensive abilities
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },

    berserk = {
        id = 50334,
        duration = 15,
        max_stack = 1,
    },

    -- Debuffs
    lacerate = {
        id = 33745,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
    },

    thrash_bear = {
        id = 77758,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
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

    -- Buffs from talents
    incarnation = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },

    nature_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
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

    -- Generic buffs
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },

    -- Procs and special effects
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
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

    dream_of_cenarius_damage = {
        id = 108373,
        duration = 15,
        max_stack = 1,
    },

    dream_of_cenarius_healing = {
        id = 108373,
        duration = 15,
        max_stack = 1,
    },

    mangle = {
        id = 33917,
        duration = 0,
        max_stack = 1,
    },

    tooth_and_claw_debuff = {
        id = 135286,
        duration = 6,
        max_stack = 1,
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

} )

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
        id = 33917,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 132135,

        form = "bear_form",

        handler = function ()
            if talent.infected_wounds.enabled then
                applyDebuff( "target", "infected_wounds" )
            end
            
            removeBuff( "tooth_and_claw" )
            
            if set_bonus.tier16_4pc == 1 and active_dot.thrash_bear > 0 then
                if math.random() < 0.4 then
                    setCooldown( "mangle", 0 )
                end
            end
        end,
    },

    -- Lacerate (Guardian ability)
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "lacerate", 15, min( 3, debuff.lacerate.stack + 1 ) )
            
            if talent.tooth_and_claw.enabled then
                if math.random() < 0.4 then
                    applyBuff( "tooth_and_claw", 6, 2 )
                end
            end
        end,
    },

    -- Pulverize (Guardian ability)
    pulverize = {
        id = 80313,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 20,
        spendType = "rage",

        startsCombat = true,
        texture = 236149,

        form = "bear_form",

        handler = function ()
            if debuff.lacerate.stack >= 3 then
                removeDebuff( "target", "lacerate" )
                applyBuff( "pulverize" )
            end
        end,
    },

    maul = {
        id = 6807,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",

        handler = function ()
            if buff.tooth_and_claw.up then
                local stacks = buff.tooth_and_claw.stack
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff", 6 )
            end
        end,
    },



    -- Defensive abilities
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 136097,

        handler = function ()
            applyBuff( "barkskin" )
        end,
    },

    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 236169,

        handler = function ()
            applyBuff( "survival_instincts" )
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

    -- Rage generators
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 136224,

        form = "bear_form",

        handler = function ()
            applyBuff( "enrage" )
            gain( 20, "rage" )
        end,
    },

    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 236149,

        talent = "berserk",

        handler = function ()
            applyBuff( "berserk" )
            setCooldown( "mangle", 0 )
        end,
    },

    -- Utility
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,

        handler = function ()
            applyDebuff( "target", "faerie_fire" )
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

    -- Savage Defense (Guardian ability)
    savage_defense = {
        id = 62606,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        talent = "savage_defense",
        toggle = "defensives",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "savage_defense" )
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



    -- Swipe (Bear form)
    swipe_bear = {
        id = 779,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",

        handler = function ()
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                -- Hit multiple enemies
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
            applyDebuff( "target", "thrash_bear", 15 )
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                for i = 1, applied do
                    if i == 1 then
                        applyDebuff( "target", "thrash_bear", 15 )
                    else
                        applyDebuff( "target" .. i, "thrash_bear", 15 )
                    end
                end
            end
        end,
    },

    -- Symbiosis (MoP ability)
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = false,
        texture = 136033,

        handler = function ()
            applyBuff( "symbiosis" )
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
    desc = strformat( "If checked, %s will be recommended when you have sufficient rage.",
        Hekili:GetSpellLinkWithTexture( 62606 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "savage_defense_rage_threshold", 80, {
    name = "Savage Defense Rage Threshold",
    desc = "The minimum rage required to use Savage Defense.",
    type = "range",
    min = 50,
    max = 100,
    step = 5,
    width = 1.5,
} )

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



-- Priority List
spec:RegisterPack( "Guardian", 20250721, [[Hekili:DVX(VnUT5)wckGQD3np)ioxANDa6w36UdDhkMV(tf1smw02Arp8KOsAkc0F77JpfPejTC6T1HHd5UtsF879ls(LTZ2(XTBIre82pmF68LtF78ztMnB68zB3qE(eE7MtODpGoa)NCug83hQrLXjO8MicUIq)8ZPfOykwQkQl3bGSDZ91jPK3LV9EBOE285aSNW72(HztVE7MJjXXyoS4QDB38XJjvnr0FqnrcQ3evShEEhjPaOCAsfb(8(IYMO)g(HK0KjB3WEjLnovI3vKDpIap8bM4HZr3NIJ3(N4KOm5efpB38nL1jXFvt03kKPTB4uaeamQmeWF2wcW8DWbGacUmbTDZvnr3xVF)Kmu5dHf7djhXHpLKgpP(utuqt0HYI6tTyTlyuKV4SiV65S7tkQsQKyLGkpGjtW)mxnaV5reScadtQRWHk4BjC7RakETtksqP4CYK4smkJYN7aOktQRMiGMrljB1dQWyugyQMOlXhXO0K8dHKI6DhPeF55fx0JawcJX7X5vyPmBkHgGOjMMVNa)zZbCoUe8bdlPoXw8iA5GDffPXfpLdMZ8daPabm(zDRh9T(DiuOGCSevDmK6hXXdtkgX9HFehcCvwcgSE31enRj6Lxyk2ymtfOVyQ8pULj0(KFVhbQsr7yI)Kkcej1eTstvk)wi7BCpPswWga1TlBjQeq)EpwKSfUXz1tjNWs5aStuGcbvm8pzGtOnlLCP7qPPH8hcPr96mHIw3mvpwHKKHbNWW4emJXULNViuKtZWhXIbE4u(okLnqoKPlpwH5Ugm3ywdf7tstXLIpxX1xGwcKS8Dp73Nwi)7qveiouxLiCqeFH6KkyfLf6HAGNUhC387ZlYAKLC4i5zg8g5lSWbx1Lj0xRrcZ2373BxWd0KQH7osXTnEiguPO8Dcxa7FbCDMR5MQHr)E)9Kji3)tPDszZ)hqbSgQSLIEgdX35jKwYXwe3adzXq1Pwde6N0uvVYq95Tk2G88A9YET(UYmIwl9mK4kAjeYXjN2r45qMYZwMKdf5PLw4vDcxYZ4iGod9ZnrFrt00juJPg7WRna5PQSvnAqsugkjNa)egxqyy5Mxdw6MVJzZnd0Nmixa7fuSfLbUXa6Zpq1ALfIAlQ8Z01P543f4Z2iKjTIXzfLqT)FPlXeGHkZODVbeDAhEyAlp0dj)hSKxhX)vxYBMBC2TKxBOXaJXlRWLpivKJ0kSETiOWw1oAcnXNzObcCqL5iMxzf8d0bxDzvXUUDAii3GY9RHtR9k6LMCzPty(nocZNn1rC(sVAGflnKnx8ZWAihNxY7Z1S7g)DCO7iWrWG6fhKZsIXwl01V91BNXtyPUNGUd1yJE2njP)(2fmkOnRlXvHpMCij1Gj7WHVvla3yr2sL2Jmq1SDykZXxAxTrVaY1SMqVipPRn0gDiipY1SeG3OxhjLwFMKsJAdEovN(iGRFH7XPSETVUet5NkE5rdMxbJ)O4xtItkFmsTJf1s15LRPbLb9HziQGX2tf7n40XUNOCQLpPZPluYJZm6Nbd34BxAE7Au2cmFpNDyy1orBPKEbY2TK6o(uGPNWOhaPkoKv5vZeVWxzzLbs5XVhbOfhUpPuBJ36Vu28QSnlVrhDYnOiNA9HCiGCrqEIJq9sJ6kv1LpM8ikneuoWUl2ruNrIeI9L48Fjbe7sSyxE0AucGgApKl0QH3JI(dT(vkGEz)rA9ziRxEi95thDSmvUs90B2G0FK2Vsr6Eu5dvpKOlfd1omxuK3rwE9Mxeezq1ybva(jK3IwdvivN)JeNDodjXRhufv(5QbDN8eQm(tbZjTaMiwFdJgFXF9y)hxNYVuXBMWXopKoS3L4iOvhKuuaskkh2MEk6jEZmM5UUOJm8dV9tTJ)ibJkB2b2gWEsoUQsLS32U4LsbF3u9oRvXbRQLhFUrhCgN6kX4uO8Mq2Lkv3MUWOcuDQ)mGQLDlVBGUbVRLvy1A5XcdOS3wC4g3NFCN(Ysf(5MY3YPo2ZMNujQf)L9vomdaerLd2Kk69BaqMKDQOKiUdJp3((()CGNW)RAOOk4ivvKbldvtkYGEHGxaBqp)aUAsZ7)UKC4tZ(QMOFiVQ(efXua4ydWE3TY)5Q1m35A6T172fTW5IKDQ1c71oHTvXsHMPt2xKMw8e7qcr1qdunrpHlH3dXVX0CdqxkuWKOGEykuFcIeU8cMcTo3a64ykWXic6Euf(RAEFt0VN2Fvh5t8EPiap(ElgkJtk(tL9H3f3qSkA9v()z2JZO3BtF9PtPxNoevUjCU11M6VZPTLy9)66zZSNIxAMU1Hj4tCsj6IcreA5lQIWkjv3K7Lrupgj59G2AJw6gydv1Vjwlx3XQpJPsgDOuvN64LPuDhH46W0gsud)KWgI1W4OI(nXyW5vXdUeAhkDJdm6Yu8UdHuNUZqYJ1VwGBRI1Ym(sMzw)YTru7Cc(nXeQvLH(iNXfpO0MINnpWe3jffNZXLzuV5)LZ6i38SZKqI9xi(EV91CPLAOJ6ZPYcOjymFUFYsQQyIQqbj02SMVs2biPmj)bmbuNrnrVJWxeRwrg0MavHqoIGxJbd6ZuCNuanQ)mlQnToM21pob0aLsj(h)bGbbmHZQ(P3aQSJj7oQdnk)5wQkuM4F(uAYUesAlE11TsI(hBIkKnx(JFKJciO(NOinw)vZ1O8tW(b0KibkjsqzAd2RYRZUhZD5sliGZY7YKEuZMA6oqD(GTMutowuUDZMS69LjpqNwkMIF7MpRjQ78q18(pdE7gmHEZ9GzvUJ33qVcZ1U327BEeLwJxF70UlX7Ha4CvDoCybCl6cMXSpjaAMvGm4cxqA7epBHLRA(EzdknrFntvdkjUoVAIQ5LF36)GAJ92)C35c7nj7xFL48F7nyzbSHkZoIAfFfg0NESaJjhlW(uJzhZghPaf7NBwXcUYXjxOMsmhIGPXPvo6UT)apNVJ0(83r04XVwef89Q8aFhn9OK8ar1Agv)1kZwlByCenAG29U(5(qQXN48GQAl78G2w0HYxTNk1QBN(Yl9pcT7Ap(SVGDgQNLagDRCEW7mkdsL)Frj8QGJOrVlNGllRprQejaFhKHdY1a1KJ(iKjarQg36yO0Fuhd14iXD)0NQOa)Z0KDeQnCrAo0wgJPGoe7kFdVKDAPngrA0YY4kf0zGKU72UVzLMf0GgSzhI5PAFqKcmgcPRwZhaP2qL)jTQYFUNB4eLNjlIGDLX6XdY7qoye1py11Gpy)lFE1C41Sf4zuagBNMUwHMI0Y8hiY)4HCbJ0cDUXsOZSPDIDwAv0wS0bJZ3WqRUsn3abmn1ntd6JT7MT0oY6DR8AIVZHeWqeDyzwkTmTMshYJXwW0iV1R(pqJYVDQDe25U11qPJR5pyefnTNE7DRxmaZ21JLo5FJmZPvh928Q00n9UOVojBhWX)l8bTElLIV56c(coxE8fo4BRi8vZ6ozpwW(D0OMbCJJJDWRYnA8QzpT7smy050yZHW3EUpUynXf1P5s25wcdUqg2(nd6G6g3dNgpy9kbVuo5kRxcORWGb3ogZHyyx33aSvICs9UiOX(B7ZQm0R31luHnY5139Yl97kCCWqUYUvZv5Kk(OOvOVHvVM31kbwfDEKvsKrpzGqPoUcQazDcBw7A6AcgX5A9blsOV7nurRUDSBEqIxNSWkxSWlVmYXKdT66jldUm5XdhQDswmFxRJi0lV4E4Ewbfy6w0zwGh4VXd3WpVjDgrn1pkEWCIFwnBQB0PVX0wlGTb9z1Ia9b85UPbEhShPR5)GEENG7OQZEUF6g6LXWo)hjN1zhao3PGX1Nr5zpncD7LJ(2BjsIBOc1LJgZBJ1uz8TQIBA7Nurbd5ZWGB93Ti3lSJFR7FTI61r0miNKvV8XUP2RpoM3j7TlDJ727fJI9om7I21RRKvoywuXT2yM(TMvI2ETcEjPftpZIzqD7YatEB9mzAYE4vKRSxjWXoiKxvWCoxUCqC5xovQO(RmFulh7KPZl1hVZT)BHhM1DlTw(nfGZM67oPhL6DN6w2mQTFVa6MBItPPEO0Vshw)IHxZ1mjcyt1X2)9p]] )
