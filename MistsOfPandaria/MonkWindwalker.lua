-- MonkWindwalker.lua July 2025
-- Adapted from MonkBrewmaster.lua by Smufrik, Tacodilla, Uilyam

if select(2, UnitClass('player')) ~= 'MONK' then return end

    local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
    
local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 269 )

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12)

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
                -- Consume current Tigereye Brew stacks (simplified MoP model: each stack grants damage buff percentage; we just track duration)
                if buff.tigereye_brew.up and buff.tigereye_brew.stack > 0 then
                    -- Apply a use buff; we can store the consumed stacks in v1 for scaling if needed later.
                    local stacks = buff.tigereye_brew.stack
                    removeBuff("tigereye_brew")
                    applyBuff("tigereye_brew_use", 15)
                    buff.tigereye_brew_use.v1 = stacks
                end
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

    -- Combo tracking (basic SimC-style) to enable combo_strike / combo_break style conditions if desired.
    spec:RegisterStateTable( "combos", {
        jab = true,
        tiger_palm = true,
        blackout_kick = true,
        rising_sun_kick = true,
        fists_of_fury = true,
        spinning_crane_kick = true
    } )

    local prev_combo, actual_combo = "none", "none"
    spec:RegisterStateExpr( "last_combo", function() return actual_combo end )
    spec:RegisterStateExpr( "combo_break", function() return state.this_action == last_combo end )
    spec:RegisterStateExpr( "combo_strike", function()
        local a = state.this_action
        local c = state.combos
        return not c[ a ] or a ~= last_combo
    end )

    -- Tigereye Brew stack accumulation + combo tracking hooks.
    local chiSpentForBrew = 0

    spec:RegisterHook( "spend", function( amt, resource )
        if resource == "chi" and amt > 0 then
            -- Track Tigereye Brew stacks: 1 stack per 4 chi spent (simplified), max 20.
            chiSpentForBrew = chiSpentForBrew + amt
            while chiSpentForBrew >= 4 do
                chiSpentForBrew = chiSpentForBrew - 4
                if buff.tigereye_brew.up then
                    buff.tigereye_brew.stack = math.min( 20, ( buff.tigereye_brew.stack or 0 ) + 1 )
                else
                    applyBuff( "tigereye_brew" )
                    buff.tigereye_brew.stack = 1
                end
                if buff.tigereye_brew.stack >= 20 then
                    chiSpentForBrew = 0
                    break
                end
            end
        end
    end )

    spec:RegisterHook( "runHandler", function( key )
        local c = state.combos
        if c[ key ] then
            if last_combo == key then
                -- If we wanted to model a hit_combo style buff we could remove it here; placeholder for future.
            else
                prev_combo = actual_combo
                actual_combo = key
            end
            last_combo = key
        end
    end )

    spec:RegisterHook( "reset_precast", function() chiSpentForBrew = 0 end )

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

    -- Bare resource tokens handled via core state recursion guard; explicit expressions not required.

    -- Removed spec-level threat expression; rely on core state.threat

    -- Resource change monitoring using unified spec event registration.
    spec:RegisterUnitEvent( "UNIT_POWER_UPDATE", "player", nil, function( event, unit, powerType )
        if unit ~= "player" then return end
        if powerType == "CHI" then
            local current = UnitPower( unit, 12 )
            if state.chi.current ~= current then
                state.chi.current = current
                state.chi.actual = current
                Hekili:ForceUpdate( event )
            end
        elseif powerType == "ENERGY" then
            local current = UnitPower( unit, 3 )
            if state.energy.current ~= current then
                state.energy.current = current
                state.energy.actual = current
                Hekili:ForceUpdate( event )
            end
        end
    end )

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

    spec:RegisterPack("Windwalker", 20250809, [[Hekili:fR1EVTnos8plbfWnPTrNLFKMUika71BbUnyVfhG7I7)KeTfLTQLf1rr1SzrG(SFZq9IsIuwjxbAlsBc58IdNz4VzCCTD)I7MaIG6(7lMVy98BTNBnF(QBx8j3nINsPUBsj7os2dFtc5e8V)NOKGhjXhPCCRNIzKauezSC(oyB3nBZJIf)AI7wnYD5hxSWDdjxCGbSV5uEip6O7Mdrbb0soOz7C38Ldrzf(4xKc)k9x4ZcHFENiILu4hhLjGTdz8c))j9yuCKL7g5IsJjkzFm1tq47PcyHFxEkPjKTX0a3)U7MD8ibLhrqRnm0kGseh8sycQvEAH)Sc)DhIk8V3PWFjyUsDcUdw(UdESqpj5L2kpkTCth9)PWFJ0wU(lsBPW)YnF5QcFdu7kaVLrtTXMw0At8i8S6LLN4DmA3rualh)SstO89r)fY1wo9rRa2JjYJSi6e4YyENi)PNKONaTv4VsUPKvr0Ek3lL9iLBXPNirjzkKOZLfI3iOllmN)eACRmACcsmnrybsX7rY3OwvenMPP4hQzd1X6POJT58mXRqjs(qTCZ50YFrt8Yspq5t7Si38Ic)awhwfWTkCx1AeT7b68PDnH5zyuoyxFC8R)DStBz4npbYG92Yoc3KGO7EdQCM3gdPFSCrt41TVe5lsve)LvHrAiPkw6ohPJ45Nn4Mk3(QUgRTsgAzakj(eAPFASmjlqWf(xR)q)vYwua2ZnkHAt69f(LFRfY73OEC6EkKp9oqWmwmMCz1lhvj1b06Q5t21lWsoHK84PusBBmJfeNdX4vxasNQmsXQ23gerl953mVvRPSY)FAv3(mJtpF5SAzNNr9aR8uMQLxxYQ5yt5zuEzqFhQMuTdznn18nPNTkWQmiuWJsocUHuoBNfzp82H4jvV0LitONcUIW4ljFCA5AEOZRuG2ZLXIilQ0VyeFTcLVRsa9kVaM)41WmxjgTPLtm3WC1Rw5tFIkThp4AR9zIH7BLjGa1YZ(8EkSMMjuzAeD2MD0PqIwRqESxp6DWQ51frcOsb1pdTceWaxDE6ihpZfgnuYFDRW69O84vVmy0A8wJItyKQBdo4nY2GUvrdyp2ZC2tm(02C5TQK9OKVXos9(ZCAsD(ERWu2ukT(GQAClWbO879qWJQQPQEoy7NIOzniBqY8krctys4g29bC9ke(D9LDxeSYA)Pqji4LtYuQ(d5cISE5SX09KDpHGXehavFkLYzL3STMSwA69wW)ILC8Nk8B7daX4E6ZCsiu)C9QBV(wJpiu4)V50R)S8uaCrfyIMbAhhlCjqc4hh9q(4bGEpzK1Ohuf6g8Cu97HQpfjkV8h9EOkmLNNDatv(kja0d4ZggSoGKP(47pdpADnl86FjmKIpED5pZ(LxBZfJdA97aUuZTLya5VEW9tdeGk4Ed43n)cRS6KJSkfIsC0IOMFh9c85NPgcKLgLKG0SJtsODb8rtYGAfztkAlGaPSjEagJt9V)kRPx3c7rGcs97ChOKyXbRumgQpCqfjo1WY)rJnx4)BqjT))IidIcdrCJNaKA7(EDOuLPBv91hjC8kidh)aGti6ukJlQgXWB7up(TiCW)BEehnKmgIhKKlyNicCbaHxcGWZQ4HFlkb2Ygkw(hjz5PO8qckTcqODhOWBB4yHro6fb2YYsJS0Pf8wgwzKH6STwAxpkTYmQwIVXiXTviAP(JgPUt3pTmCRzVzdaIwQ)KrQHw8AjZE(0ndzWriloMbPY7XBEobc0busW6qqfWCeWOajRwkXYSGT5IA6syYiR8KouheGehqeKTKm6pv8qzdQ97yx76I0QLBNLv1c9WwwTQc6oyLh0eYx1R5llyF8Wku)tjSs3vP54QoiXNsOLbgmhA1ZfoL4lJzQJeRP7yBBU8Hci3FibM9oIAdSAwP2DRBnSzpdbHnGEFzHHMDAAr4oLsVgrm(dX3R9yODpfl1GpgGY(9Y7oaQZu8S6ExW87zdFE6m1C6(8K5IogZynx5rdSnKntLtRqf99YzRanBkU5oGE(He02fOg6N(1t1M56U6ap)iSy6oaI4nFc7(Lfgfd9w8Mc)HDG(WBg2e6d4FFJ5ErX9g2o6OCuAHzwnvLEVZFtBM4hIcD61i(SZ0e(uKUsUCJgAAcwNc63aSELu2I7eCxdq2pjVvBKpOlLGw8iyUVLzxOhC)SwG935CZCtQrnyxvr66MyYQ6Soi54WNItPXR3Cp2BG9p)8WHx258csOzC6Ql2o(C1vRrFP4k6pT8zWc35Sy2LMNp(ZpFz18RDSN1zI435yp)QNFUE3fAn)QDFhqQQT1c7PXzOz(235SeTW7DShWBnoIUSpyuYZmn0yNfZF1YuAsGtZKSb7DTwNXQ5xnZ44NNPz0ZQMypaPYB1bdC9(1QS0tjilJmi5QZ1l4AsY14Jh(E7zASsBnxRkqBvIy1mY3oNWUZB9d4KuDaWnOeW1Bh469olplJD64FOiUB5ekhO7Z(FkvhS6OC033zsbn()o)Elu6gxAwiAIa6DlpGLodpOrT6(viq3n7QHHX1rcRoR1wJZRxfl1jeQtNJCyAqd2ViO60cFHYSf76h6m0thBfLmCOQA1YSl0pJvZAVZWjAreO)J4VFk9WGSHj46)08RQ2z6ZX)oz5)HhqNfx1pvFGn8vY2Q4sC0RxFotEGdOuvVxZNj)7o3Nh)9oRM34JoBQT(zVpPKBOKKSOtVwLucymoX4(c51g(D2iTsXpHCqDSC2KSb(cTvMQJc6tTMUUqoU4Cop5yED)Fp]])
