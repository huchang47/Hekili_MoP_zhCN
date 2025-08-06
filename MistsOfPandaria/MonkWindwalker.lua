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

    -- Initialize and update Chi
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)

        state.chi = state.chi or {}
        state.chi.current = chi
        state.chi.max = maxChi
        state.chi.actual = chi -- This was the missing line

        return chi, maxChi
    end

    -- Initialize and update Energy
    local function UpdateEnergy()
        local energy = UnitPower("player", 3) or 0
        local maxEnergy = UnitPowerMax("player", 3) or 100

        state.energy = state.energy or {}
        state.energy.current = energy
        state.energy.max = maxEnergy
        state.energy.actual = energy

        return energy, maxEnergy
    end

    UpdateChi() -- Initial Chi sync
    UpdateEnergy() -- Initial Energy sync

    -- Ensure Chi and Energy stay in sync
    for _, fn in pairs({ "resetState", "refreshResources" }) do
        spec:RegisterStateFunction(fn, UpdateChi)
        spec:RegisterStateFunction(fn, UpdateEnergy)
    end

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {}, {
        max = function() return 100 end,
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
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
            id = 116740, -- This is the Spell ID for the Tigereye Brew buff
            duration = 15,
            max_stack = 20,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116740)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        touch_of_karma = {
            id = 122470,
            duration = 10,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122470)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        tiger_power = {
            id = 125359,
            duration = 20,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 125359)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        power_strikes = {
            id = 129914,
            duration = 1,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 129914)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        combo_breaker_tp = {
            id = 116768,
            duration = 15,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116768)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        combo_breaker_bok = {
            id = 116767,
            duration = 15,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116767)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        energizing_brew = {
            id = 115288,
            duration = 6,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115288)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        rising_sun_kick_debuff = {
            id = 130320,
            duration = 15,
            max_stack = 1,
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 130320)
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
        }
    })

    -- Abilities for Windwalker Monk
    spec:RegisterAbilities({
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
            end
        },
        tigereye_brew = {
            id = 116740,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            toggle = "cooldowns",
            startsCombat = false,
            handler = function()
                removeBuff("tigereye_brew")
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi")
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi") -- CORRECTED: Added spend command
            end
        },
        auto_attack = {
            id = 6603,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            handler = function() end
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
            end
        },
       tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            -- The cost is now 1 Chi, unless Combo Breaker makes it free.
            spend = function() return state.buff.combo_breaker_tp.up and 0 or 1 end,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                -- Only spend Chi if it's not a free cast.
                if not state.buff.combo_breaker_tp.up then
                    spend(1, "chi")
                end
                applyBuff("tiger_power", 20)
                if state.buff.combo_breaker_tp.up then
                    removeBuff("combo_breaker_tp")
                end
            end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = function() return state.buff.combo_breaker_bok.up and 0 or 2 end,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                if not state.buff.combo_breaker_bok.up then
                    spend(2, "chi") -- CORRECTED: Added spend command
                else
                    removeBuff("combo_breaker_bok")
                end
            end
        },
        rising_sun_kick = {
            id = 107428,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyDebuff("target", "rising_sun_kick_debuff", 15)
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        fists_of_fury = {
            id = 113656,
            cast = 0,
            cooldown = 25,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi") -- CORRECTED: Added spend command
            end
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
                spend(2, "chi") -- CORRECTED: Added spend command
            end
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
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                gain(2, "chi")
            end
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
                spend(1, "chi") -- CORRECTED: Added spend command
                applyBuff("rushing_jade_wind", 6)
            end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            startsCombat = true,
            handler = function()
                applyBuff("zen_sphere", 16)
            end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            startsCombat = true,
            handler = function() end
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
            handler = function()
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("dampen_harm", 10)
            end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("diffuse_magic", 6)
            end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            toggle = "interrupts",
            startsCombat = true,
            handler = function() end
        }
    })

    -- Consolidated event handler
    wwCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")
    wwCombatLogFrame:RegisterEvent("ADDON_LOADED")

    wwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_POWER_UPDATE" then
            local unit, powerTypeString = ...
            if unit == "player" and state.spec.id == 269 then
                if powerTypeString == "CHI" then
                    -- CORRECTED: Removed 'or 0' to match Brewmaster implementation
                    local currentChi = UnitPower(unit, 12)
                    if state.chi.current ~= currentChi then
                        state.chi.current = currentChi
                        state.chi.actual = currentChi
                        Hekili:ForceUpdate(event)
                    end
                elseif powerTypeString == "ENERGY" then
                    -- CORRECTED: Removed 'or 0' to match Brewmaster implementation
                    local currentEnergy = UnitPower(unit, 3)
                    if state.energy.current ~= currentEnergy then
                        state.energy.current = currentEnergy
                        state.energy.actual = currentEnergy
                        Hekili:ForceUpdate(event)
                        if Hekili.ActiveDebug then
                            Hekili:Debug("Energy updated to %d for player", currentEnergy)
                        end
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

    spec:RegisterPack("Windwalker", 20250722, [[Hekili:LN1xVTTnq8plbfWnPTrZ2XjnzioaTDfynOROyoa7njrlrzZAzrbkQ44cd9zFhfLLOKjL0YsYdBjiT2K3F(DhV74Ds2JSVZEMpIJT)24HJpF4Ldp3c(WKjtSNX3gJTNfJ8wHwaFicTg(3)Ie5VbfUcZeBTnKI8fIiHMY8GTTNnpLeY)sK9CDYD84raTXypy5lUYE2sIVpwsloXZE2DljjzUI)qzUfAoZLgaF3JtOrzUHKeoSDaLL5(74vKqIL9S8ffWWJYWW))TCZchHMhI9T)O9mj3WspeJdDwIyRLAKrILBmv)pzUFcKyM7hbJYhZafF8xPBWj8m3VZiugHV9KmxJm)vseWmakg2JJ9)1m3)ehhI8W(zUV2BjXYhhq8i8xN5UHWxwSOxkqFKyXKTrC0dGbcaLJzee4XWOq(sRypacxN5E5Wm3bzU4imBX2m3BaLorUKIKYP88m33K5YrHWcwOepCucy5wfoPm33cCMtYrMPYMdNBgCT)anVHp9zW6F5StUWycqPHCDXt9l25pqeiI9dfrUFLicBmqCLF0dfg6i)IJiUwgD7iZ(aijq694K2okAveEuAOpDtuUeoRHeQ80c2Vh7ao81eCsUN9SEQHeH37Bt6TOfhM9v2ikwi8ZFCwodlpzJHis665iTNTLYAjXzEklH33J7VZWN(PCXM5odZtJB50UYBuedwQT2Y10ZfdVPKP6Oh2rAWvh6p6G5pTxe9osonb7a4DDvS6(DMhsP(obPSTQazF8yjvqbxmBfjArdQMOsfI5HIWoCAEjGgu2mo5ahij6E6kSZdP4Od9HkBke2fTfOiC1p7L)mCQRPo40NMcHzUNM5owy8V3ONCEAqGfNSaZWBXsCLWHRULj2JGQ072b3BckHrIwH5wXmQNfAbC1nFRfdJexLjiP2(jCWswa30vqWj5gz766YQZKA0iW)LgXV8ofqQRfrroRrpasl39j9QsV5iLMiemq(jexQKHPuzULAk(O1X4O)rnG8BLcUZeVdcuuuxTyLJ27jPPElDOboRakqwIkwWU1AXaqWfd7vTiFsqGiLFnC069VtDv(lvzkD0jTw0Uuf(yeFzF9XqM(Iq8P3HylWII3GtROBVz3zU)U6(abRwn6oBuhEU8OR8SKCpXXkUkr8Rtm0Rjl3pjYpoydgEn0HrXLZqksJWFNyu462VLVeaJvaGpoxtmsIiepjnYzfXBLtXY7rt7uzgAnyO9wfkX3zns)vCnd6clfezipFCf0ceJricEYVzQ1RpYfSOhcQOgacghYzoDfOk1l5Gct0uEPz28(JwLgpEpUB5yhCmxz6q3Cb7Qd9waR56LkxcTbDpwFRhIDeI5QUeZpH6tjXlHI1AlzOSTQVTAzHsG0SoTvzgwHszPjlfrk)a5JD2at0Qv3hsLkeoyxz5jrdQp51N(aeuCkn40pheG9QxG6d0p))Pku9O80)1k18Ygc3svkD1nsIjrrcz4XeDHV3nBU4JXXD0m3L83zBqmHksSN9L1XugxyJVVXteYk7wqcP8LuM9S7qEuzd5qRKbKqy2Vxz(P0C7R0n62TTXHu1jwLZr(2P)sjSFhjyQjRSfwb82Kt1w8VTDe9knnk2ltOQVvaik9lQGfnDro4i9n0nOQ8Y1tVyOj1O2vNQI01bzVvvNoOMtW2l)t5KZaUlhOv)2vt1Ay)Y5z1VF9jz1tJYiPkoontXMBDprJGQhk9iQDGI4UE65VX0yMVDYBoY0ENowV6RnHNadMMn8MPJgUB3XMN(C3UwM88KbML7L6rwJ5dfy7WleU5CHZ56PJ6vGBNpd6UeXZqKadlS1YhOUWmvsjVC4aPrFZ0jdRfh84cdEwTIFGMxDk9Kb4opuAFSZEvEkrC)r9MkL5JnA276rdBYuzdycga7fYtgC8rA67z3ot91D9zN0qQn6lQu0Jbr3vRt721RzkpuP1AMQuLNnqJTmOlqmqtQ64g6R2WsLLE0nnyR(Ctt9DiU3B5tVQlKiD2nOA)aznQuRo9wdoQMVsHNdhvR4U5AdP1mGOzpMkrBD1kBH411eBpYU6AOPELFbJZ9isWk46PodtkwZPyDMH1uuVGjofy)5kAOUA0mvIUKdjX9SX9oJ3082(6tiMabnERvVt8(QMw1YC30w2(r3KkTtXYvVdURpRB(aN1HmcblDZz57DZ(V)]])

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
