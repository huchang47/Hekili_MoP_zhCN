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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:DZv6YTTrs4NfvPcfzScdV0HZkQQsSt2y7C4APtLFSvi5qGHIWceGloImDPI1(39ry))(KLNKT75aNZGdsq5yNQILfoMP7V(RVMzmM2F6BMoXKeqN(Zd6n48Ex1By3(x2FuVbtNeSDdD6KneJ7i3c)fhYA4p)gtYMaR)GUB(36rVFnXpG6TB(pqVZY2A3C3LlTmSi24RT12LyIdVVBONb8QtNSi0Yo4fotxKFopV)5NdZP)gQbC5lUA6KvwMMu(Zs9nMo5nRS83nh)FYU5cPcNr43ncSCD2n32YpaU9s3ijQliiEUlTSHP)Z2nFS6)B3lH79ApQH76fKGDZ9PbHByxu7lWNs)UBKV1y)aIJbDM7YzbROZ8dc9m3oZ9D7EzXdeCVNtxsD8bm1V4hvmu)QpO2FNDOFKvy387xrb9hebJ7q8XdUXkRBxDgGdVMJzoUGITm02gU2FpK4zYVSP79oWvioWVV1neVGZF(V)VWZsS9OeZTWarW5buk8MMiMViC5YyiWms8FYykxSMTaKQZSwogFYUjV4mUm2L9JBg3VxRvuIDWQUBOahXj46(961I9w3Iczxu(ALFuyxbVxeQ86qpRLBTCUvcjFjYbi)XwgSC7TilT9OEF(t6i02eGadBq1buuLQ1xTro6rAMXkRUgHEEGmdQrlGYea32VBOpDw6NU1jgUU2OWk0jgU2sivZSP)b1(MXdlqp(jxtQh4VKuvgYvflG(B7Ep3oJ8(eQf6siNAHsh9(Ew(4CCe022zmOJh17HhucbDYIbdsYWfkc4(YTm2BfE2iXoHMWC2bL)p)p)VDZVS3NZXKV31linoA57CASzE(9wbWOeyXgJne71frR)kMuNdigOMPUmAUzic)oTtPRG788Hp8qwO6YED4dbtUMTX9EQxxmuedwYRtFPaRqnoJtTWGtb1K6fhgGXvqilc)WRYH07joy4ZaxG2SI4GE6mHLFjYA3qhaaTjyeF1Wugnpkcqcekh94CGEKMhmSJqHFoz9gmU2pq8wZu2Fes3GH5Deb(5tovg)dEBVTbRyae1MbmPrdic3PySrl4cMOgQtrmzZ8SvWehPejUwzg7SkDExIkKw4zcxMsZkeLtWH6DR17tY5LrhWqbu82BfiXZwzfR6sNtuZPrdsKjK)IDHNoKyJcFReEbxpUFszah3etEaXgEgQzIznIgQC6HroAE5VCx5L6sDilSPMPM9b5toWZTC9tJsnOf6(mHe9laVzjtKQgqd6hbJEGuWV3Yt4a(CR3)EUZ5pqEVG7fU5mee8ULgefbArONd8yYSUtwbkGT45xqCUdqRiOXvizaYSGnPy9flHPmtSOXJp)leWfX3a5XUos86jJ(It0Dpo65ZfbiQ8AILJ)nx1YKYP8cvci9VNcbIKxpTSeLiotOBUtjwqfdLniBeQSvWP(SAfH788Zy(ToCmKLjwL3zcGqvS4dt)J9ufAbtEndxVHlvGKVjIdluoMKcP)0ySSbkOByWS7SmURHK1QXNDr6y7jqukuI)r3BTm6ugVMD)Fcm9bee7JyKSeImeyTLF66fmG5rLEkRMzuRmzkpjftlkNgpW172Gzz4H5zUsuOpaEfp)eL4h6rLv(NPinHyqXbit0A5qmBTyeYmPVIcEQtGgywXZVDlgMJnL8OuYqN80OoUHyksrm0SZ)D0BN5Jdvgt91d)Y(AT1Tsfx9M4KcXwI3Wlp51yDaGvvKnE4izLFsZclJoacwEQmsIIjGACsBHANRud0f4HhYDzrCHRhpOtHMnlN3g6f5OW8qKE(Bs6OO0QPOpGKi5(5ZKhJBjFwMQbTJ4zDhWns4J9rU61oLJ3qEeU0kB4gPD8FqxcEgRsMfAPm(mzb4yZ9nyulkNMD4HcARkPZ1JH6HZgKOtUsl(nwZOjlT4mrMezveNvv7dwxX9WWLPud8sXLAiBBj6orIBZB)U(QZr9TCV3RZIP93dF5rsW9BDFvS9VuRAABzjrSWC)eNTY(iQGQDqbMyYIucyT0T0Y2g)nwJJXHpteEpvvXaNjz3dH(OvQYIDAJ5WluxMS28WW9Mato6e(grfJFfKbhAndjY2ugZVn0M7aMuV2I6xAMD4UVKSGRUlXrIPDtEd3v2Mp2gSX(mzBGC1q6gLmnz(fv4M(Dh6hdq(ba88wYcex4PQNjKuWeLny1vxg7EfLanQguyGRuO6hb1tSwbB4CAHyC8u6AfaNP(m2TuRnemLOYPtgduwndNZ7hYwUwyE2tTzuJeeSYM5gqpBsBzdP91YER1xhU334(D4cdkstZAeOQXj4V)V8DFnusWl)n(imzJLJdZH6zEeCfxEfKcGJ3dFISRw)8(v6t8sCXWNEH(yq2zVLysNDVLJzEWgHbbGL7PZNBo)JWxH1mMRlAgZvzK10kRVaeNzGyyuw08Q7jLQVzuNlBe1rz))97(0Y1ZJiHPeN0p2r2Q7W)jLJt1vBETqQztlj22lGAspI0Hctq)0JswaMoRrJv6mC44WE36yvqWeaYOilkphUuUflpil6bw5LSFo(keQE7RKj0XBRQ4foeOm)DL8moPUUgaQ1(WT(DGbrlNRdq6gvE4yaHpA4BLIh)be1hvfaSAK7IOQ2C9pyfb(LrxiWmtxQClKVZb7OCYZEvLXgE78JUOk(uffvA0rlQK(EQ5Gs2gOsWMkPBAo0KUz68iuDuB2Et1oQH8hEi9IKeNBrBLWI1YakTHjKy73(bLv8SqHWLucymZ4)6m8WOCgEMzgBM48Du2ZAeVPFL9OYTBaXT2nW(l0P8PexaKYFk4NQAFQ8xeyekjbjEtsyG7msaUdFtNaaaQarhJO(D7FXWH9VA6K7jS9yZhp1qypIR346fiAG8uuloD3Cp6)k0ITEU(URHhch61e2MvY3(B)U7Ej71x6Ad4mJktc9i4kcq9OIT)HTDvSthdrWzqfc38Ka5ZXp7nUHoPEAttx2gDfqwq8PFnWKWT4o)(wGumfAbWQiH2bvvr(r2MMp8RXTiYbao2TDztfISCb70gHhDkFrJtpy77y1vJ6hDWRQha0haGF1XpCdowSfkqy0ovZ53sRae7vxpjyujMGmlw((FctQ(5lrAWAQPUgZ8hcxSCNKmnwyza26zF7xD77(6H1C7AVcl)hEzkckh8ybLXK8MgqsmYvoiCdOwnNA8bXdnnRG7EIfxkolV8knJ28Br0CHBlBF8TmGjWZY5oAa4zoF38xeWFjwwJ1uhtuOHk5deNAmCSTC9ScWUFCmSdnXQ65NEoPu9pzBd5lcOR9)9ZW6FTmwL8Pz70LCwfkm9DBSHUOcSJh3K6VCs)BSvqtmnVHpeqOKFxujD8LgKyMVhkepHgjgYa5JYqd2LCcxVGYJEz7gag0xSwM(7Q0wmmm20jS)gEYTXkLGF(ZStjUGqm9BHRdYmaYe4r57P2n45zC0U5TW4Hruo(1hWU8j8JtsIn3D6e(mpDsQnzKFCV9S2WVNU6U1Csx0wNELoFltdGAj1QR8azQoxjXQs8M(Nrp2Rd6ckpd1kpPq6RbdaJ(0F38Vq2TVIw6qBrQMM4gPr9I1HOoTuPchWXMb1Mr1Gj1wqzYUrW7M)WdkULiNdafCsxNynkUjZmQ0bEuBqn6CTAu6AGyMO(96L3jbU(5Ly0EcyHypYj7JPv6aw0AiT3u4IpvmicDXhpiuBfXVgYUPYLlkfjRXXTlRHVIMOUTZe1nLpYqUJu(iZPuRIcoV)hFiu)UsR(jmGgzoooCnv3rYHRupUShyOV68ySsksQiah4XxcbSNwgH4A98H(hCi1r6cPcsw)EvllfJzwnUvYJLeBkQtrihIEEGPosFMNysU(skYl55jydVqbLgTOvqiB8ddfOpbW86wszHPxcVKXrlBDUt7JRzdb0fi)IJS3FLZHMtURAvTfDgo0xB7rAJ4lUCy924tQOzwHf8YJSfuD2WBaVPUpTEMyfB0AXLR)jlEDifnPcft7QCK42Q3uZIBr5t3OAhIjmFSUc7k6WDd0VLGPyM6l0)yGK1HsxYrBP4EM0JFnCNn1ZMKbshvAGs9D3CGUzNS)EAc4klw1quejM2UykChblEu9Yh9wYIm0SJ15bP4E3(RO1B0(c913RjTbPWM20JuXTZn6I65gwwOrLnz8OfASIC0QFqBkP3t9i8(buxNILLP5nSZsvTDxLMjBWdydVdnXPdqvxAsHj7zWOQTOO4aYORZe(wjmJ)LJjEdZv1xHEPkXqeD6yuvPT(riMqK1FECZWWzg5eYPCNJvvozfvupQQYOQIoML0ZwtJuJUFGQsm2NXMX9tn24sdiZUlhXuhAN4zKruJGQcxpHJJrRvb93Cf72A296K3tXoyhR5PVzv9Ws)rjqFB)pkFmckEraoUgM4Dppgszxt1cS2yF1bQXUU1qACcctbRiAD(QeWDUIJxwO3L(SCfTOJS3k(lfsLj3rNWXsi218ZzsX8ubYBK5BjIYAEgetaZ)DfH9epnr0sXiQDj)R0hdLOK2YmKfAVYjAP(QAjk8GBalyh2Y4HPwPJ)sBLWWN4(v1QN4BCwzM9p0FzZQraV4nwPGViw5ARjXNal(7M8WZfLtvI2PhSm4Dd9vpRgr8QUk3wb7tezrSTJQrKo6aLbhaOC0(eQv8kgQzBz166P60vkbZmiY4OnWvfkJRlCN4Xn9PUS6jtFK)6Rv8khQc10qYoxqYYYIyywIgYYG3zqI)c9bxR41eKhKoZ3NSkWQuHOQ9zJHSettg46r4Z1gppPVY(AlPdiDl8XvxwTfei7Aux7LJtBAV6)vFqFk0J)NdHItpECH(dD54uS2thvSs)Mmv9TjSqe8iUQDhkDVH(InuC(1)Qbwhbc6HdHAzHb4xhzX)mAufrTAHVY9Htw)Qbkvvn)BTHjsbS1lALRhujIL9wYA21M())d]])
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
