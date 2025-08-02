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

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:nZv6YnUns4NfxPITughfDzBnZA5QMRSZzYuRCQ8JTIKGiHS4yksT8ioAkxQ2)Upc7)3NS8KSDJdsqsaskljpjPMm2aGaD)1NOBYmUZ4RhpYMerh)tDB39S2dA3Tv7bDh0V34rrRxrhpAfX6wYnWp4rwc)3NBtwf5870ntFra9ULKWiAWMPVHERJRZMP(ZN7y5qCXhBTRpXg3(q)4al4rhpAwSJB0B9gpR4zEEVbD7dRDf1cg(8bJhTWX2MYxln0A8ORx4eUzk(hYMPcQcpr43TIC892m11jmcMEUFcf1ciKa)5oUWX)nBMou))S5DWCFkGA5VCgjAZ0qAu8k2GgFa(rg2AL8Pgggr8SOt8NpjAbDsyuCG96j()XM3v(gbZ9k6CQxiGPHLVuXw9lHaB)A34WePWMP3TGc8pqcw3I4tamXcNBwCkGdFIJzE(aJnp21fg7VhtcS5dB7FNhmcXd(91(X4aE)5)()cRL4gqj2RHnIGNdWu4K2iMplE(8uiWoH8FYqkNSMmdOQtDMpexzl1bBXOXRg2P9XlOe3OfTwrbLdVOl70U9XSLFdsDTqc74cp(e2i4CjWXNIdCMV2X7gjw89OWN87Rz4Xn3GQNn63(BFstbBQW9mqb5dGd1Yp)Wk5UNWswlCAzfhea0mWghd6krW0HTIdPtYU6cSJGEM4s)DQ7vd7vch8rFBAayIOYe94mHdOX76Fhx0IQ65eNc2m55cCcX9(aWFnYjch2V993NJPBMNR7QQgliDWgLlfCxlmFrTxfEGzrdS7F(F(FBMEr7VLJc)OFquwKZj07KQePmARaN2vVY38KJGR(YMPrgwcmnN27(7ZJfx0UPGtlsMFVG9rMqV0J6agCbPMVmboIcjqcokhLUJ4HU9I83m1AbXdTqzegFiYs)ypatCjONA9qsoUmXYvbnkiRpdK1zfT9Km8RilxH(JEdjyjJz)aeMaDp7jCyZpCQ0Vf80bRJwWaiQldyYIgGNPtqFAoWa2ihAIrSzN8KfWbNWekJvLGnptxu)UgUZFPVVl(0v6npXxUhn4gNVOQglnXXOAuC61cK4LlCszDl5jbConztseH8hSfS6yIls8hROXF5WoQ0aUVkhEeXfwd1w5utud1E8WoNCU8hULCOwupYmxQDMtVBrF78qdx(0ep7gHUVrqr)mO3mNrs1dOb(JeTGRc(JobcdWx58LVWnoFd5lcDV4vNIGqWn0OeNkZId8GLjJwoAbWaUI1pJ4DlGwjqJVGYaKzg7qX8cMdhzo)odhE23jGlsOfQh77jXRN0)7oY0CC0lKtcTcOljoEHxn4yBkxLxWsGs)xOTIxjhplTKehnN3yUrjMiedLTiReSSt0jHSC8GzE1Pm7wpogYcKQZ6ubi053D34)ulvbxWOx74LR4ufq5Rs0HfmhJsHyzgewUGkOFC0KBDSUDprR1tF2hvhBmc8sHu8h8VXXQzv61S5)ii6Jii2NOrYYpJHalDcZg83cohD8PmLK(hNlQ4rz00W0IvCC9hRWOmC38mtjkK)opTLpsjHXbuzg75cilidkUb58wl3Ijlf7qUd99uWsDeCXJf84B3GU5yhj3lL01jpmQNFmgIu4dn)5Fl9MjH4wLtuF5WEhNX75vPU(tX7RDybI)K)DS0ZeXC71xMKMe8zXTbw1jqNOic3LjRiUlZkhAWGdXS4rWu0f5xPoSW6)YHDBwQWXX7ZXbjMdm7aP99kvZbTYgnjRRIxpmldJy8)Gohe8luDYox6(Hmd0B5IEgMs547URP3qNpvqt4(7ZBd0SqKZFLDhj1iNNkCukdsEADXDmS5DW2LlskouAKuXMMotc5U)Llxo4mKFRwT9Y8yANhGsCFj4(c)3Nk)RuQMvwwHPkgAJ4TwMMCnyTDYIKrlska2v4kooUU4VXUQtQFdfVxzs6d0zutoooeLs1MSZkm7DU(SangMbMBeC4Or41IeI(biafCZdur2LY08BaxmRlJQx6qdRmWfm77iZ4S7CCNyC3OR5MYU892IT3NkVLdNnKMrQrbWamyIYsRIntVQtREHPauyeapFMmdXfEKOjckfer5Dcn4IuZRK4djPybBSkdWeGs62sagjjePAMlJhXfRHXScLbsGhiv2FFyNxdr)Z9Fnw5bHpwwsk1viZF(F(1pd8N)UFLVdJw545Xe2VmGG3g89G9lhX69ezg3HfL5M9As8rD)G4q0czYNj20j354zxeebBHJfarHvx0XAXLWQgwEXW57lXqw2juattSqukXjxrg6Ok5OdbbR)2hDA9uHq3GuEoX1Dg43(aYTLA5(0dMrKIdbjpkUfftZhDqjZlGFrQcESY4DaNwNhcoCP1frT0UpABvVbaQXUJqnHnXOCPjiy6Vzk8VLGIU842rliWV0)CbCz7tL1W9wpmO5Ox((Adw8mw6F(UQu1)WQuPnTboOKpeOIIufjmWHMS5lueH2g2MvDPgj5CC)9zZdSzTUd8hzPQ9ClEZC(GtyuvHyemeM1mOXmH)RtW2aDk2TQH2kDwPQ1ALw2UQwQSGbiU1ypuHGMvFKyoEvVk4V1L8q1piOrOvjq5jjXr(tiryn6gpcaaKbsAGxNwDoVxVodgp6ocRkzHy)6WCHwUYpisKO0jixCYMPb0)vSd7QOH(lHfHB9scRCJ8cyh2AZ7yp(CFxaNzQYK4acOLdocOIc4Wk4eRVueHodYqy5pIKRJ31l)yVmR222NvQQiYmsi9zGMewK6IvEavX0WfGwfj2nQUmYhyL9U3ZWI84bahBAF2rHilNWozVOhDc)EXz3Sh6E1Ya7N0YZTda6aaWV4fgVc3lwcXcH2jg6CQrci1QE7OG(vic2B9dsF3GKcN91Xy4u(Ay6uOfTgKCshNBNCRt9LBpulN9x901iL)6ttjqz3hlOmvHEFdik7CTDUUhyR9hB8vXcnRwb38etAu82XWZGmPG1cV0cZwwf2DSGdiWX7w4(5TW81FBe)Hyrdws9SrIgYqps0pxCVD8dCIWl04z5gBJzRZ7RTKQ(NSkO(2i6YWF7umVwhRfQRMvKo5Pkyy6FSYfUyuKB6(QY)Yd9VXk4G4yUMVfGRKFtKHC6qDvo57GeSv4iXwgjxkdnyd5fVCgL79Y1pceOVDPmS2GSsm0n24rSFcFxOWmGG)(NyV3vcfIXVaghOzaKjWs5Ld8k8TkaUy0XO)Wevo(4DzdFeVrpk1LE8i(jpEuM6JYFbQcCwXNZu(0g6bLX8VRvNNghb5iAKxn3XNuwjTpe54JhulOq6PNr6jdsFjkbyiDMR6Wfb9BNsHj3pshbUdTRcP1(BHEsdHcr(kuVz693RzkrefoJcQunt5O0RgMJL2XMFHC0zg5OSzZa0fyV2UDrtay8Z2m97K1urZTNN(eqcXwYrLTQQfTBPYx5Tyd5(Z3c5Pb7(g5S7Zih7Xf2f9nKr(wM7HhEV3q(7cJ8NqmKVxwCo1u)S4m1JRoaS1dolfRKKKofGDS3FiGnOkfIlnRp0zNn77BYShOSNwp3KmfZ6PAP2sp8e60UkM)VgE3Y2VqgLVnXVlQF17CnA0OaTge5EVrIa)ebNRFf5LKT2qcgKXgvva1SM4gk9SjVXNF4m(tb7c0uDtzQS2JzoXPdutXkpxlZYVJQPi8Xv6W2y9b6UcSuA90uXNMgivEEE7owyU44sYZC6fhmiRCejRkDf9OR8Cp3rFbh9WDhiqVghgaectKS9LiGBkKX9tb8ptMLdGpuTdS8COnlzstNO)57xvDTr5E0u1RjYx)wiwEA6Mb4hgoDzgL6CjpGz2OlRV6KmZESZH8meeT9qxwcj5kNR5s1nmQMo)zk6jVwkt4FmAPDcqxSpZuLYwK02pDrmmVdPke5DfnC)OGZeYk0PS056CmxtgnGQZ3rD4X8k9xYZ5xz3dJ0z28q2BMUFM9gtnvE1s5oMPBKPNitrnbQknF2dJqRSCwgWM2q57vNttj8vUGvMjRRfw2VxcZPM(O8DsuEIQhwbtA7dsHu2y6UF)E7dIylk74EIJR3nY3MpycUXvQ)YsTUmhLRSl9YEQ0pIPARCN8QBuHI9w(LwvUEQsbTu)mN0MYt3ufWIFYtSvOCDg5oASIt1670kjOTmczPYlJKglJdUKRK6ZMZ0sp3M(X7QiXvMVUIBLVx6QK3FT)kP3cpDPf0RKp5wJGDMxnGKGOsuo7MKdN3tFa1BHlU6ZQn0O1jCLKu1pvKOPjWO7oag79Vf7YVCTHY(B0et37kIe8YHedtAqGou9I2zUzrvrfpmF02LF9wDGGbDKZe6i5vgyqGcBMd(YXW)f6B3U87LY9TM7tDUgkj6qu9MCPqMYXKdUEe(YV5X1c1Ep0kUXIP6um4I6Db(ELv1bJrI2(VEgZr1o8F1mBxrKlfw)Qw(ND(dZHRNL8YoQtDREY)c)pwgZL2qYugEJihlik4YVl8dgp6nKWG4BzJn()p]])
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
