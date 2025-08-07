-- MonkWindwalker.lua July 2025
-- Adapted from MonkBrewmaster.lua by Smufrik, Tacodilla, Uilyam

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format


-- Enhanced MoP Specialization Detection for Monks
function Hekili:GetMoPSpecialization()
    -- Prioritize the most defining abilities for each spec

    -- Windwalker check
    if IsPlayerSpell(113656) or IsPlayerSpell(107428) then -- Fists of Fury or Rising Sun Kick
        return 269
    end

    -- Brewmaster check
    if IsPlayerSpell(121253) or IsPlayerSpell(115295) then -- Keg Smash or Guard
        return 268
    end

    -- Mistweaver check (currently not implemented, but placeholder for completeness)
    -- if IsPlayerSpell(115175) or IsPlayerSpell(115151) then -- Soothing Mist or Renewing Mist
    --     return 270
    -- end

    return nil -- Return nil if no specific spec is detected, to allow fallbacks
end

-- Define FindUnitBuffByID and FindUnitDebuffByID from the namespace
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Create frame for deferred loading and combat log events
local wwCombatLogFrame = CreateFrame("Frame")

-- Define Windwalker specialization registration
local function RegisterWindwalkerSpec()
    -- Create the Windwalker spec (269 is Windwalker in MoP)
    local spec = Hekili:NewSpecialization(269, true)

    spec.name = "Windwalker"
    spec.role = "DPS"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end



    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        base_energy_regen = {
            last = function ()
                return state.query_time
            end,
            interval = 1,
            value = function()
                local base = 10 -- Base energy regen (10 energy per second)
                local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
                return base * haste_bonus
            end,
        },
        energizing_brew = {
            aura = "energizing_brew",
            last = function ()
                local app = state.buff.energizing_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                return state.buff.energizing_brew.up and 20 or 0 -- Additional 20 energy per second
            end,
        },
    }, {
        max = function() return 100 end,
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end,
        regen = function()
            return state:CombinedResourceRegen( state.energy )
        end,
    })

    -- Talents for MoP Windwalker Monk
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

    -- Auras for Windwalker Monk
    spec:RegisterAuras({
        tigereye_brew = {
            id = 1247279,
            duration = 120,
            max_stack = 20,
            emulated = true,
        },
        tigereye_brew_use = {
            id = 1247275,
            duration = 15,
            max_stack = 1,
            emulated = true,
        },
        touch_of_karma = {
            id = 122470,
            duration = 10,
            max_stack = 1,
            emulated = true,

        },
        tiger_power = {
            id = 125359,
            duration = 20,
            max_stack = 1,
            emulated = true,

        },
        power_strikes = {
            id = 129914,
            duration = 1,
            max_stack = 1,
            emulated = true,

        },
        combo_breaker_tp = {
            id = 116768,
            duration = 15,
            max_stack = 1,
            emulated = true,

        },
        combo_breaker_bok = {
            id = 116767,
            duration = 15,
            max_stack = 1,
            emulated = true,

        },
        energizing_brew = {
            id = 115288,
            duration = 6,
            max_stack = 1,
            emulated = true,

        },
        rising_sun_kick = {
            id = 130320,
            duration = 15,
            max_stack = 1,
            emulated = true,
        },
        zen_sphere = {
            id = 124081,
            duration = 16,
            max_stack = 1,
            emulated = true,
        },
        rushing_jade_wind = {
            id = 116847,
            duration = 6,
            max_stack = 1,
            emulated = true,
        },
        dampen_harm = {
            id = 122278,
            duration = 10,
            max_stack = 1,
            emulated = true,
        },
        diffuse_magic = {
            id = 122783,
            duration = 6,
            max_stack = 1,
            emulated = true,
        },
        legacy_of_the_emperor = {
            id = 117666,
            duration = 3600,
            max_stack = 1
        },
        legacy_of_the_white_tiger = {
            id = 116781,
            duration = 3600,
            max_stack = 1
        },
        death_note = {
            id = 121125,
            duration = 3600,
            max_stack = 1
        }
    })

    -- Abilities for Windwalker Monk
    spec:RegisterAbilities({
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,

            handler = function()
                applyBuff("legacy_of_the_emperor", 3600)
            end
        },
        legacy_of_the_white_tiger = {
            id = 116781,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,

            handler = function()
                applyBuff("legacy_of_the_white_tiger", 3600)
            end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            handler = function()
                gain(1, "chi")
            end
        },
        tigereye_brew = {
            id = 1247275,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            startsCombat = false,

            toggle = "cooldowns",

            handler = function()
                removeBuff("tigereye_brew")
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            startsCombat = true,

            spend = 3,
            spendType = "chi",

            toggle = "cooldowns",

            handler = function()
                removeBuff("death_note")
            end
        },
        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            handler = function()
                local chi_gain = talent.power_strikes.enabled and buff.power_strikes.up and 3 or 2
                gain(chi_gain, "chi")

                if talent.power_strikes.enabled and buff.power_strikes.up then
                    removeBuff("power_strikes")
                end
            end
        },
       tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = function() return state.buff.combo_breaker_tp.up and 0 or 1 end,
            spendType = "chi",

            handler = function()
                applyBuff("tiger_power", 20)
                removeBuff("combo_breaker_tp")
            end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = function() return state.buff.combo_breaker_bok.up and 0 or 2 end,
            spendType = "chi",

            handler = function()
                removeBuff("combo_breaker_bok")
            end
        },
        rising_sun_kick = {
            id = 107428,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            startsCombat = true,

            spend = 2,
            spendType = "chi",

            handler = function()
                applyDebuff("target", "rising_sun_kick", 15)
            end
        },
        fists_of_fury = {
            id = 113656,
            cast = 0,
            cooldown = 25,
            gcd = "spell",
            startsCombat = true,

            spend = 3,
            spendType = "chi",

            handler = function() end
        },
        spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = 2,
            spendType = "chi",

            handler = function() end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,

            handler = function()
                applyBuff("energizing_brew", 6)
            end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            charges = 2,
            startsCombat = false,

            gcd = "off",
            talent = "chi_brew",

            handler = function() end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            talent = "rushing_jade_wind",

            handler = function()
                -- Gain chi if hits three or more enemies
                local chi_gain = active_enemies >= 3 and 1 or 0
                if chi_gain > 0 then
                    gain(chi_gain, "chi")
                end
                applyBuff("rushing_jade_wind", 6)
            end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            startsCombat = true,

            talent = "zen_sphere",

            handler = function()
                applyBuff("zen_sphere", 16)
            end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            startsCombat = true,

            talent = "chi_wave",

            handler = function() end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            startsCombat = true,

            spend = 2,
            spendType = "chi",

            talent = "chi_burst",

            handler = function()
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            startsCombat = true,

            talent = "invoke_xuen",
            toggle = "cooldowns",

            handler = function() end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            startsCombat = false,

            talent = "dampen_harm",
            toggle = "defensives",

            handler = function()
                applyBuff("dampen_harm", 10)
            end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            startsCombat = false,

            talent = "diffuse_magic",
            toggle = "defensives",

            handler = function()
                applyBuff("diffuse_magic", 6)
            end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            startsCombat = true,

            toggle = "interrupts",

            handler = function() end
        }
    })

    spec:RegisterStateExpr("time_to_max_energy", function()
        if state.energy.active_regen and state.energy.active_regen > 0 then
            local deficit = state.energy.max - state.energy.current
            if deficit <= 0 then
                return 0
            end
            return deficit / state.energy.active_regen
        end
        return 3600 -- Large number indicating it will never be reached
    end)

    -- Temporary expression to fix a warning about missing threat value
    -- Should probably remove this
    spec:RegisterStateExpr("threat", function()
        return {
            situation = threat_situation or 0,
            percentage = threat_percent or 0
        }
    end)

    -- Consolidated event handler
    wwCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")
    wwCombatLogFrame:RegisterEvent("ADDON_LOADED")

    wwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_POWER_UPDATE" then
            local unit, powerTypeString = ...
            if unit == "player" and state.spec.id == 269 then
                if powerTypeString == "CHI" then
                    local currentChi = UnitPower(unit, 12)
                    if state.chi.current ~= currentChi then
                        state.chi.current = currentChi
                        state.chi.actual = currentChi
                        Hekili:ForceUpdate(event)
                    end
                elseif powerTypeString == "ENERGY" then
                    local currentEnergy = UnitPower(unit, 3)
                    if state.energy.current ~= currentEnergy then
                        state.energy.current = currentEnergy
                        state.energy.actual = currentEnergy
                        Hekili:ForceUpdate(event)
                    end
                end
            end
        elseif event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "Hekili" or TryRegister() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end
    end)

    -- Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 3,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 8,
        package = "Windwalker"
    })

    spec:RegisterSetting("use_energizing_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(115288)), -- Energizing Brew
        desc = "If checked, Energizing Brew will be recommended when energy is low.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("energizing_brew_energy", 40, {
        name = "Energizing Brew Energy Threshold (%)",
        desc = "Energizing Brew will be recommended when your energy drops below this percentage.",
        type = "range", min = 10, max = 80, step = 5,
        width = "full"
    })

    spec:RegisterSetting("chi_brew_chi", 2, {
        name = "Chi Brew Chi Threshold",
        desc = "Chi Brew will be recommended when you have fewer than this many Chi.",
        type = "range", min = 0, max = 4, step = 1,
        width = "full"
    })

    spec:RegisterSetting("defensive_health_threshold", 60, {
        name = "Defensive Health Threshold (%)",
        desc = "Defensive abilities (Dampen Harm, Diffuse Magic) will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 90, step = 5,
        width = "full"
    })

    spec:RegisterPack("Windwalker", 20250806, [[Hekili:TM1EVTTnq8plbdWijTrtYpsBhIcqxxbwl2kgGcW(pjrlrzZAzrbkQK6Ia9zFhPEr9GYQPRfDZMK37J)U7ODTCFW1jeXXUFzP5YnMV18ngMMwWhCD4NsXUoPOGdODWhsqhH)7)sscFcfFaZeBDkMIcfSiJMZcGTDih)adfXl83S(T3amzBojM)Pe3TJjMvwwUoOC(EkWT)KCeJCD2tcdXLNhNf468WEswHV4FOc)kLPWNgbFpGtOjf(XKmoSDeLv4)N4dKyIbOBmAejg0OFPW)VPjh(Tc)wvV4ZWQ9u1Ipl(lSU94)rU3)WW38b6XTiGkhmppDAkk1WmJugoqs1RS)1y8ouWjpAKhFp2dFmfZOSxtIS3MhfzKXr8mJq6tjlKFF0tl3FoC)P9eo2Jt2HBLqaJW1kafcMqiPuPJ)8UR)ahHtYipIHWZFbrP55TcBOcKvicS5eV9i2rHjWrX4eq)Bx1aNG2gJdxCH0E408G9cZ5aShYipDXEmkMV3inGFN9TM6edjkkpd7DeTJeOki11)Hf1zDqFGYWZYP041BIJBJP0W48mUbddh65N5i2om3GdxJ84uVqcUJ9cCqyiq89yM6IBXSmm7ajzN6Qb7jEBz4NuCf1l14fGfUZE5Il5msYbqYWvUadWpft4NQvQld2luRmBRfqcK8ZEcn8oBlZRE(56DxoQ6xT71Wrv1nz6Pxkk(yJZOAj6tqEldFersYUZELqdV32AaT4t4gJRL86v9a3KYfKo7jUFgCWEP5lMNsvcCA64nOVBg1zS28QfHyjzmsgeU8YYt8oqcoiY8g4feqtTQiobZ2r(UGQMOAfVpI(MNC7t3VrLKEcrqIgXRyx)aHjjvA4yvi8ERfJOLwJewjjpspG9(woorjJvz16K2owiiUYV5jkH8ArboBefl4Gy9hXcrEKGZU3E1zjuybXGUkJCdzXDRMbCGJKh38GKhf(x68WvZcDWOJWf((AOPqmIVVX)l)MxcLJf5ms34k9mzKmGEr5bKejkflKBuo7uJy7L9vg6hjYUEyACDMW6ZQTc4PNqpI7HyjwQbXAezoHXib8Yzz8(GGI1EH887qvRS09WT(xhCkOzhaFuriThAsPS4IqANdZHOKko(aPVngqyO58M4zzhbqDDQiYGGwJ82spucE3)k9WKSHxW7YkEAfNUu3Mvi1c4)HgO9YR6FvFGo8v02Q8sdGYBoNkpWbukQxv()mQUYYW7WjxhqPXImvTOt2RnB8rN9Q97bZ(gA0nFmkchiUB)E6hN5LBassc6KTxOgFffc9PbTYQKWmyVbWDvm5LM(D2mTs2pJ7GJrYzVKnWxmkYuDwq)tNLssseNpGHsWnuCX5CEUopc9gbmQzOLBDDEcXe8kZ15thtPmoOC(B6nlIrXNDDKFsoAKAoiSWxKZCvlJF31r0roMrqIHL6dsx4VOWhSRc)7Tl8xbtljfemCwhe(YHLyK0Yn1LsnAbgDjGUCWU1QQn60YwDQxyrWGvtBRJvzqAYdHdaPv4VwUPUQekhzmxwNItcLBTwLtxY7eQMIFOMmHm2mhz0nzF(crsNqk3EoPm8o9KIrU5ff(JFTVvjA3dKPkGIilh0R3mD4xtLNUrqfBUd8TG)V9hH)1LJKS)YQ0iDfLk8VZw6iE(znUPYTVQRYAPCdTP8OqtF3u3KKOw(3mUrdL4emWYulhQvPxv4psHSc)RbgFMIzLsDT5SD9CbKtekpEoqA9MvTYPoygNsF(TMTsTCM35IUjNM(SWz18UzAyvnVgYQXSBMoU3PMf2H64YTE2QeRYKq9dpx6LUuqKCmyWYG8ljDDgLUKHwMYCrbjQNF5e(ALtEDfd6bVaQ)0yy6rIf60QzE3qp61ets3Rsq3POlTDZEcS(mZazAcz2E7OdqYOAH0S3mzmyTzniI2P7hVOxE6eMNEGrnq(BAzwVIYtJEnXBcOflzK(eMaDB0xoykhMA3awtvMZAM5Nw6H30)sdTmtztj363uvJBP7ZkOkMk88Q3sOPZgXX8kFxEOvxjZ73W1lG531N3D7GvI938CWZa9V9nTBtK1)U2TQ8ONPxTGHpT)G31x7awJ8A(NT4Xe9Au)U66mY(VTUodv5CdkhvxpuTueVm4pzC48J60MN07iZT474d4(YCOt306)d9LQFSenD(pEZ9ZRja1M710)U(kSs0jBjkLOlXjbr1xh9cr5N5McmY8Ynn8v9lMmRSTr(rAQJFLy69)9tK72(BOmSDqfoo30Yb)eu)uzKJ(Zb9ZAuQ80TcFnlfha6ZTVt(v3)7]])

end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterWindwalkerSpec()
        wwCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

-- Attempt immediate registration or wait for ADDON_LOADED
TryRegister()
