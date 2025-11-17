-- RogueAssassination.lua July 2025
-- by Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local Hekili = _G[ "Hekili" ]
local class, state = Hekili.Class, Hekili.State
-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff = state.applyBuff, state.removeBuff, state.applyDebuff, state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt = state.summonPet, state.dismissPet, state.setDistance, state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action =state.buff, state.debuff, state.cooldown, state.active_dot, state.pet, state.totem, state.action
local setCooldown = state.setCooldown
local addStack, removeStack = state.addStack, state.removeStack
local gain,rawGain, spend,rawSpend = state.gain, state.rawGain, state.spend, state.rawSpend
local talent = state.talent
local floor = math.floor
local strformat = string.format

-- Create the Assassination spec (259 is Assassination in retail, using appropriate ID)
local spec = Hekili:NewSpecialization(259, true)

spec.name = "Assassination"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Ensure state is properly initialized
if not state then
    state = Hekili.State 
end

--资源
spec:RegisterResource( 3 ) -- Energy
spec:RegisterResource( 4 ) -- ComboPoints 

--[[
-- 在状态初始化部分添加
state.last_finisher_cp = 0  -- 初始化为0，表示没有使用过终结技

-- 能量资源
spec:RegisterResource( 3,
{
    -- 基础能量恢复
    base_regen = {
        last = function () return state.query_time end,
        interval = 1,
        value = function()
            local base = 10 -- MoP基础能量恢复10点/秒
            local haste = state.haste or 0
            local haste_bonus = 1.0 + (haste / 100) -- 急速百分比转换为乘数
            return base * haste_bonus
        end,
    },

    -- 无情打击能量返还
    relentless_strikes_energy = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            if state.last_finisher_cp then
                local energy_chance = state.last_finisher_cp * 0.2 -- 20% 每个连击点20%概率返还25能量
                return math.random() < energy_chance and 25 or 0
            end
            return 0
        end,
    },
} )

-- 连击点
spec:RegisterResource( 4,
{
    seal_fate = { --封印命运
        last = function ()
            return state.query_time -- Continuous tracking
        end,
        interval = 1,
        value = function()
            -- 基于简单的角色暴击率预测by风雪
            local critChance = (GetCritChance() or 0) / 100 -- 将百分比转换为小数形式
            return math.random() <= critChance and 1 or 0 -- 暴击后100%增加一个连击点数
        end,
    },

    --预感(可能有问题，后期再修改)
    anticipation_storage = {
        aura = "anticipation",
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Anticipation allows storing combo points beyond the 5-point limit
            if state.talent.anticipation.enabled and (state.combo_points.current or 0) >= 5 then
                return 1 -- Store excess combo points as Anticipation stacks
            end
            return 0
        end,
    },
},nil,{ --最大连击点
    max_combo_points = function ()
        return 5
    end,
} )
]]

-- 套装
spec:RegisterGear( "tier13", 78794, 78833, 78759, 78774, 78803, 78699, 78738, 78664, 78679, 78708,77025, 77027, 77023, 77024, 77026 ) --T13黑牙织战

-- 天赋
spec:RegisterTalents({
    -- Tier 1 (Level 15)
    nightstalker = { 1, 1, 14062 }, -- Increases damage done while stealthed.
    subterfuge = { 1, 2, 108208 }, -- Allows abilities to be used for 3 seconds after leaving stealth.
    shadow_focus = { 1, 3, 108209 }, -- Reduces energy cost of abilities while stealthed.
    
    -- Tier 2 (Level 30)
    deadly_throw = { 2, 1, 26679 }, -- Throw a dagger that slows the target
    nerve_strike = { 2, 2, 108210 }, -- Reduces damage done by targets affected by Kidney Shot or Cheap Shot.
    combat_readiness = { 2, 3, 74001 }, -- Each melee or ranged attack against you increases your dodge by 2%
    
    -- Tier 3 (Level 45)
    cheat_death = { 3, 1, 31230 }, -- Fatal damage instead reduces you to 7% of maximum health
    leeching_poison = { 3, 2, 108211 }, -- Your poisons also heal you for 10% of damage dealt
    elusiveness = { 3, 3, 79008 }, -- Reduces cooldown of Cloak of Shadows, Combat Readiness, and Dismantle
    
    -- Tier 4 (Level 60) 
    cloak_and_dagger = { 4, 1, 138106 }, -- Ambush, Garrote, and Cheap Shot have 40 yard range and will cause you to teleport behind your target
    shadowstep = { 4, 2, 36554 }, -- Step through shadows to appear behind your target and increase movement speed
    burst_of_speed = { 4, 3, 108212 }, -- Increases movement speed by 70% for 4 sec. Each enemy strike removes 1 sec
    
    -- Tier 5 (Level 75)
    internal_bleeding = { 5, 1, 154953 }, -- Kidney Shot also causes the target to bleed
    paralytic_poison = { 5, 2, 108215 }, -- Coats weapons with poison that reduces target's movement speed
    dirty_tricks = { 5, 3, 108216 }, -- Reduces cost of Blind and Sap.
    
    -- Tier 6 (Level 90) - Correct MoP Classic talents
    shuriken_toss = { 6, 1, 114014 }, -- Throw a shuriken at target
    marked_for_death = { 6, 2, 137619 }, -- Instantly generates 5 combo points
    anticipation = { 6, 3, 114015 }, -- Allows combo points to exceed 5, up to 10
})

