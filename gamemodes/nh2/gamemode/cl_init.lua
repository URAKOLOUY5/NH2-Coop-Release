-- NIGHTMARE HOUSE 2 PORT TO GMOD
-- Den Urakolouy

include("shared.lua")
include("networks.lua")
include("cl_spawnmenu.lua")
include("cl_notice.lua")
include("cl_hints.lua")
include("cl_worldtips.lua")
include("cl_search_models.lua")
include("cl_hud.lua")

-- Add/Override sounds
sound.AddSoundOverrides("scripts/announcer_soundfiles.txt")
sound.AddSoundOverrides("scripts/captionsample.txt")
sound.AddSoundOverrides("scripts/emily_soundfiles.txt")
sound.AddSoundOverrides("scripts/game_sounds.txt")
sound.AddSoundOverrides("scripts/game_sounds_ambient_generic.txt")
sound.AddSoundOverrides("scripts/game_sounds_weapons.txt")
sound.AddSoundOverrides("scripts/nh2sounds.txt")
sound.AddSoundOverrides("scripts/npc_sounds_nh_guard.txt")
sound.AddSoundOverrides("scripts/npc_sounds_nhdemon.txt")
sound.AddSoundOverrides("scripts/npc_sounds_nhzombie.txt")
sound.AddSoundOverrides("scripts/npc_sounds_stalker.txt")
sound.AddSoundOverrides("scripts/romero_soundfiles.txt")
sound.AddSoundOverrides("scripts/swat_soundfiles.txt")

--
-- Make BaseClass available
--
DEFINE_BASECLASS("gamemode_base")

local physgun_halo = CreateConVar("physgun_halo", "1", {FCVAR_ARCHIVE}, "Draw the physics gun halo?")

CreateClientConVar("nh2coop_cl_playermodel", "", true, true, "Sets player's model")

function GM:Initialize()
    BaseClass.Initialize(self)
end

function GM:LimitHit(name)
    self:AddNotify("#SBoxLimit_" .. name, NOTIFY_ERROR, 6)
    surface.PlaySound("buttons/button10.wav")
end

function GM:OnUndo(name, strCustomString)
    if not strCustomString then
        local str = "#Undone_" .. name
        local translated = language.GetPhrase(str)

        if str == translated then
            -- No translation available, apply our own
            translated = string.format(language.GetPhrase("hint.undoneX"), language.GetPhrase(name))
        else
            -- Try to translate some of this
            local strmatch = string.match(translated, "^Undone (.*)$")

            if strmatch then
                translated = string.format(language.GetPhrase("hint.undoneX"), language.GetPhrase(strmatch))
            end
        end

        self:AddNotify(translated, NOTIFY_UNDO, 2)
    else
        -- This is a hack for SWEPs, etc, to support #translations from server
        local str = string.match(strCustomString, "^Undone (.*)$")

        if str then
            strCustomString = string.format(language.GetPhrase("hint.undoneX"), language.GetPhrase(str))
        end

        self:AddNotify(strCustomString, NOTIFY_UNDO, 2)
    end

    -- Find a better sound :X
    --surface.PlaySound("buttons/button15.wav")
end

function GM:OnCleanup(name)
    self:AddNotify("#Cleaned_" .. name, NOTIFY_CLEANUP, 5)
    -- Find a better sound :X
    --surface.PlaySound("buttons/button15.wav")
end

function GM:UnfrozeObjects(num)
    self:AddNotify(string.format(language.GetPhrase("hint.unfrozeX"), num), NOTIFY_GENERIC, 3)
    -- Find a better sound :X
    --surface.PlaySound("npc/roller/mine/rmine_chirp_answer1.wav")
end

function GM:HUDPaint()
    self:PaintWorldTips()
    -- Draw all of the default stuff
    BaseClass.HUDPaint(self)
    self:PaintNotes()

    NH2_HUD.HUDPaint()
end

function GM:HUDPaintBackground()
    BaseClass.HUDPaintBackground(self)
    
    NH2_HUD.HUDPaintBackground()
end

--
--	Draws on top of VGUI..
--
function GM:PostRenderVGUI()
    BaseClass.PostRenderVGUI(self)
end

local PhysgunHalos = {}

--
--	Name: gamemode:DrawPhysgunBeam()
--	Desc: Return false to override completely
--
function GM:DrawPhysgunBeam(ply, weapon, bOn, target, boneid, pos)
    if physgun_halo:GetInt() == 0 then return true end

    if IsValid(target) then
        PhysgunHalos[ply] = target
    end

    return true
end

hook.Add("PreDrawHalos", "AddPhysgunHalos", function()
    if not PhysgunHalos or table.IsEmpty(PhysgunHalos) then return end

    for k, v in pairs(PhysgunHalos) do
        if not IsValid(k) then continue end
        local size = math.random(1, 2)
        local colr = k:GetWeaponColor() + VectorRand() * 0.3
        halo.Add(PhysgunHalos, Color(colr.x * 255, colr.y * 255, colr.z * 255), size, size, 1, true, false)
    end

    PhysgunHalos = {}
end)

--
--	Name: gamemode:NetworkEntityCreated()
--	Desc: Entity is created over the network
--
function GM:NetworkEntityCreated(ent)
    --
    -- If the entity wants to use a spawn effect
    -- then create a propspawn effect if the entity was
    -- created within the last second (this function gets called
    -- on every entity when joining a server)
    --
    if ent:GetSpawnEffect() and ent:GetCreationTime() > (CurTime() - 1.0) then
        local ed = EffectData()
        ed:SetOrigin(ent:GetPos())
        ed:SetEntity(ent)
        util.Effect("propspawn", ed, true, true)
    end
