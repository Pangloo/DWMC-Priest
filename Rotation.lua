local DMW = DMW
local Priest = DMW.Rotations.PRIEST
local Player, Buff, Debuff, Health, Power, Spell, Target, Trait, Talent, Item, GCD, CDs, HUD, Player40Y, Player40YC, Friends40Y, Friends40YC
local Rotation = DMW.Helpers.Rotation
local Setting = DMW.Helpers.Rotation.Setting
local ShootTime = GetTime()


--------------
----Locals----
--------------
local function Locals()
    Player = DMW.Player
    Buff = Player.Buffs
    Debuff = Player.Debuffs
    Health = Player.Health
    HP = Player.HP
    Power = Player.PowerPct
    Spell = Player.Spells
    Talent = Player.Talents
    Trait = Player.Traits
    Item = Player.Items
    Target = Player.Target or false
    GCD = Player:GCD()
    HUD = DMW.Settings.profile.HUD
    CDs = Player:CDs() and Target and Target.TTD > 5 and Target.Distance < 5
    Friends40Y, Friends40YC = Player:GetFriends(40)
    Player40Y, Player40YC = Player:GetEnemies(40)
    MeleeAggro = false
    for _, Unit in ipairs(Player40Y) do
        if Unit.Distance < 6 and Player.Pointer == Unit.Target then
            MeleeAggro = true
        end
    end
end


----------------
--Smart Recast--
----------------
local function smartRecast(spell,unit)
    if (not Spell[spell]:LastCast() or (DMW.Player.LastCast[1].SuccessTime and (DMW.Time - DMW.Player.LastCast[1].SuccessTime) > 0.7) or 
        not UnitIsUnit(Spell[spell].LastBotTarget, unit.Pointer)) then 
            if Spell[spell]:Cast(unit) then return true end
    end
end


--------------
--5 Sec Rule--
--------------
local function FiveSecond()
    if FiveSecondRuleTime == nil then
        FiveSecondRuleTime = DMW.Time 
    end
    local FiveSecondRuleCount = DMW.Time - FiveSecondRuleTime
    if FiveSecondRuleCount > 5 then
        FiveSecondRuleTime = DMW.Time 
    end
    if Setting("Five Second Rule") and ((FiveSecondRuleCount) >= Setting("Five Second Cutoff") or (FiveSecondRuleCount <= 0.4)) then return true end
    --print(FiveSecondRuleCount)
end

---------------
----Healing----
---------------
local function HEAL()
    if Friends40YC >= 1 then
        -- Fort Buff on Party
        if Setting("Fort Buff Spread") then
            for _, Friend in ipairs(Friends40Y) do
                if not Buff.PowerWordFortitude:Exist(Friend) then
                    if Spell.PowerWordFortitude:Cast(Friend) then return true end
                end
            end 
        end
        -- Cycle Party HP Values
        for _, Friend in ipairs(Friends40Y) do
            --Party Renew
            if Setting("Party - Renew") and Friend.HP < Setting("Party - Renew Percent") and not Buff.Renew:Exist(Friend) and Friend:IsTanking() and Buff.Renew:Count() < Setting("Renew Count Limit") then
                if smartRecast("Renew",Friend) then FiveSecondRuleTime = DMW.Time return true end
            end
            -- Party Heal
            if Setting("Party - Heal") and Friend.HP < Setting("Party - Heal Percent") then
                if smartRecast("Heal",Friend) then FiveSecondRuleTime = DMW.Time return true end
            end
            -- Party Flash Heal
            if Setting("Party - Flash Heal") and Spell.FlashHeal:IsReady() and Friend.HP < Setting("Party - Flash Heal Percent") then
                if smartRecast("FlashHeal",Friend) then FiveSecondRuleTime = DMW.Time return true end
            end
            -- Party Lesser Heal
            if Setting("Party - Lesser Heal") and Spell.LesserHeal:IsReady() and Friend.HP <= Setting("Party - Lesser Heal Percent") then
                if smartRecast("LesserHeal",Friend) then FiveSecondRuleTime = DMW.Time return true end
            end
            -- Party Shield
            if Setting("Party - Shield") and Friend.HP < Setting("Party - Shield Percent") and not Buff.PowerWordShield:Exist(Friend) and not Debuff.WeakenedSoul:Exist(Friend) then
                if smartRecast("PowerWordShield",Friend) then FiveSecondRuleTime = DMW.Time return true end
            end
        end
    end
end