-- 雕文
spec:RegisterGlyphs( {
    --大型雕文
    [56813] = "ambush", --伏击雕文
    [63269] = "cloak_of_shadows", --暗影斗篷雕文
    [56811] = "sprint", --疾跑雕文
    [146629] = "redirect", --转嫁雕文
    [56799] = "evasion", --闪避雕文
    [63249] = "vendetta", --仇杀雕文
    [56804] = "feint", --佯攻雕文
    [56801] = "cheap_shot", --偷袭雕文
    [56809] = "gouge", --凿击雕文
    [146628] = "sharpened_knives", --削铁如泥雕文
    [56818] = "blade_flurry", --剑刃乱舞雕文
    [56806] = "recuperate", --复原雕文
    [146631] = "hemorrhaging_veins", --动脉出血雕文
    [146625] = "recovery", --恢复雕文
    [56808] = "shadow_walk", --暗遁雕文
    [56810] = "shiv", --毒刃雕文 你的毒刃技能的冷却时间缩短3秒
    [89758] = "vanish", --消失雕文
    [63253] = "stealth", --潜行雕文
    [56819] = "smoke_bomb", --烟雾弹雕文
    [56803] = "expose_armor", --破甲雕文
    [56805] = "kick", --脚踢雕文
    [63254] = "deadly_momentum", --致命冲动雕文
    [91299] = "blind", --致盲雕文
    [56812] = "garrote", --锁喉雕文
    -- 小型雕文
    [63268] = "disguise", --伪装雕文
    [125044] = "detection", --侦测雕文
    [56807] = "hemorrhage", --出血雕文
    [63256] = "tricks_of_the_trade", --嫁祸诀窍雕文
    [58033] = "safe_fall", --安全降落雕文
    [58027] = "pick_lock", --开锁雕文
    [146961] = "improved_distraction", --强化扰乱雕文
    [58032] = "distract", --扰乱雕文
    [58017] = "pick_pocket", --搜索雕文
    [63252] = "killing_spree", --杀戮盛筵雕文
    [58039] = "blurred_speed", --水上漂雕文
    [146960] = "the_headhunter", --猎头煞星雕文
    [58038] = "poisons", --药膏雕文
    [56800] = "decoy", --诱饵雕文
} )