end

local tohide = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudCrosshair"] = true,
    ["CHudQuickInfo"] = true,
    ["CHudCloseCaption"] = true,
    ["CHudSuitPower"] = true,
    ["CHudSquadStatus"] = true,
}

--
-- Draw element?
--
function GM:HUDShouldDraw(name)
    if not IsValid(LocalPlayer()) then return end

    if tohide[name] then
        return false
    end

    return self.BaseClass.HUDShouldDraw(self, name)
end

local plyMeta = FindMetaTable("Player")

local _HEADLIGHT = NULL
local _HEADLIGHT_POS = Vector(0,0,0)

local offset_light = 0
local offset_light_back = 0
local state_light = false

local FLASHLIGHT_TRACE = {}
local FLASHLIGHT_TRACE_BACK = {}

local forceflicker = CreateClientConVar("r_flashlightforceflicker", "0", false, false)
local flick_time = 0

plyMeta.FlashlightState = function() return state_light end

net.Receive("_NH2_Flashlight", function()
    state_light = net.ReadBool()

    if state_light == false then
        forceflicker:SetBool(false)
    end
end)

net.Receive("_NH2_ForceFlicker", function()
    forceflicker:SetBool(net.ReadBool())
end)

function GM:Think()
    local ply = LocalPlayer()
    local origin = ply:EyePos()
    local angles = ply:EyeAngles()

    FLASHLIGHT_TRACE = util.TraceLine({
        start = LocalPlayer():EyePos(),
        endpos = origin + angles:Forward() * 100,
        filter = function( ent ) return ent ~= LocalPlayer() end
    })

    FLASHLIGHT_TRACE_BACK = util.TraceLine({
        start = LocalPlayer():EyePos(),
        endpos = origin - angles:Forward() * 72,
        filter = function( ent ) return ent ~= LocalPlayer() end
    })

    if state_light == true then
        if not IsValid(_HEADLIGHT) then
            _HEADLIGHT = ProjectedTexture()
            _HEADLIGHT:SetPos(origin)
            _HEADLIGHT:SetAngles(angles)
            _HEADLIGHT:SetFarZ(768)
            _HEADLIGHT:SetFOV(60)
            _HEADLIGHT:SetShadowFilter(2)
            _HEADLIGHT:SetTexture("effects/flashlight001_nh2")
            _HEADLIGHT:Update()
        else
            offset_light = math.floor(math.Remap(math.sqrt(FLASHLIGHT_TRACE.HitPos:DistToSqr(origin)), 4, 100, 100, 4))
            offset_light_back = math.floor(math.Remap(math.sqrt(FLASHLIGHT_TRACE_BACK.HitPos:DistToSqr(origin)), 4, 72, 72, 4))

            if forceflicker:GetBool() then
                if CurTime() > flick_time then
                    if _HEADLIGHT:GetBrightness() == 1 then
                        _HEADLIGHT:SetBrightness(0)
                    else
                        _HEADLIGHT:SetBrightness(1)
                    end
                    flick_time = CurTime() + math.Rand(0.005, 0.35)
                end
            else
                _HEADLIGHT:SetBrightness(1)
            end

            --print("Forward: " .. offset_light)
            --print("Back: " .. offset_light_back)

            if ply:GetViewEntity() == ply then
                _HEADLIGHT:SetPos(origin - angles:Forward() * (offset_light - offset_light_back))
                _HEADLIGHT:SetAngles(angles)
            else
                _HEADLIGHT:SetPos(ply:GetBonePosition(0) + ply:EyeAngles():Forward() * 10)
                _HEADLIGHT:SetAngles(ply:EyeAngles())
            end
            _HEADLIGHT:Update()
        end
    else
        if IsValid(_HEADLIGHT) then
            _HEADLIGHT:SetBrightness(0)
            _HEADLIGHT:Update()
        end
    end
end

net.Receive("_NH2_SendAntiSingleplayer", function()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Message")
    frame:SetSize(500, 100)
    frame:Center()
    frame:MakePopup(true)
    frame:SetDraggable(false)

    function frame:OnClose()
        RunConsoleCommand("disconnect")
    end

    local label = vgui.Create("DLabel", frame)
    label:SetText("There's no sense in playing Nightmare House 2 Coop in Singleplayer mode!\nGo ahead and download mod from Moddb!")
    label:SetPos(40, 40)
    label:SizeToContents()
end)

--
-- Used to control buttons of player and bot (same as server)
--
function GM:StartCommand(ply, cmd)
    if bit.bor(cmd:GetButtons(), IN_ATTACK) ~= 0 then
        local tr = util.TraceLine( {
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:EyeAngles():Forward() * 8192,
            filter = function( ent ) return ( ent ~= ply ) end
        } )

        if tr.Hit and (tr.Entity:IsNPC() and (tr.Entity:GetClass() == "npc_citizen" or tr.Entity:GetClass() == "generic_actor") and not tr.Entity:GetNWBool("NH2COOP_IM_CRAZY_NOW", false)) or tr.Entity:IsPlayer() then
            ply.PointingAlly = true
            cmd:RemoveKey(IN_ATTACK)
        else
            ply.PointingAlly = false
        end
    end
end

--
--
--
function GM:HUDDrawTargetID()
end


--
--
--
function GM:DrawDeathNotice( x, y )
end

--
--
--
function GM:PlayerTick(ply, mv)
    if ply:GetViewEntity() ~= ply then
        ply:AddEffects(EF_NODRAW)
    else
        ply:RemoveEffects(EF_NODRAW)
    end
end