--------------
---DPS Code---
--------------
local function DPS()
    --Shadow Word Pain Spread
    if Setting("Shadow Word: Pain") then
        for _, Unit in ipairs(Player40Y) do
            if Debuff.ShadowWordPain:Refresh(Unit) and (Unit.TTD - Debuff.ShadowWordPain:Remain(Unit)) > 4 or not Debuff.ShadowWordPain:Exist(Unit) then
                if smartRecast("ShadowWordPain",Unit) then FiveSecondRuleTime = DMW.Time
                    return true
                end
            end
        end
    end
    --Holy Fire On Target
    if Setting("Holy Fire") and Spell.HolyFire:IsReady() and Power > Setting("Mana Cut Off") and not Debuff.HolyFire:Exist(Target) then
        if smartRecast("HolyFire",Target) then return true end
    end
    --Mind Blast Cast
    if Setting("Mind Blast") and not MeleeAggro and Power > Setting("Mana Cut Off") and Spell.MindBlast:IsReady() then
        if IsAutoRepeatSpell(Spell.Shoot.SpellName) then
            MoveForwardStart()
            MoveForwardStop()
            ShootTime = DMW.Time
        end
        if Spell.MindBlast:Cast(Target) then FiveSecondRuleTime = DMW.Time return true end
    end
    --Smite Cast
    if Setting("Smite") and not MeleeAggro and Power > Setting("Mana Cut Off") then
        if Spell.Smite:Cast(Target) then FiveSecondRuleTime = DMW.Time return true end
    end
    -- Auto Wand Management
    if not Player.Moving and not IsAutoRepeatSpell(Spell.Shoot.SpellName) and (DMW.Time - ShootTime) > 0.7 then
        if Spell.Shoot:Cast(Target) then
            ShootTime = DMW.Time
            return true
        end
    end
end

local function DEF()
    --Auto Fade
    if Setting("Auto Fade") and MeleeAggro and Friends40YC > 1 and Spell.Fade:IsReady() then
        if Spell.Fade:Cast(Player) then return true end
    end

    --Fortitude Self Check
    if not Buff.PowerWordFortitude:Exist(Player) then 
        if Spell.PowerWordFortitude:Cast(Player) then return true end
    end
    --Inner Fire Self Check
	if Setting("Auto Inner Fire") and not Buff.InnerFire:Exist(Player) then 
        if Spell.InnerFire:Cast(Player) then return true end
    end
    --ShadowGuard Self Check
    if Setting("Auto Shadowguard") and not Buff.Shadowguard:Exist(Player) then
        if Spell.Shadowguard:Cast(Player) then return true end
    end
    --Defensive Renew
    if not Buff.Renew:Exist(Player) and Setting("Renew") and (HP <= Setting("Renew Percent") or (not Player.Combat and HP < 80)) and Power > 15 then
        if Spell.Renew:Cast(Player) then FiveSecondRuleTime = DMW.Time return true end
    end
    --Defensive Lesser Heal
    if Setting("Use Lesser Heal") and HP < Setting("Heal Percent") and Power > 15 then
        if Spell.LesserHeal:Cast(Player) then return true end
    end
    --Defensive Shield
    if Player.Combat and Setting("Power Word: Shield") and HP < Setting("Shield Percent") and Power > 30 and not Debuff.WeakenedSoul:Exist(Player) then
        if Spell.PowerWordShield:Cast(Player) then return true end
    end
end

function Priest.Rotation()
    -- Init Locals
    Locals()
    if Rotation.Active() then
        -----------------
        --Out Of Combat--
        -----------------
        if FiveSecond() then return true end
        --Cast SWP on target, regardless of combat
        if Setting("Pull Spell") and Target and Target.ValidEnemy and not Debuff.ShadowWordPain:Exist(Target) then
            if smartRecast("ShadowWordPain",Target) then
                return true
            end
        end
        --Mind Blast Snipe (WIP)
        for _, Unit in ipairs(Player40Y) do
            if Setting("Mind Blast Snipe") and Unit.TTD <= Setting("Snipe TTD") and not Spell.MindBlast:LastCast() then
                if Spell.MindBlast:Cast(Unit) then FiveSecondRuleTime = DMW.Time return end
            end
        end
        -- Call Defensive Actionlist
        if DEF() then return true end
        -- Call Healing Actionlist
        if HEAL() then return true end
        -----------------
        -----Combat------
        -----------------
        if Player.Combat then
            -- Auto attack if no wand is equipped
            if not DMW.Player.Equipment[18] and not IsCurrentSpell(Spell.Attack.SpellID) then
                StartAttack()
            end
            if Setting("DPS Stuff") then
                -- Auto Target Enemy regardless of target
                if HUD.TargetLock == 1 and UnitIsFriend(Target) then
                    TargetLastEnemy()
                end
                -- Call DPS Actionlist
                if DPS() then
                    return true
                end
            end
        end
    end
end