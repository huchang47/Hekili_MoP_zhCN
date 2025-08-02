-- MonkBrewmaster.lua July 2025
-- by Smufrik, Tacodilla , Uilyam

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Define FindUnitBuffByID and FindUnitDebuffByID from the namespace
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Create frame for deferred loading and combat log events
local bmCombatLogFrame = CreateFrame("Frame")

-- Define Brewmaster specialization registration
local function RegisterBrewmasterSpec()
    -- Create the Brewmaster spec (268 is Brewmaster in MoP)
    local spec = Hekili:NewSpecialization(268, true)

    spec.name = "Brewmaster"
    spec.role = "TANK"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end

    -- Force Chi initialization with fallback
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)

        state.chi = state.chi or {}
        state.chi.current = chi
        state.chi.max = maxChi

        return chi, maxChi
    end

    UpdateChi() -- Initial Chi sync

    -- Ensure Chi stays in sync, but not so often it overwrites prediction.
    for _, fn in pairs({ "resetState", "refreshResources" }) do
        spec:RegisterStateFunction(fn, UpdateChi)
    end

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        -- No special energy regeneration mechanics for Brewmaster in MoP
    }, {
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
    })

    -- Talents for MoP Brewmaster Monk
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 },
        tigers_lust = { 1, 2, 116841 },
        momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 },
        zen_sphere = { 2, 2, 124081 },
        chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 },
        ascension = { 3, 2, 115396 },
        chi_brew = { 3, 3, 115399 },
        deadly_reach = { 4, 1, 115176 },
        charging_ox_wave = { 4, 2, 119392 },
        leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 },
        dampen_harm = { 5, 2, 122278 },
        diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 },
        invoke_xuen = { 6, 2, 123904 },
        chi_torpedo = { 6, 3, 115008 }
    })

    -- Auras for Brewmaster Monk
    spec:RegisterAuras({
        tiger_power = { 
            id = 125359, -- This is the Spell ID for the Tiger Power buff
            duration = 20, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 125359)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew_stacks = {
            id = 128939, -- This is the Spell ID for the stacks buff itself
            duration = 30,
            max_stack = 15,
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128939)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        legacy_of_the_emperor = { 
            id = 115921, 
            duration = 3600, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115921)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        shuffle = { 
            id = 115307, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115307)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew = { 
            id = 115308, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115308)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        fortifying_brew = { 
            id = 120954, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 120954)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        guard = { 
            id = 115295, 
            duration = 30, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115295)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        dampen_harm = { 
            id = 122278, 
            duration = 10, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122278)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        diffuse_magic = { 
            id = 122783, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122783)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        breath_of_fire_dot = { 
            id = 123725, 
            duration = 8, 
            tick_time = 2, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 123725)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        heavy_stagger = { 
            id = 124273, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124273)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        moderate_stagger = { 
            id = 124274, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124274)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        light_stagger = { 
            id = 124275, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124275)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        zen_sphere = { 
            id = 124081, 
            duration = 16, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124081)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        rushing_jade_wind = { 
            id = 116847, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116847)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        }
    })

    -- State Expressions

    spec:RegisterStateExpr("elusive_brew_stacks", function()
        -- This now points directly to the stack count of our new aura
        return state.buff.elusive_brew_stacks.count
    end)

    spec:RegisterStateExpr("stagger_level", function()
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then
            return 3 -- Heavy
        elseif state.buff.moderate_stagger and state.buff.moderate_stagger.up then
            return 2 -- Moderate
        elseif state.buff.light_stagger and state.buff.light_stagger.up then
            return 1 -- Light
        end
        return 0 -- None
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
        auto_attack = {
            id  = 6603,
            cast     = 0,
            cooldown = 0,
            gcd      = "spell",
            handler  = function()
        end,
     },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            toggle = "interrupts",
            startsCombat = true,
            handler = function() end
        },
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            toggle = "buffs",
            startsCombat = false,
            handler = function() applyBuff("legacy_of_the_emperor", 3600) end,
            generate = function(t) end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            talent = "chi_burst",
            startsCombat = true,
            handler = function() spend(2, "chi") end,
            generate = function(t) end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            startsCombat = true,
            handler = function() applyBuff("zen_sphere", 16) end,
            generate = function(t) end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("dampen_harm", 10) end,
            generate = function(t) end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("diffuse_magic", 6) end,
            generate = function(t) end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        elusive_brew = {
            id = 115308,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            startsCombat = false,
            handler = function()
                applyBuff("elusive_brew", 6)
            end,
            generate = function(t) end
        },
        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
                if state.talent.power_strikes.enabled and math.random() <= 0.2 then
                    gain(1, "chi")
                end
            end,
            generate = function(t) end
        },
        keg_smash = {
            id = 121253,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(2, "chi")
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 25,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                applyBuff("tiger_power", 20)
            end,
            generate = function(t) end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyBuff("shuffle", 6)
            end,
            generate = function(t) end
        },
        purifying_brew = {
            id = 119582,
            cast = 0,
            cooldown = 1,
            gcd = "off",
            spend = 1,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                removeDebuff("heavy_stagger")
                removeDebuff("moderate_stagger")
                removeDebuff("light_stagger")
            end,
            generate = function(t) end
        },
        guard = {
            id = 115295,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            spend = 2,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                applyBuff("guard", 30)
            end,
            generate = function(t) end
        },
        breath_of_fire = {
            id = 115181,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            talent = "rushing_jade_wind",
            startsCombat = true,
            handler = function()
                spend(1, "chi")
                applyBuff("rushing_jade_wind", 6)
            end,
            generate = function(t) end
        },
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("fortifying_brew", 15)
            end,
            generate = function(t) end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            charges = 2,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                gain(2, "chi") -- This is the correct function call
            end,
            generate = function(t) end
        },
       spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2, 
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(2, "chi") 
            end,
            generate = function(t) end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
            end,
            generate = function(t) end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,
            handler = function() end,
            generate = function(t) end
        }
    })

bmCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")

bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        local unit, powerTypeString = ...

        -- Only update for the player and if the Brewmaster spec is active
        if unit == "player" and state.spec.id == 268 then
            if powerTypeString == "CHI" then
                local currentChi = UnitPower(unit, 12)
                if state.chi.current ~= currentChi then
                    state.chi.current = currentChi
                    state.chi.actual = currentChi
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            elseif powerTypeString == "ENERGY" then
                local currentEnergy = UnitPower(unit, 3)
                if state.energy.current ~= currentEnergy then
                    state.energy.current = currentEnergy
                    state.energy.actual = currentEnergy
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            end
        end
    end
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
        package = "Brewmaster"
    })

    spec:RegisterSetting("use_purifying_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(119582)), -- Purifying Brew
        desc = "If checked, Purifying Brew will be recommended based on stagger level.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("proactive_shuffle", true, {
        name = "Proactive Shuffle",
        desc = "If checked, Blackout Kick will be recommended to maintain Shuffle proactively.",
        type = "toggle",
        width = "full"
    })
    -- Settings for Defensive Thresholds
    spec:RegisterSetting("purify_level", 2, {
        name = "Purify Stagger At",
        desc = "The stagger level at which Purifying Brew will be recommended.",
        type = "select",
        values = { [1] = "Light", [2] = "Moderate", [3] = "Heavy" },
        width = "full"
    })

    spec:RegisterSetting("guard_health_threshold", 50, {
        name = "Guard Health Threshold (%)",
        desc = "Guard will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 90, step = 5,
        width = "full"
    })

    spec:RegisterSetting("elusive_brew_threshold", 8, {
        name = "Elusive Brew Stacks Threshold",
        desc = "Elusive Brew will be recommended when you have at least this many stacks.",
        type = "range", min = 1, max = 15, step = 1,
        width = "full"
    })

    spec:RegisterSetting("fortify_health_pct", 30, {
        name = "Fortifying Brew Health Threshold (%)",
        desc = "Fortifying Brew will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 50, step = 5,
        width = "full"
    })

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:nV16YTTnw4NfpzQSuJRQU5ljRKNj36M4M2Mzv60FStLiejKiJPi1YlXvz8Wz)7(iS)FFY6tYEoaG3biP1fN2oUUMee4C(oxWhoayw)zFC2udsaD2ppO3GZ7DvVbD7pA459gnBAW2n0zt3q0VLSc(FCiRH)7lmiBcS(mns7LE07wt8dOErAVLERLTvKM7YLw6weB8Z2A7smWU33n0th(0ztxeAzh8oNzlKnMJgCj02nuD4XxC1SPMwgguEBP(6ZM(rtl)in8hsKMqQWre(B9alxNinBl)a41lDtKOUZMYEikg6UEu43)mtLPoKf2uJzVC2u(xdcNn0NUHbZV1s)w(G6zTH)UjY)NiTxbDAKw7PMepQrK27DxzP3jstz7)jILta8tK2uZWLlTHpEb8BqVGFwB57B5ScevplawTiG0t)m1os7A4thoksRvKMUPvx9qppQta)5dyp(eEh11N3TDd3mlaasf6k9p2qTNdc96ck6V6ds0BW3cqi8AUG9Akyx8algOauIFOhn2sOJ(czfyMqye3(5Rfnxipdvip3sxn3hCMmLjo)iDfax4BJ0cCJ0wrDecZRmT4cOT7DGW4awaQJB4kt83uVvBZkz5aUXiGYaoEd7cssirG0J6HY6ifYAG1kQ38ne7IyxQT9JytI0(G7D4VAlmIdh90o5m0G3l8AWwy5vRzVTW(kgDSN7A4Ehmy3FVKx5rxdsIpxrbpKoOgD(HXBWY5tHmVDgG74gime6KnBGooJAysj2bMDbFbDoQhP1VxVYUXWZpps7BbZlXgEqxIp0EFqe6kK2iTNcMfwtoPQwvL98IDiU)FqxcoVMzIwzaqWPOV)c4J4EKmtiLBo3NG42fcIZzfhYn1Ld0fw3lvOFWyn)ocgLw22YSB)g5ZcfJdSuJZyzYbX011gDYoRb2AHrjE0YztI7N03MtZEC9iGU(QZra7Qcawjd2y12R(7Dq5i0SjlPcizpBhCvFP7pM4MQmThZvdhH(9ouz3ibOZXwihmcAh)Ky9vn)TsjpwEH3aKdSSTX)IrsinXCMPr4UlPE8MSm1uBmEj0hh2QvYYUBdVqIdo6eb6taqvYJQ7UEbjqg7KMrd5dXDrKMpnatjOOPPWLFaXrNo3D58at6C)GqpJTZD)dUizqxscT3db6NyEkVqqm79ahSgis6eB758)yosBJtEBoN4jisyS9NP(vrSPYUionKVmQiPM02fmvtou5I60q509ZuVLGVyvSqQrrbQUsMWpvh5e3Md(QRTOXrynS39dKnDQ6(MfB0W(M4stMll(diHbUZjbbemNx6iYCutGQQi27rjbMON(syw6M6bZMM7xeDFfm6zZJ(s2qWxnYpWOcWOnB9LVSLL94TKVq5mMd3Cg6I4TIgGpW50amXNNd0S4zzt5AaTFbX528t0EC8nBPI6X1W0LSxBq5C7fkfWx8lC2hPVlpsZsTxvW6QqINHmAj)D8frA3zsD4tWeZ5qGqCcymkkV61aSb5GD4qoJHcM6XG4az9F8WnMUKOXQwNtvtGZ0rJW1B4AcNHLqHfact7c9p((d8GlmySI4kVqFCUX5FIyqNFNLtrtPYqMx4(gGlWqbFz2kOfjlQAPZV4xEZZJ0(h38B8VB6glhhwW1R8io4YebiLdDdFACiMp4CyALUEWZQMdR0mxmBSaOkPYYP5wUzqGHXwvRp5IJhbyzHFnrFpPHQ8JR2uDAQ(DFwg6nc3J56O3bpERIatznpV3Sc)TLWSzlyZmDiH1epPKcJuutvVw3Jg6xfDKprwuaVUHSifDIZLZIEXP1IxPjpDoMm3jvRtkLdNio(A)qwLfHVPzaDJq5t29qwbmxKQ4bcPbQIjDFfEcDeodJQQ4on0YyZxnxGjb(JrximbgUiSYszERdsdA6R(XMzasxc9OloSU(sxL1JGRVQ6h9Ww3jhTZwst09oJxFTR4unMVBq34CUZfwplUUCzf)OdNHGV0LiQ21t5K7tbvgP8(rbZ4Vhx04ktCQABkR(uT)Z)Z)BqJikW8VrEalXEGHLt)iN0GnVp1z9zzUbmdqrBt(mtx3V7q)AxjLkx0RUSzgQHvrBwvenJvKqr1fOwcN4mmEkKETzPwRuToUrEb5w8Ff(Bu7qSnZHLHCxtD8EDspx3A8EdV35B8vCGSpUQuSyWijw0Bc8IE7h4oomCFzOT9zje4JJ1J9126gIpW5p)3)xSmA2I5Cmz2Uatk(sJvInjAwXTzjR(oNljDz)seMYTkvue(cRCj9z56z(Y(QzTCBc9SwYwxOe0)dXVmg8(oCd6iFEldaxXst2EuVVb3FKSR3jbf5EJvwwtEfz9PbyeVFxyvsZZltk1yHimpBQVQ4k(Gv1FY1qSHvPA7qU2Mu1r0PbdCl4OiWJKVZZQ4MlSJarBjogIi5KAXMfN6OcQgufTW6wH)gpxUP1ERibgpJCI(Y2kxaAGK)rAx27B4i2p46fKhLfvsPb(jdQ2ZFzsxZWQ032UK2pjzpzKHKx2RMDDRWivaLkRIFNipecaY9sOwqkdV0eqmhlebtGt8PCe(oIdUx54UxPBI1kjzQF8rK1UHOIydETELY7ua3u4kDUWvQOpdd16ufJkdY6nuhzBi5RzVjEZibe59eSYY2w4cYWIVXNOGgNEggsVT54tvaYGeWNYkxN0sgXZ8Lknn1xrgkjpAJp9wAHPRA2nCExRVOWFr5CxVkUVRD(TK(pjOko5esbk32IaSjYItQzukDppux9Etlz6w6wvMkxXlGmvGs85NjFxjzMOCR0OaDLbYN)lEkvOfpJzUadg4wHKusoal972)IHd7F1SP3ry1Y1hpVkOF16nGtIi32PyD5pfsIt)xHwSDq33Dn0iSa3RjmLHhl63n6g2NV01guiMjHe6ra9dwLgLxdqUtlJKah)4hagudcIBhNccelNR1ggUm39aYcIp95r3WcLkFOnGxCJeTqS5qnvrEpl4C4Zrxrha4yV2LnuGq7ZfStBNXAmzY5FRk(GpD03EIQ315uE2R8D2U2xDvO(jBx3dda6daWV64hUb7lMFRWODQIDItPaKsg(HjbJQXeKb0UEYGwfsI1szkVwTZLIFYKH3FF(SDJNCzVeJZHAyumkFncDkrxwHLlE3QEy2T(n3UTRroTKvu1RVQLI98PL697rIv(RVmLaLdESGYuh6dnGKPNBCY1dGAD4uJVkrO59k4HNiDbybilTI3R1KJLNilTiSLDEdT0HbWZY5wAaezQfP9Ua(hXMnyn1Xaf6atC3kzSoX(2YfiIGvW2r3o0alXaNIESu9pzmBExaDT)VFgYz1s3mBRzNRM4rvOW0)yJTLUvGDA)Mv)Jh0)gJ5Vyy(iVlGuj)UGVu6JgKzKVZY2oJgj6YG4MYqd2JCcxVGYZEz7gag03ToEATRYBXW0y4rCHbZZM(e1SqV5jsohl3u1hWhh)UjZiprXuPO9UMrotDGQSPIU6Vgvekfcs5e80jzNn6mRLtQUwrxpPFVwfMiTFVEYNxwEDHsqLduDEKRwFF(QyGAwoQe9BvrnpkPo54sC9KHvObh8Y3Cm0V2f5cnQ393xqP7uuRhK1B(OwsgfQmt2kPP7bPqSMms5fk00)cvwffqsbTmjaodAuYwFoyRZBAhgRWpcvmrHIKPUjjkrXAPuHHTOsx2)Ubz1tl(rnj1FYUveKuvpPeoGMxOsnO2NRcjOW3kJh)4j9ZkdnVshYh(4IDGJRI6FKB0huo3oFQHXpljZUsO7jfpPCneOp2NyUuOjErxaYKNfyH8o7kZ4d36uKKnE)pcCsbcz5D3p9pt1oVj1ROHhNn5gRSNvUdKS2m)zP3PRMWkSj3URSXSEuz6zmLKrTkmR4j580q2XzsC9aVZwLeJ0lbuA2AzxJRSd6ECZSkn(jBfEbt94jdBLl751PP(3ZBCvjzi9OCK3o0MbhfV1cc(vsUXcJNmOtLgNQVcv1yBKqwplETBrgkX4D)kqThE6TLLtDmwYVIXaDknZ5UFDMkjW6IRRuHzsZE)MAP8UnnEYH3Um(QZr9TE32XfX0(7Gt8OyWn7DlQERAEBznHQ5V(qnr12RisMSCWVqqnwSZBmhEHCwGkNM5j7YbLQEczh)dmvka5haWZNilqCHptu8zmcmrftcD1LTuFuPWooRcS)N)PDukhDiIZBGPVQJnFtyNCKoa9POgXf99lD8oldIqSqlbqO8WG2QUJMBrZWfhkZqE1rYjdxUcDsTA0XqGLV6d8aIZn61CS1pIABLrUp7OfeLjHWH)WNxeUKMIOrE3N8qDVbaQ9(JqDGorPDPZ1SJim8VvGIn)GI3yWIZyz0f7Rt1OJRt1b88CxeAYZxOmc9quBw1LANW54(7ZZdStJwdSK7VBntXiuiK1CHl45z4v7CIrMnyPU2QNw2U6AACbdqC7GCgsQFiroE13k43Yipu)hcEesDcY8L5UrSWFy66nB6VAzVLSMD(KM9)p]])
end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        bmCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

-- Attempt immediate registration or wait for ADDON_LOADED
if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