-- 刺杀贼光环
spec:RegisterAuras({
    -- Weapon Poison Buffs (applied to weapons)
    deadly_poison = {
        id = 2823,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    instant_poison = { --致伤药膏
        id = 8679,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    wound_poison = {
        id = 8679,
        duration = 3600, -- 1 hour duration  
        max_stack = 1
    },
    leeching_poison = {
        id = 108211,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    paralytic_poison = {
        id = 108215,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    crippling_poison = {
        id = 3408,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    mind_numbing_poison = {
        id = 5761,
        duration = 3600, -- 1 hour duration
        max_stack = 1
    },
    
    -- Poison Debuffs on targets (MoP mechanics)
    deadly_poison_dot = { --致命毒药dot
        id = 2818,
        duration = 12, 
        tick_time = 3, 
        copy = "deadly_poison_debuff"
    },
    instant_poison_debuff = { --致伤药膏dot
        id = 8680,
        duration = 15,
        max_stack = 1
    },
    wound_poison_debuff = {
        id = 13218,
        duration = 15, -- 15 second duration
        max_stack = 5, -- Stacks up to 5 times, reduces healing by 10% per stack
        copy = "mortal_wounds"
    },
    crippling_poison_debuff = {
        id = 3409,
        duration = 12, -- 12 second duration
        max_stack = 1, -- Reduces movement speed by 70%
        copy = "crippling_poison_slow"
    },
    mind_numbing_poison_debuff = {
        id = 5760,
        duration = 16, -- 16 second duration
        max_stack = 5, -- Stacks up to 5 times, increases casting time
        copy = "mind_numbing_poison_slow"
    },
    paralytic_poison_debuff = {
        id = 113952, -- MoP paralytic poison debuff
        duration = 4, -- 4 second stun duration
        max_stack = 1
    },
    leeching_poison_debuff = {
        id = 112961, -- MoP leeching poison effect
        duration = 8, -- Duration for tracking
        max_stack = 1
    },
    
    -- Bleed effects
    rupture = { --割裂
        id = 1943,
        duration = function() return 4 + (4 * (combo_points.current or 0)) end,
        tick_time = 2, -- Ticks every 2 seconds
        max_stack = 1
    },
    garrote = {
        id = 703,
        duration = 18, -- 18 second duration
        tick_time = 3, -- Ticks every 3 seconds
        max_stack = 1
    },
    
    -- Buffs
    slice_and_dice = { --切割
        id = 5171,
        duration = function() return 6 + (6 * (combo_points.current or 0)) end,
        max_stack = 1
    },
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1
    },
    cold_blood = {
    id = 14177,
    duration = 60, -- Correct 1 minute duration for MoP
    max_stack = 1
},
    vendetta = { --仇杀
        id = 79140,
        duration = function() return 20 + ((set_bonus.tier13_4pc == 1 and 9) or 0) end,
        max_stack = 1
    },

    -- Revealing Strike (Combat spec debuff on target, referenced in imported rotations)
    revealing_strike = {
        id = 84617,
        duration = 15,
        max_stack = 1,
        debuff = true -- Mark as target debuff
    },
    
    -- Deep Insight (Combat spec debuff on target, referenced in imported rotations)
    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1,
        debuff = true -- Mark as target debuff
    },
    
    -- Venom Rush talent buff
    venom_rush = {
        id = 152152,
        duration = 30,
        max_stack = 1
    },
    
    -- Stun effects
    kidney_shot = {
        id = 408,
        duration = function() return 1 + (combo_points.current or 0) end, -- MoP Classic: 1s base + 1s per combo point
        max_stack = 1
    },
    cheap_shot = {
        id = 1833,
        duration = 4,
        max_stack = 1
    },
    
    -- Talent effects
    nerve_strike = {
        id = 108210,
        duration = 6,
        max_stack = 1
    },
    internal_bleeding = {
        id = 154953,
        duration = 6,
        tick_time = 2,
        max_stack = 1
    },
    
    -- Utility
    evasion = { --闪避
        id = 5277,
        duration = 10,
        max_stack = 1
    },
    feint = {
        id = 1966,
        duration = 10,
        max_stack = 1
    },
    sprint = {
        id = 2983,
        duration = 15,
        max_stack = 1
    },
    shadowstep = {
        id = 36554,
        duration = 0,
        max_stack = 1
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1
    },
    
    -- Stealth and related buffs
    subterfuge = {
        id = 115192,
        duration = 3,
        max_stack = 1
    },
    master_of_subtlety = {
        id = 31665,
        duration = 6,
        max_stack = 1
    },
    overkill = {
        id = 58426,
        duration = 20,
        max_stack = 1
    },
    nightstalker = {
        id = 14062,
        duration = 3,
        max_stack = 1
    },
    -- MoP Trinket auras
    vial_of_shadows = {
        id = 79734, -- Vial of Shadows proc aura
        duration = 15,
        max_stack = 1
    },
    
    -- Shadow Dance (for compatibility with imported rotations)
    shadow_dance = {
        id = 185313, -- Shadow Dance spell ID
        duration = 8,
        max_stack = 1
    },
    
    -- Anticipation (Level 90 talent)
    anticipation = { --预感
        id = 114015,
        duration = 3600,
        max_stack = 5
    },
    
    -- Virmen's Bite (MoP agility potion, formerly called Jade Serpent Potion)
    jade_serpent_potion = {
    id = 105697, -- Correct MoP agility potion buff ID
    duration = 25,
    max_stack = 1,
    copy = "virmen_bite" -- Alternative name
},
    
    -- Tricks of the Trade
    tricks_of_the_trade = {
        id = 57934,
        duration = 6,
        max_stack = 1
    },

    --盲点
    blindside = { 
        id = 121153, 
        duration = 10,
        max_stack = 1
    },
    
    -- Shadow Blades - Major DPS cooldown buff
    shadow_blades = { --暗影之刃
        id = 121471,
        duration = 12,
        max_stack = 1
    },
    
    -- Cloak of Shadows - Defensive buff
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1
    },
    
    -- Crimson Tempest debuff
    crimson_tempest = {
        id = 121411,
        duration = function() return 2 + (2 * (combo_points.current or 0)) end, -- 2s base + 2s per combo point
        max_stack = 1,
        tick_time = 2 -- Ticks every 2 seconds
    },
})

-- State Expressions for MoP Assassination Rogue
spec:RegisterStateExpr("stealthed", function()
    return {
        all = buff.stealth.up or buff.vanish.up or buff.subterfuge.up,
        normal = buff.stealth.up,
        vanish = buff.vanish.up,
        subterfuge = buff.subterfuge.up
    }
end)

spec:RegisterStateExpr("effective_combo_points", function()
    local cp = combo_points.current or 0
    -- Account for Anticipation talent
    if talent.anticipation.enabled and buff.anticipation.up then
        return cp + buff.anticipation.stack
    end
    return cp
end)

spec:RegisterStateExpr("behind_target", function()
    -- Intelligent positioning logic for Assassination
    -- Stealth abilities work regardless of positioning
    if buff.stealth.up or buff.vanish.up or buff.subterfuge.up then
        return true -- Stealth negates positioning requirements
    end
    
    -- In group content, assume tank has aggro and we can be behind
    if group then
        return true -- Tank should have aggro in groups
    end
    
    -- Solo PvE: assume we can position behind mobs
    if target.exists and not target.is_player then
        return true -- PvE mobs, can usually get behind
    end
    
    -- PvP or uncertain cases: use time-based deterministic positioning
    -- This prevents blocking abilities while being somewhat realistic
    local time_factor = (query_time % 10) / 10 -- 0-1 based on time
    return time_factor > 0.3 -- 70% of time cycles we're "behind"
end)

-- Stealth-breaking hook for proper MoP mechanics
spec:RegisterHook("runHandler", function(action, pool)
    -- Handle stealth-breaking for non-stealth abilities
    local stealth_abilities = {
        "stealth", "vanish", "garrote", "ambush", "cheap_shot", "sap", "pick_pocket", "distract"
    }
    
    local breaks_stealth = true
    for _, ability in ipairs(stealth_abilities) do
        if action == ability then
            breaks_stealth = false
            break
        end
    end
    
    if breaks_stealth then
        if buff.stealth.up and not talent.subterfuge.enabled then
            removeBuff("stealth")
        elseif buff.stealth.up and talent.subterfuge.enabled then
            -- Subterfuge extends stealth abilities for 3 seconds
            removeBuff("stealth")
            applyBuff("subterfuge", 3)
        end
        
        if buff.vanish.up and not talent.subterfuge.enabled then
            removeBuff("vanish")
        elseif buff.vanish.up and talent.subterfuge.enabled then
            removeBuff("vanish")
            applyBuff("subterfuge", 3)
        end
    end
    
    -- Handle Overkill buff from stealth abilities
    if action == "ambush" or action == "garrote" or action == "cheap_shot" then
        if stealthed_all then
            applyBuff("overkill", 20) -- 20-second energy regeneration bonus
        end
    end
end)

-- Hook for Master of Subtlety and other stealth-related mechanics
spec:RegisterHook("reset_precast", function()
    -- Ensure proper stealth state tracking
    if buff.stealth.up or buff.vanish.up or buff.subterfuge.up then
        -- Master of Subtlety damage bonus (if it applies to other specs via talent)
        if talent.master_of_subtlety and talent.master_of_subtlety.enabled then
            applyBuff("master_of_subtlety", 6)
        end
    end
end)

-- 刺杀贼技能
spec:RegisterAbilities({
    -- Basic attacks
    mutilate = { --毁伤
        id = 1329,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 55
            -- Shadow Focus reduces cost while stealthed
            if talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up) then
                cost = cost * 0.25 -- 75% cost reduction in stealth
            end
            return cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            gain(2, "combo_points")
        end,
    },
    
    -- Dispatch - Assassination finisher that can be used with 1+ combo points or on low health targets
    dispatch = { --斩击
        id = 111240, 
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 30
            --触发盲点，不消耗能量
            if buff.blindside.up then cost = 0 end
            -- 暗影集中天赋下，潜行消耗能量为25%
            if talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up) then
                cost = cost * 0.25
            end
            return cost
        end,
        spendType = "energy",
        startsCombat = true,
        
        usable = function()
            --触发盲点或生命值低于35%
            return buff.blindside.up or target.health.pct < 35, "requires blindside or target below 35% health" 
        end,
        
        handler = function()
            gain(1, "combo_points")
            -- 移除盲点buff
            removeBuff("blindside")
        end,
    },
    
    -- Fan of Knives - AoE combo point generator
    fan_of_knives = { --刀扇
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function()
            local cost = 35 -- MoP: Fan of Knives costs 35 energy
            
            -- Shadow Focus reduces cost while stealthed
            if talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up) then
                cost = cost * 0.25
            end
            
            return cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            -- Fan of Knives generates 1 combo point per target hit (up to 1 in single target)
            local targets_hit = active_enemies > 0 and math.min(active_enemies, 1) or 1
            gain(targets_hit, "combo_points")
            
            -- Apply poisons to all targets hit
            if buff.deadly_poison.up then
                applyDebuff("target", "deadly_poison_dot", 12, min(5, debuff.deadly_poison_dot.stack + 1))
            end
            
            -- Track for Seal Fate (though FoK doesn't typically crit for extra CPs in MoP)
            -- state.last_ability removed for Hekili compatibility
        end,
    },
    
    -- Finishers 终结技
    envenom = { --毒伤
        id = 32645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function () return 35 * (( talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up)) and 0.25 or 1 ) end,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return (combo_points.current or 0) > 0 end,
        
        handler = function()
            local cp = combo_points.current or 0
            
            applyBuff("slice_and_dice", 36) --穷追猛砍，毒伤续五星切割
            spend(cp, "combo_points")
            
            -- Track for Relentless Strikes
--            state.last_finisher_cp = cp
        end,
    },
    
    rupture = { --割裂
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = function () return 25 * (( talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up)) and 0.25 or 1 ) end,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return (combo_points.current or 0) > 0 end,
        
        handler = function()
            local cp = combo_points.current or 0
            applyDebuff("target", "rupture", 4 + (4 * cp))
            spend(cp, "combo_points")
            
            -- Track for Relentless Strikes
--            state.last_finisher_cp = cp
        end,
    },
    
    slice_and_dice = { --切割
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return (combo_points.current or 0) > 0 end,
        
        handler = function()
            local cp = combo_points.current or 0
            -- MoP Classic: 6 seconds base + 6 seconds per combo point
            applyBuff("slice_and_dice", 6 + (6 * cp))
            spend(cp, "combo_points")
            
            -- Track for Relentless Strikes
--            state.last_finisher_cp = cp
        end,
    },

