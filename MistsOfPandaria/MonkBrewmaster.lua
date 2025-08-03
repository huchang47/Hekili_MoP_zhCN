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

         power_strikes = { 
            id = 129914, -- This is the Spell ID for the Tiger Power buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 129914)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },    
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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:DZ16YTTnw4NfpEQSuJRQU5BzT8m5w3eN02mvPt)XovIqKqsmMIulVexNXdN9V7JW()9jRpj75aaEhGKsMYjB3zY6AsqGZ57C)aapT)0pmDIbXNo9Ng0BWj9oV3WU9oT)GE9NoX)Un0Pt2q0VHSe(pSjRH))Nzq24B(jAO2ZDP3UM45tDd1En9gtlZqnNflm1njw4NDNLdXaNEpNaxD4tNozEGPL)BSNoxYA27IHNcJDdvhE8PNpDYktddkFSup9Pt(WktVqn8FKqnbvHRi876(Mo2HAwME(WRx4etrDNoH9qKm0DCPWp)jgltTjZTOgtF(0j8VgiolyoDc8NDJP(n8f11Cd)DJL))c1EbmPHATNSI4snc1ENZst9oHAkh)psmT9H)fQnzvWIfwWhph(jWxW)wB65zAVeivxtawnja1t)e1ku7k4thokuRvOM(kZU6bUUuBF(ZhWE8b8jQRhFA7gSzQpaKk4v6FSHAndi615y0F1dOOxHVfGq41Cc7LuqU4csmGbOeVaxAKKqh1fstWmIWiA8ZwlgUGEgQGEUHUCMhOmTsg58w6saUW3gQ57eQTKAliMxSYKtGwo3ceJnibO2oblxH)K6U8U0uwgG7seqzahFGDbkjGiq6r9qADKcA13Cj1D2gIvESlr2(bCiHAV35w8hTfcXHJEsNmcAq7fEnilmDRuS3wiFfRooZDnCUfwS7VxYRCPRbkXJZOGgshKJoPz0gmT)yatBNb42o(cbHozZgyItXgROel)vDbDbDoQhQ1VxVIQXWZpju7BbXlXcEqxIhmEpGe6kO2qTNaIf2qoOSrvM880DWU)xOlaL3vPSwzaG)rOU)C4J4AKmriLloFigXTZzeNrkoKlQlAOlKUNPG)G1A2Te0kTOSLj3(nYNemghyPghZ8KdKPJJfQKDCnK1cHs0QLrMenpjVndN94Qrat95NGa255aSccSlvlV6)GnkhHInzovak7IDqv95oVnwnvPBpMQgUc971uE3i(OYXDGpye02)oX6Rk(TskpIEH3ajhyAzH)gljHehZPcJWvxs04xX8utTq7LapCzlNjlQUn8ujk4OseWp(tN48jQ7cyPln5exkXF1mNfZwaEAQD2jOP6plM(sYkH5l45SLGNr1pWCNXc9B(5pFhdbEn5ZuEu)GnhJMCUlP(4dSpYhfEU2WWI8uK4Veg)CI9nzDwKbkg3G26YDFEfyYZETbLNFIGPGyEFM7bn5DzrAM6zzzsTmG4AiZ16FhFrO2TRO2CJKi)MceIheH5M9fVeGnqpYMd5mVSOHMbXg0CF8WngVeZXQYvRmNqmE0iy9goNWJsiyybGW4UaV9V(a34YGUGey5lZ2QE2q)iZN3ZeLy8oOAcLgsPI5sSSMX)Lzybi8YqMXlHcijKs)e1RmfRsNIOaQEYeujWA7CoDAiKntKRsPZyxBLKpDfmk4TtsQRj8iVeKzGx31M0Oyf1C298LLyO65M5LVMZnXHgNvw0hqc8DMr89jOHtYkYuu34s1DwpN8auvFF0ueQ5r9r3AkgAcf55tS1PO3o)v0zE(bUg3nZ5p4KuIwwjrMyH7m)m6nfCDEBDP1xen3vfw6vXZpVLdPIuJgKzIwdUFsl(YhjMvkG6qXQnfHSwLWBjzqNqxrzqNqq8qGOnG8KLXjoBYY5YdEqIdAQva63G)nEOAeBexWfxEsvDIyIpsMxxzZeaSXy3FqeI)7r)ElxHXWSOSIfA)N)7)7ag4JggL1WJRjZ5iZcCgysXjFGxPKfFo1zZjebCLzsH7r5rKU2FehrrEKAjyp2V7qVkDgOQSWZplBXjXnHitIdWse1GfHuJLCkyR4AEd1lv0gL6pfH(9pQazEyIzZTHNLUGAF8WQ8HEUACudxyAYzXW4AyvLZHceKLeFeWPl0nJtHkvHQXnhI7SWlG1NsGW2zarQJKMk8A9u3ufqDVbwnSo1JaeUtAH(zsrRSqFPChxxFRVmEMRmWhF2JIUWlKG50hB(ewFg6AaCj863Z9cWKJlcSSooozB8XPBGZDob4dS)Z)1)blB3cQ1XaeXRy6cqga4lnwkAk908T1nn)oJtjrrHy9eHlplPPF5QYqEGTz8s0QOURnbUMlUtrwhVp6LrG33HBia5t3XaWLS2b0EuVVb7hB6AtIrrUECPTrH3biipl09nO84rNLLMuYXcsyw6whuMZVTMv)rhdrdYt42HCUno3juPbDeKtrrGhXFNRz(MzUJarBjkgcFaX9(jno1rfunOmxFvvn(gxhUO16oHdrE41y(LT1ra0a53eQDwVVHJy)GJRFwuw01JAONmOCn)fXtnpRU432Ua3poUhWYqYZ6vrx(ZTs5qPIS43j8dHaGCTekenG6M4aINuUBk4eFkhHVLyJ7nh2TC9vyFnI7(g(iYANaKrSaTw3c(DYHBkuLorOkLxNHHADKvOxeYyqwVHAlBdqEj7nrB(bGiVJG1)BzAt5nkJhOGg5Egws37Y0XWCqg4a(iwR1K2EhUNVeQPU6kYqj5wB8WByTPLexZnWdzHzFKyqNDRPDElkLXTEMZRqxnIncHT1O1OeHN9ZV6PHA)Y1)g)7MSX02MHGVWLG48BnXimOA4WNe13rVIzgx2MtiTqEgmjYGOallF)lkomreu5z4C6(pdNQssmF8Z6GjhutyrchF2EMJv2F3(DVOwqssNpeQzZ0rTmEZmljiSSHN1QypPgV9jD)xgb5oL9EHCdQdqvlu6RyVa7asvI3(ssIOAZaf69liwwZz99SoYJ6Q4wz)iUqLqzpw85o0t5kOYDscVDazoCyuLokvDCdu19bH8pktjMFsm5OOoMY3uScnZktRiWxxVE3SLM2hS7w3cruE5tdPlfjhBxUUEhH6(OAfdS0Z(WxJi5ODfg2ERMSkYLCwmQPEUfpSTpuZdWhNkuOnCOrTA4gBSQPjV4T1tiKC0ugD62zHxLRsPNEHhbxLB)rrr6b6Gd357mEkNivEuoud67g2DzgD6ChueSsvzTsH3asW3gujjIuXNr2(D7F6WH9pF6KBjSJAHhEKyXsjxVbQlu0oJJWnm9Oqnx6)mWKDi98Cwddc35X1e2gtXl)2RB41SpFHJfOJYagsGlb4iqHLY3IEEDQS(cYfk8ZylA94hnoExhHY3ZmAddhwfU(K5ep6tdVMv9CXZfk8IRLWfIDTVUmY7y1Jp8P42kAdah71oSLciApoHDu7u494XN8TQukFYOV9avVRdqsydlYoz76C1vb7hVxWBha0haGF12lydox4aIeAhPyBEvsaj9)E7OGrvicsbAxnEqRC9TOLYUC0QDMU6mE8W7VpBdoUC8z9Ifon1YOyv(sy6uOd5kKCrN4ITtU1V(YTD1YPLSk(U68wkoswTuFCSKiL)YttXq5GhlOmrHUPbKuZCTDU2aSvZXgFrSqZQvWnpXuq246a5Oq55JeFY)fEPfMTSR0GPoSaUM23q9bltTqT34Z)iw0G1uBdKOHmj9fnAgNBthi)fS0iBDRadmTfEx5JOQ)bRh(VXNU273pgZsYuFv6rZo6UrRQGHP)XglOelFRK5nn)hTO)nwJUelZh4tb4k53f5BL8ObPw5BH01sXrIP0pAOm0G9i7G1ZPCVxwo(Ga9nRJcRDEwjg6gdp)umyE6Kdv3Q5RpuYHK66Y(a(641noI8yfHsr5DfRCQT(T0HkMQVo2e4eiijNGNmoD0OJnxmU8Th(QX971kxG0(96jpUS8TcogvAOT2voB99z34sKZYKkr)wLSnNfyNm5sC14HLWbn(o2Up4V25ZfAuV7Vpht3jpxpiT28EDxyvWYmARaN(askelGtAEHco9RODsvbKKJlJnGtHgfK1NaY6SI2Hrm8JWMKQGrsTvPXmr(TpTebBEMUO(Dn8QNCqwRWP(H72bAnH1JpoUaNtZEQBrUpt3hqIVvkn(lh3pnnu)tTQ8LxxCWvX1vKeMEUZYAMvFqrF78qdxErSNDLq3H5Vil1eO33xOLeOjQOlazYMfyo)o7AMXnxDks8g)WVHksbcz(DFy8FQd4W1jAf182MixyL(QS0q0A90NLETXRtwH15cKN2M1LkJpJsjzuRCrfpiJMgMDCkhxB51cVazKCpJt8wl7MINErFax(7cRFC3BZjQVC8Wwz8EEvIR)h4L6UanK0u7SYH2m4i)fJuKFLKlf5LJh0PuHt53s7kKnsswpnETBwgkX4D)ww)a00BlZN6Lyl)YBd0PqKZD)gtxGG1f3i6CrstFfQBP86tF54MxUC55NG8B1QTxMht7VdkXJIa30xF5QLQzLLvyQM9gkxhw7bzrYOLg)ohxBYoRWC4PYZcuzyMd3LR)t1jK9iCHxIbipFaE(izoIl8irr7PhiIY7e68ZAPE39WjUvKDJ09s)XJ9KEmW2FmD7mMyd5zGLF)Y7KM9BG7xYUXnJAeNG1wm3a8ztklBiUFRK3kT1pS8ZaCDsWDFDmkJrxId6(SWHLOiyJWGaWuE0kAv1HDjV460MrCvLYAwMvYr4so7EqL8Bo25SgHDKwEB)UxunFUhvyQWi9)3r26BW)xkdN6Z28CHk)0SUhvhkna9f7LOamEwbhl1y4HJdfzJAkHQdcMcqgflr3xNg18qG0431YY4GT10aqT2pCPFhysuQZ1bu6gvT7yaH3B4BT8h)fe1hvhaSEk3LPQw)duATXgE58JoTo2uL5vA0EZRK6AQ3TJ9zEOjBX0frOTHTzB9s74cYV)(Snjjj2IYmHpu6F1HQi5zbdHTuk3FwAog)dsZyJuN(GQgREYEAv1qJ6MoIBnYbSS6LeBas1Jc(PSYNQ(dbncPkbP(Ym)D8b(LvoUtN8RMw3rwZo8Ut)F)]])
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
