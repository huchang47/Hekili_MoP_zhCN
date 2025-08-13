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
    if IsPlayerSpell(115175) or IsPlayerSpell(115151) then -- Soothing Mist or Renewing Mist
        return 270
    end

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
    -- Use default resource state (with metatable); UnitPowerMax already reflects Ascension.
    spec:RegisterResource(12, {})

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
            cast = function()
                return talent.rushing_jade_wind.enabled and 0 or 3
            end,
            cooldown = function()
                return talent.rushing_jade_wind.enabled and 6 or 0
            end,
            gcd = "spell",
            startsCombat = true,

            channeled = function()
                return talent.rushing_jade_wind.enabled and false or true
            end,

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
        },
        chi_torpedo = {
            id = 115008,
            cooldown = 20,
            charges = 2,

            talent = "chi_torpedo"
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

    spec:RegisterPack("Windwalker", 20250806, [[Hekili:LM1EVTTnq8plfdWijTrt(vw6Gva66kqBXwXaua2)jjAjkBwllkirfxxeOp77i1lkjszLSg02y(4EF)U7ODM78OJDaIHD(2cZfRnVF(cJflnnxm3XMDob7yNG8pG2b)sm6i8V)ljo4ek6aoLV15ikkGtImAEQpSTn54htrHScV1RU)27DS3MtIyFj2z7q2Sy97xT0XgLZ2tbQ9zYrmYXEpjiaxEECMVJ9J7jzfE8)Ik8QeMcpAi8zFgHgx4frYyW2H00cVpJpqIigGSLsdjrGe9lfE)nn(WVx41k6fFfwTNOw8v(pW6wQ)JyV)jfF7hPh3IGBzJz5jJFJsjmZijf7lU1BT(1i8oK)zxAOlBp2fFmbNstFhj0ABEyOrgdXYmcONINj(SYtl2Fku)0Ecd7Yi7WTCWpLW0YaPlmctsOcd)Lnx)joehNrEcdUN)c8stZAf0ClGxbiqNJD3JspYvbgkchdYF7Qg4y02iCqP6WO5(75AZbyluPEUhJIy7ns8zBSUZuhFiHH5zy3JODeFzojV(lNxx0e9rAkEsMLg7EJNCBeLgeLNXmsXWHE(zgkDhMzWGejxg1nGG7OWaf4Ac4HpMjV4wCAgo9ajEN8Q(7jUBtXNKSf1l1ygGf2yTy2vSus8bGZqsNVbyOIiSZ1c1v(75IvM18zqiK43D5s4gR5Mx)8Z17UqP4xT7nWrLLnraQBck6yJXOAj6jiYnfFerIZ2yTKlHpynFWDXNXnkx71Rx1fmtsPiD2JNH6FWAH5RMMcrcmA6OniVRvAmwzE9SaS4APKmWD5MLh7EG4FWipz2aRahCQveXX40DKFYVvJxTI2hr)WvS95hwlFLEmHFfnSxsVEbUjXT0qXkx4dZNPqkNRWTsIFIEa7(JCCSueR0Q1bTD0qGDLFYLxe5D8sCwikMtb(6pH5S8ibN9G1YlErUgebYQWZnKeBwob4aBbnU9rbnk8UY(XRNe6GrhMZT91GtbyeBFJ9x8j3ykdZJzeMXL6jIIiGEE5bxjKxmMZ3W80ZnSTx0xPRxHND1WW46iHvxuA5WtNqpH7HyXxQbXsbphrzeaE5PzS(GG81EL08NqDRSK9qw)78p73SdGpkXK2dnkxM9MaANdZaVKmo(aUVncqyO5Sg)zzpbqLDk3ZGGMJC3spucE3pLEyq2We8UKILurPR0Tzfsnh(FOcAT46(P6dKHVJ2wfxAa382ljYdmaLS6TL)NrvkBkEho(gFknIhPQfDYALzJn6IP2Fau7BPH3(PWqSpp3(d0pnXKBassa6KTNlgFhfaDQbnZkfWmyVbWDve51g(DXiTsYpHCqvx5IjzdSfkrMQJc6F6SesCm)8(POyCZn0A7cizQ56KG9RdEVZ0X(jO3k441J9yENJ9jukxwYCS)YXeAkdyJ36EtZyu8vyMQeSpCX7EVJTyrXCwYmdw4BIb4Qmso)bmnLGmWWBDW)lhMkLKuUPUaoLLF0fE6yZhLaNsq8P86xBPWBwHh4ok8EaO7shgOj9e12R3CUfTkqppmNal1saTfzeIXqKfGBfEReBQRGJ0rKuJgXRtDoUWTsRWPlpyertYouFnopwpfE0nVz6mrCpoxUttivB2VcopeYyuwl28nfEQrva6lJnXJYb563g39RPiwxpOKo3PsaN(3)sOFDLnb5VQkmsx9TcVnwcL(5N1ysk3(6Uc7CP05MkTCj99JLjjaa9UvTsdvl5eyUPwkulsVTWtrnXcVBacFH6ILCDL5Kn9mo(uikpAuiTYXFNkuMyW6jJD1Bw6kp1GzWkDKaWEnCwTS1myTSKxdz1O2ndA37utc7qEY7wlBvGvzqO(5WlvOR4xsmrnyzG4lX96mvEjbNBkIf5xr(8lgXSiDYBQiqp4fq8hhdtpsmxMwoXCJ(OxQO)GHY7vjO7a5L6UzpgwFMjGmncpBZo6aKOukeQ96r9bRmRbr0(qbQl6LNmI6Phyud8(6wI1RO84OxJ88cAXsu0NWiOBkFeIXmyYDdmFSsAZNy858(WBds2v8OfTetAtb103uvfSD1RpmObME9Yw2JPB5J8dD7kiU(gU6t8ntM2D7GvG9382YJH(R8LW7vmy4d9p4v(1oSLI32FYvpAF1(2Sl9VC)49cx2ir9J0RJE9FOED2jPZnOCuD9u5srSsN)i(Hbtln1cYQN)Dk24lnJRkd6)NMwFH9LQplrtN)QBUFAnbi3CVM(31xHvGozjqP4DjokiQ(6OxCS5w6QyW7XRxk3q8DMVAeL2VANXcLL(wKMAq8GVrRxq8RIV0kPIXd)YKeB2(fknO3ZXCok)AREvCR1AjtshwZpo)3]])

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