-- Add missing finishing moves for Assassination
    eviscerate = { --刺骨
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
    
        spend = 35,
        spendType = "energy",
    
        startsCombat = true,
    
        usable = function() return (combo_points.current or 0) > 0 end,
    
        handler = function()
            local cp = combo_points.current or 0
            -- Eviscerate: Damage scales with combo points
            spend(cp, "combo_points")
        
            -- Track for Relentless Strikes
--            state.last_finisher_cp = cp
        end,
    },

    kidney_shot = { --肾击
        id = 408,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
    
        spend = 25,
        spendType = "energy",
    
        startsCombat = true,
    
        usable = function() return (combo_points.current or 0) > 0 end,
    
        handler = function()
            local cp = combo_points.current or 0
            -- MoP Classic: 1 second base + 1 second per combo point (max 6 seconds)
            applyDebuff("target", "kidney_shot", 1 + cp)
            spend(cp, "combo_points")
        
            -- Track for Relentless Strikes
--            state.last_finisher_cp = cp
        
            -- Apply talent effects
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike", 6)
            end
            if talent.internal_bleeding.enabled then
                applyDebuff("target", "internal_bleeding", 6)
            end
        end,
    },

-- Stealth abilities
    stealth = { --潜行
        id = 1784,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return not incombat, "cannot stealth in combat" end,
        
        handler = function()
            applyBuff("stealth", 3600) -- Long duration until broken
            
            -- Master of Subtlety (if talented)
            if talent.master_of_subtlety and talent.master_of_subtlety.enabled then
                applyBuff("master_of_subtlety", 6)
            end
        end,
    },
    
    vanish = { --消失
        id = 1856,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,
        
        handler = function()
            applyBuff("vanish", 3) -- MoP: Vanish lasts 3 seconds
            
            -- Vanish breaks target lock and resets threat
            if target.exists then
                setCooldown("vanish", 120)
            end
            
            -- Master of Subtlety (if talented)
            if talent.master_of_subtlety and talent.master_of_subtlety.enabled then
                applyBuff("master_of_subtlety", 6)
            end
            
            -- Nightstalker talent bonus damage
            if talent.nightstalker.enabled then
                applyBuff("nightstalker", 3)
            end
        end,
    },
    
    -- Cheap Shot - stealth opener that stuns
    cheap_shot = { --偷袭
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function() 
            local cost = 40 -- MoP: Cheap Shot costs 40 energy
            
            -- Shadow Focus reduces cost while stealthed
            if talent.shadow_focus.enabled then
                cost = cost * 0.25 -- 75% cost reduction in stealth
            end
            
            return cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return stealthed_all, "requires stealth" end,
        
        handler = function()
            -- Cheap Shot generates 2 combo points and stuns for 4 seconds
            gain(2, "combo_points")
            applyDebuff("target", "cheap_shot", 4)
            
            -- Apply poisons
            if buff.deadly_poison.up then
                applyDebuff("target", "deadly_poison_dot", 12, min(5, debuff.deadly_poison_dot.stack + 1))
            end
            
            -- Nerve Strike talent
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike", 6)
            end         

            -- Remove stealth (unless Subterfuge)
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            else
                -- Subterfuge extends stealth abilities for 3 seconds
                removeBuff("stealth")
                removeBuff("vanish")
                applyBuff("subterfuge", 3)
            end
            
            -- Overkill energy bonus
            applyBuff("overkill", 20)
        end,
    },
    
    -- Opening abilities
    garrote = { --锁喉
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return stealthed_all and behind_target end,
        
        handler = function()
            applyDebuff("target", "garrote")
            removeBuff("stealth")
            removeBuff("vanish")
        end,
    },
    
    ambush = { --伏击
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function() 
            local cost = 60 -- MoP: Ambush costs 60 energy
            
            -- Shadow Focus reduces cost while stealthed (but Ambush requires stealth)
            if talent.shadow_focus.enabled then
                cost = cost * 0.25 -- 75% cost reduction in stealth
            end
            
            return cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return stealthed_all, "requires stealth" end,
        
        handler = function()
            -- Ambush generates 2 combo points
            gain(2, "combo_points")
            
            -- Seal Fate proc chance on crit (50% chance for extra combo point)
            if (state.crit_chance or 0) > math.random() then
                -- state.last_ability_crit removed for Hekili compatibility
                if math.random() <= 0.5 then
                    gain(1, "combo_points")
                end
            else
                -- state.last_ability_crit removed for Hekili compatibility
            end
            
            -- Apply poisons from stealth
            if buff.deadly_poison.up then
                applyDebuff("target", "deadly_poison_dot", 12, min(5, debuff.deadly_poison_dot.stack + 1))
            end
            
            -- Track last ability for Seal Fate
            -- state.last_ability removed for Hekili compatibility
            
            -- Remove stealth (unless Subterfuge talent extends it)
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            else
                -- Subterfuge extends stealth abilities for 3 seconds
                applyBuff("subterfuge", 3)
            end
        end,
    },
    
    -- Utility
    kick = { --脚踢
        id = 1766,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        interrupt = true,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,
    },
    
    evasion = { --闪避
        id = 5277,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        startsCombat = false,
        toggle = "defensives",
        
        handler = function()
            applyBuff("evasion")
        end,
    },
    
    feint = { --佯攻
        id = 1966,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("feint")
        end,
    },
    
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("sprint")
        end,
    },
    
    -- Baseline Abilities (not talents)
    vendetta = { --仇杀
        id = 79140,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        
        handler = function()
            applyDebuff("target", "vendetta")
        end,
    },
    
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        talent = "shadowstep",
        
        startsCombat = false,
        
        handler = function()
            setDistance(5)
        end,
    },
    
    -- Poison Application Abilities
    deadly_poison = { --致命药膏
        id = 2823,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        usable = function() return not buff.deadly_poison.up, "deadly poison already applied" end,
        
        handler = function()
            applyBuff("deadly_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    instant_poison = { --致伤药膏
        id = 8679,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        usable = function() return not buff.instant_poison.up, "instant poison already applied" end,
        
        handler = function()
            applyBuff("instant_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    wound_poison = {
        id = 8679,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        usable = function() return not buff.wound_poison.up, "wound poison already applied" end,
        
        handler = function()
            applyBuff("wound_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    crippling_poison = {
        id = 3408,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        usable = function() return not buff.crippling_poison.up, "crippling poison already applied" end,
        
        handler = function()
            applyBuff("crippling_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    mind_numbing_poison = {
        id = 5761,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        startsCombat = false,
        
        usable = function() return not buff.mind_numbing_poison.up, "mind numbing poison already applied" end,
        
        handler = function()
            applyBuff("mind_numbing_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    leeching_poison = {
        id = 108211,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        talent = "leeching_poison",
        startsCombat = false,
        
        usable = function() return not buff.leeching_poison.up, "leeching poison already applied" end,
        
        handler = function()
            applyBuff("leeching_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    paralytic_poison = {
        id = 108215,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        talent = "paralytic_poison",
        startsCombat = false,
        
        usable = function() return not buff.paralytic_poison.up, "paralytic poison already applied" end,
        
        handler = function()
            applyBuff("paralytic_poison", 3600) -- Apply to weapon for 1 hour
        end,
    },
    
    -- Jade Serpent Potion
    jade_serpent_potion = {
        id = 76089,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        
        usable = function() return not incombat and not buff.jade_serpent_potion.up end,
        
        handler = function()
            applyBuff("jade_serpent_potion", 25)
        end,
    },
    
    -- Tricks of the Trade
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("tricks_of_the_trade")
        end,
    },
    
    -- Apply Poison (generic poison application)
    apply_poison = {
        id = 2823, -- Deadly Poison spell ID (updated for MoP)
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function()
            -- Check if deadly poison is missing (for SimC lethal=deadly,nonlethal=crippling)
            return not buff.deadly_poison.up, "deadly poison already applied"
        end,
        
        handler = function()
            -- Apply deadly poison as lethal and crippling poison as nonlethal
            -- This matches the SimC priority: apply_poison,lethal=deadly,nonlethal=crippling
            applyBuff("deadly_poison", 3600)
            applyBuff("crippling_poison", 3600)
        end,
    },
    
    -- Shiv - applies poison and removes buff
    shiv = {
        id = 5938,
        cast = 0,
        cooldown = 9, -- MoP: 9 second cooldown
        gcd = "spell",
        school = "physical",
        
        spend = 40, -- 40 energy cost
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            -- Shiv automatically applies your active poison
            local poison_applied = false
            
            if buff.deadly_poison.up then
                applyDebuff("target", "deadly_poison_dot", 12, min(5, (debuff.deadly_poison_dot.stack or 0) + 1))
                poison_applied = true
            end
            
            if buff.instant_poison.up then
                applyDebuff("target", "instant_poison_debuff", 8)
                poison_applied = true
            end
            
            if buff.wound_poison.up then
                applyDebuff("target", "wound_poison_debuff", 15, min(5, (debuff.wound_poison_debuff.stack or 0) + 1))
                poison_applied = true
            end
            
            if buff.crippling_poison.up then
                applyDebuff("target", "crippling_poison_debuff", 12)
                poison_applied = true
            end
            
            if buff.mind_numbing_poison.up then
                applyDebuff("target", "mind_numbing_poison_debuff", 16, min(5, (debuff.mind_numbing_poison_debuff.stack or 0) + 1))
                poison_applied = true
            end
            
            if buff.leeching_poison.up then
                applyDebuff("target", "leeching_poison_debuff", 8)
                poison_applied = true
            end
            
            if buff.paralytic_poison.up then
                -- Paralytic poison has a chance to stun
                if math.random() <= 0.25 then -- 25% chance to stun
                    applyDebuff("target", "paralytic_poison_debuff", 4)
                end
            end
            
            -- Shiv removes one magic effect from the target
            removeDebuff("target", "magic")
        end,
    },
    
    -- Crimson Tempest - AoE finisher
    crimson_tempest = {
        id = 121411, -- MoP Crimson Tempest spell ID
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        spend = function() 
            local cost = 35 -- Base energy cost
            
            -- Shadow Focus reduces cost while stealthed
            if talent.shadow_focus.enabled and (buff.stealth.up or buff.vanish.up) then
                cost = cost * 0.25
            end
            
            return cost
        end,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current and combo_points.current > 0, "requires combo points" end,
        
        handler = function()
            local cp = combo_points.current or 0
            -- Crimson Tempest duration: 2s base + 2s per combo point
            applyDebuff("target", "crimson_tempest", 2 + (2 * cp))
            spend(cp, "combo_points")
        end,
    },
    
    -- Shadow Blades - Major DPS cooldown
    shadow_blades = { --暗影之刃
        id = 121471, -- MoP Shadow Blades spell ID
        cast = 0,
        cooldown = 180, -- 3 minute cooldown
        gcd = "off",
        school = "shadow",
        
        startsCombat = false,
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("shadow_blades", 12) -- 12 second duration
        end,
    },
    
    -- Cloak of Shadows - Defensive cooldown
    cloak_of_shadows = { --暗影斗篷
        id = 31224,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        toggle = "defensives",
        
        handler = function()
            applyBuff("cloak_of_shadows", 5)
            -- Removes all magical debuffs
            removeDebuff("player", "magic")
        end,
    },
    
    -- Marked for Death - Combo point generator
    marked_for_death = { --死亡标记
        id = 137619,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",

        startsCombat = false,
        handler = function()
            gain(5, "combo_points")
        end,
    },

    -- Disarm the enemy's weapon for 18 sec.
    dismantle = { --拆卸
        id = 51722,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "dismantle")
        end,
    },
    
    preparation = { --伺机待发
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        handler = function()
            setCooldown("vanish", 0) --消失
            setCooldown("sprint", 0) --疾跑
            setCooldown("evasion", 0) --闪避
            setCooldown("dismantle", 0) --拆卸
        end,
    },
})

-- Duplicate behind_target removed - using the intelligent one above

spec:RegisterStateExpr("poisoned", function()
    return debuff.deadly_poison_dot.up or debuff.wound_poison.up
end)

-- Proper stealthed state expressions for MoP compatibility
spec:RegisterStateExpr("stealthed_rogue", function() return buff.stealth.up end)
spec:RegisterStateExpr("stealthed_mantle", function() return false end) -- Not available in MoP
spec:RegisterStateExpr("stealthed_all", function() return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up end)

-- Add anticipation_charges for compatibility (not used in MoP but referenced in imported rotations)
spec:RegisterStateExpr("anticipation_charges", function()
    return buff.anticipation.stack or 0 -- Return anticipation buff stacks
end)

-- Hooks
spec:RegisterHook("reset_precast", function()
    -- Reset any necessary state
end)

-- Options
spec:RegisterOptions({
    enabled = true,
    aoe = 2,
    cycle = false,
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 8,
    potion = "virmen_bite_potion",
    package = "刺杀(黑科研)"
})

spec:RegisterPack("刺杀(黑科研)", 20251116, [[Hekili:1EvZUoonu4NLzdxytvs)J5IgMfWgMRqZMCzfIK4MCAJvDSd2oZOknYAwYkKgj2HqcjwGepcWZdm6(wWX2nTjTjP3osZM2e7t((o)8Doojom((4OCIgIF50GPlcddxozAWSBNgghP3vbXrvKSTKn4fCsj(7)(t)9)9BV9tF4FE37)Z39(F)x(mRf7ycsUfjLOwMHwfhTQMY0VGhV6e4NJgvbz49lUnoQGMNdEJavwC0by)(h(JF(HF9V(H4igvPvoVewtQzA8Yxg28Jooc4Kvmip(RIJYKuniPe0wXR5XrKmnvWTpjjNTlPsqv4TAKBlE9(GRQxVEYkMqKZQv6jsaXWK(M3ys1e5gqprtlHeTijNcM0NzsNhCKNkH7FKGzwcAwElnBBB6W9N32bw1XZbNl8kGNdAnzsD1O0pTf9feEUctVmHU5gKQfFmOslP8TGoSHTd3JeU8JiHtpHWPwc)8bRMNt4reDf5K11YDwmE6hggGubYTu(glg3oigahKB25cQLTckImJWTHSucCTfIWGXvMT1Jy2YK(8UiQkiO0pzfJG9t(MkjTYV39Hl)gt6xlemB3HjTKWX(6YgMdhNzfJMbjOOclpzGR09jM0Cb2JuxPRLaw(YCzIdottkZb)fA5uAGW0fDYUL1AkZo7OBCe5n1KkQS5vh6ZU0aH(IbjusOCLxR5cNmr5kHDobxJl)8VexVvUTZt7OD(jbvJPYAEI)6e74R2oID5xbjONxsH9KmZpLlXpHLi8GVyaWZim2qOFEaSOd2RPCQQyFsB5JMGwiSXMZjOKn2kBIQKGLtYJBSC7m(YGGlnH(K5QDhHoBqb1tmPdQP2V2zZG7aGMWWUIjLe5wahriKjO)Ha1y8rf6jwC282pmyptPP9QI9z3(r)8s)CNMUpbNFNN47FrikXSEIgkRaL(8(4tmy8dq76gpZjaBaAnHNiwNSLJoKA8AyVc5gCaooAru6tmhfKxr6bXly8Y4Pr4bLkvvr0zfJ7(7prRWlaRSZSDn6l6z6Mlko0yoAqylnQeFxKl5oZvi778tlDpT9ej3q6XRDxCi5yddpnz0xXsBpuqQSR369bFnrYrbhEE19fONtlResmHHLdt6n7FRVBmPs4hRPsi3KQe2J(i1ArjMaXfYW32zdOMyU7BPCCRWGVWK(DCvDLfkRfEVbXR5qPBoAC4Gg3uJSgBURhVd7kVopB(GCTppnivh05xhHthKWgL8XmXSRW2HdKlM0A06xxG8OYCEtx8ym1C3lkB2FXrtCFUbUT9OnXAkZ9XmOBvGdyI8FuItih))d]])
-- Pack (rotation logic would go here)
spec:RegisterPack("刺杀Simc", 20251116, [[Hekili:9IvBVTnos4FlbfW1gxoF(nL2UNTbA71B7gS7II19UpAlgjABcljQJIkDdqG(TFZqQ3fPSDUG7dnnrC4ZmC4mpZWz70TFF7gFIKU93NnzMZ0PtVB8S5ZMp5DB3iFkMUDtmX7e5a8lrKq4NKKeq6ejUWtbCIpcqcpv4blUDZdPSa5VeT9bZO6aYgt9Gp78HTBoY89PAzPjEB389JSKmx8FKm3C9M5Y3d)TNKXJYCdyjsy59CrM7xPNybSXB3O(O6Cq3tsdKWV(7QZfnI8qa1F7N2UXtWKubJGw4(9JFiGZ9dstKJfua7m3NFoZvsehOYXswiDNKVZNbkFzM7IjWPwPF4mZv)VeoaOck(8jM3P6QdwFEldOq0JKi)Ko2tsaZJUdwc0QhDCACM7Gm3HzU(C54deHGlPGH5DIfDqBS4cI0yzQO1ck8EKg5tLsIcPrGtpGll0nyClSyCsbl6evoTJ91aVE8vZNuORsOa150V6M96PUzO6UR)7(AGxzkQaID7tfpHi8UxccurcvG3dicV3kc0iQ4WtkZ)UArweHhjcpCcbnsIq8blETKJeF(p29qabYA0PocwSETVp9UVM5(zopaebYxcjrqouiGyM73e09ubMyXeQOLnkGYC)KcPm3FWKhZC)35hoiXdeoIsGFs)tQxQKEBMBIKfea5Jbb4oXuYp9RAjj7Li63njzC9J7W8isdr4wdJhve9BoyyO14bV8dE1Ee0qclkrby(MosjbYJJJX0EmgYrPWrOlF6K(V4V8dr11vHPOW)m0snoQdWZt4d8DXCweY6bgRJ6ZncHuF5MCF1dbmifN5xsHCWZVYhSkZTwe3JKiwYrLznZsOwykCDJ04nJY2ivUq4EpgnLUUj96y6bIEBQWkPr98iDhasidJaxdw48k1lsJ2P)9DihVMPFxEDiovbEBQSkWB68qODQG2dIGTI9Eg6zGdgQaBKx9IWb0VqGK5TyQ8MybfTgIXst6YSjXysjKvZts4HTZR)d(Hu6pL5(rO6BsclIOlho834FdowJDgpfcHHCrsc1xNwUHf(5m3VZWCYP3HvlfCMhK9l47zb0oLWYRS1FrSkNBraxTR6kck93mvOPcajjayLghseNOaXlxSZNsaGkeUkgSLeMkO8cGTzQS(AcJPmCbzzlMyE)i)lNJ0OmBeYENzilhduNvE9CHr2luazkDArb)assbqeMaXRsAym0dxxYQwc0Fmqx2PkG2tI2X3V7ueyqgB54cZtPraNipuF)uLv1ZTuN4ft3t)CbsjxrWJHllKrv95E6IZyjUAC2nzlTFRJf7uU5P1Vs70Cy1swljLVN(VDTvTScgFwsmr6DMe92wsYoDgqTeGI6zRZC)WeZ4BpJVvDpv)8MXWEFHTIKXQq1A1qfuqIaJNfRiE7jGyPoLBu521xX1BzZsX98nAO4BVnKEt9UEuv0rxG)t2cXQi8f0yIqDE0zxLv9(FJc8FMdZzFKZRar4vNduVpWgnpIk79wmIP17irbx)zo11B1HCvXPCObseNY4LBU2iU1LrCJ6)0z8uy7LGXqmfKOw8W(g3ZFdwdEjqa7WrzaeO9afOkbT8fnxnycCOw0JCMp(EbI4rLJxEKIpN4pbEKF(Z)Jm30OaAcy))H2yW1O(WFdVsb07XXNPeHLgHn67bELf9tIytb2HZqfQlMGzDzSW5YlMBup2zdS1zG5Zr5YkZixbn0)0Ii2skA01mPiw7M(43S(MKlie3qXN1nl(uVXaG86hereeMLGdrcILyHXCHmFqrVnFUqVfdU(pPmbQeOjBqosQKhcCSWh8osIoawF29)klcwA6eOF7)vusAmcfkHw1aEfpt7TvcpZQWf04OWz3BW6GUoVolBHvDL7uSQQYgOUofo3QclkV(2lW46kRZvi7DVChCrHTR7qB34Q5LpNT1r03DjIQod754mwuuNKubbYh)bfPjtvpXd7FsXOwSF8XNycNSqUiUYbKg1qAFFuyFIK8a8wXFc8yU)vm7wZCd(VFjSWYCAn2vWWG0Vu5rO)7nq3j7fStyBe63tU5nav(f9k17FZ18qv0MEZButVs)eAaELvLKDV28sgx(86)YQ)2(asYPBX3uVQ1tQnlV(DVMxlVTPBz7xDtR(OmVH2VCa355EuHzn3OKWfbJ2n9BQoRB7HkpNisMga(Zp3TTHLlMuhaCg31)BioChu2j8wCaSRuJwUe9opeAWqd9P98Zg6q75NBpjSr21AXqMlvCTTz8inFYzbB2leSQjiBcGgswoP4ZjzZHcJsRRdVe62btJ6zCV3)MxJj((3VWj(w3OB0maAZdnhty86F0GHD99dn48ToQ3bD6Dy5CNrncIk2I94vJ2wdiup1Y093G69GT0zq5n2GB60o0GAJNDL(kT1SvRRZIcDvMDx6iqSwtn9wCIKRGMmWTHFVAcrRxnV(gBprt9olQEIBV(rB9kNZV5Ygou8tfbSFK)LkApWYms41tRXlNnOPLmRnCTMJvxBFXG2UIfdUPNrK1wbnMVvB4x60w88cSg9H1CmvJLQcGsx4lR(sdp1QjdSWpBiCFG9AE1TPCsDLPa5NlNQ9JT461F0wcvdal69tF46MlF(DzBKtqCJoBC9hMCEumnyjlxl1smBehSAUI8Y6BDAYvSAXiqCJpOQJGMnKAZ0r10IXjdz4ETwiy54BQ0qbdWRzAAnmZVPug8Lg5mOBfH1REFl1n9CQZWRIxUA2GHnszCG7KBU07qGgz0iZgNUI8)xgDIXZDJj6yGiQwHkd(L1lmcQDETxdqMzKTQ4MA(1b2cJwe8ztd)ayXgMtvSYzYOIuM2zLgQO3BOsh6S1ZDuZVy7)9p]])
