-- ==========================================
-- GR33D PANEL — FULL UPDATED
-- Features:
--   🛡 Anti Exploiter (snap-back + joint rebuild + actuator cleanup)
--   🔒 Position Lock (invisible ForceField shield + absolute freeze)
--   💀 Immortal Mode
--   🪂 No Fall Damage
--   👾 Anti Monster
--   🌙 AFK Streak
--   ✈️ Flight Mode + Noclip + Speed + TP buttons
-- ==========================================
getgenv().NoclipActive         = false
getgenv().AntiFlingActive      = false
getgenv().AntiExploitActive    = false
getgenv().AbsoluteActive       = false
getgenv().AISkyWalkActive      = false
getgenv().ImmortalActive       = false
getgenv().NoFallDamageActive   = false
getgenv().AFKStreakActive      = false
getgenv().PositionLockActive   = false

AI_isSkyWalking = false

local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local CollectionService   = game:GetService("CollectionService")

local player = Players.LocalPlayer
local protectedParent = player:WaitForChild("PlayerGui")
if protectedParent:FindFirstChild("DevPanelGui") then
    protectedParent.DevPanelGui:Destroy()
end

local camera = workspace.CurrentCamera

-- ==========================================
-- STRICT BODY PART DETECTION
-- ==========================================
local BODY_PART_NAMES = {
    HumanoidRootPart = true, Head = true,
    UpperTorso = true, LowerTorso = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
    LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
    RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
    Torso = true, ["Left Arm"] = true, ["Right Arm"] = true,
    ["Left Leg"] = true, ["Right Leg"] = true,
}

local function isOurBodyPart(inst)
    if typeof(inst) ~= "Instance" or not inst:IsA("BasePart") then return false end
    local char = player.Character
    if not char then return false end
    if inst.Parent ~= char then return false end
    return BODY_PART_NAMES[inst.Name] == true
end

local function hasBodyPartAncestor(inst)
    if typeof(inst) ~= "Instance" then return false end
    local cur = inst
    local safety = 0
    while cur and cur ~= workspace and safety < 20 do
        if isOurBodyPart(cur) then return true end
        cur = cur.Parent
        safety = safety + 1
    end
    return false
end

local function isOurHumanoid(inst)
    if typeof(inst) ~= "Instance" or not inst:IsA("Humanoid") then return false end
    local char = player.Character
    if not char then return false end
    return char:FindFirstChildOfClass("Humanoid") == inst
end

local function isOurCharModel(inst)
    return typeof(inst) == "Instance" and inst == player.Character
end

local function isOurBodyJoint(inst)
    if typeof(inst) ~= "Instance" then return false end
    if not (inst:IsA("Motor6D") or inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Snap")) then
        return false
    end
    local char = player.Character
    if not char then return false end
    if not inst:IsDescendantOf(char) then return false end
    if not inst.Part0 or not inst.Part1 then return false end
    return isOurBodyPart(inst.Part0) and isOurBodyPart(inst.Part1)
end

-- ==========================================
-- METATABLE HOOK — METHOD CALLS ONLY
-- ==========================================
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall

    mt.__namecall = newcclosure(function(self, ...)
        if not getgenv().AbsoluteActive then return oldNamecall(self, ...) end
        if checkcaller and checkcaller() then return oldNamecall(self, ...) end

        local method = getnamecallmethod()

        if method == "Kick" or method == "kick" then
            if self == player then return end
            return oldNamecall(self, ...)
        end

        if method ~= "TakeDamage" and method ~= "BreakJoints" and method ~= "ChangeState"
           and method ~= "SetStateEnabled" and method ~= "SetNetworkOwner"
           and method ~= "PivotTo" and method ~= "SetPrimaryPartCFrame"
           and method ~= "Destroy" and method ~= "Remove"
           and method ~= "ClearAllChildren" and method ~= "MoveTo"
           and method ~= "ScaleTo" and method ~= "ApplyImpulse"
           and method ~= "ApplyAngularImpulse" then
            return oldNamecall(self, ...)
        end

        if typeof(self) ~= "Instance" then return oldNamecall(self, ...) end
        local char = player.Character
        if not char then return oldNamecall(self, ...) end
        if self ~= char and not self:IsDescendantOf(char) then return oldNamecall(self, ...) end

        if method == "Destroy" or method == "Remove" then
            if isOurBodyPart(self) then return end
            if isOurHumanoid(self) then return end
            if isOurBodyJoint(self) then return end
            if isOurCharModel(self) then return end
        end
        if method == "ClearAllChildren" and isOurCharModel(self) then return end
        if method == "BreakJoints" and isOurCharModel(self) then return end
        if method == "TakeDamage" and isOurHumanoid(self) then return end
        if method == "ChangeState" and isOurHumanoid(self) then
            local state = ...
            if state == Enum.HumanoidStateType.Dead
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown then
                return
            end
        end
        if method == "SetStateEnabled" and isOurHumanoid(self) then
            local state, enabled = ...
            if enabled and (state == Enum.HumanoidStateType.Dead
                            or state == Enum.HumanoidStateType.Ragdoll
                            or state == Enum.HumanoidStateType.Physics
                            or state == Enum.HumanoidStateType.PlatformStanding
                            or state == Enum.HumanoidStateType.FallingDown) then
                return
            end
        end
        if method == "SetNetworkOwner" then
            if isOurBodyPart(self) or isOurHumanoid(self) then
                local target = ...
                if target ~= player and target ~= nil then return end
            end
        end
        if (method == "PivotTo" or method == "SetPrimaryPartCFrame") and isOurCharModel(self) then
            return
        end
        if method == "MoveTo" and isOurHumanoid(self) then return end
        if method == "ScaleTo" and isOurCharModel(self) then return end
        if (method == "ApplyImpulse" or method == "ApplyAngularImpulse") and isOurBodyPart(self) then
            return
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end)

-- ==========================================
-- UI SIZING
-- ==========================================
local isMobile = UserInputService.TouchEnabled

local function computePanelSize()
    local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    local w, h
    if isMobile then
        w = math.clamp(math.floor(vp.X * 0.72), 180, 220)
        h = math.clamp(math.floor(vp.Y * 0.70), 300, 460)
    else
        w = math.clamp(math.floor(vp.X * 0.35), 220, 260)
        h = math.clamp(math.floor(vp.Y * 0.75), 400, 520)
    end
    return w, h
end

local PANEL_W, PANEL_H = computePanelSize()
local MINIMIZED_SIZE = isMobile and 56 or 44

local function computeStartPosition()
    local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    local margin = 12
    local xOffset = -(PANEL_W + margin)
    local xScale = 1
    if isMobile and (PANEL_W > vp.X * 0.5) then
        xScale = 0.5
        xOffset = -PANEL_W / 2
    end
    local yScale = 0.5
    local yOffset = -PANEL_H / 2
    local yAbs = yScale * vp.Y + yOffset
    if yAbs < margin then
        yScale, yOffset = 0, margin
    elseif yAbs + PANEL_H > vp.Y - margin then
        yScale, yOffset = 0, vp.Y - PANEL_H - margin
    end
    return UDim2.new(xScale, xOffset, yScale, yOffset)
end

-- ==========================================
-- CONFIG
-- ==========================================
local FLY_SPEED          = 50
local runSpeedValue      = 50
local DOUBLE_TAP_WINDOW  = 0.35

local MAX_SPEED             = 800
local MAX_ANGULAR           = 200
local SMOOTHING_FACTOR      = 0.35

local IMMORTAL_MAX_HEALTH = 100000
local IMMORTAL_TARGET_HP  = 95000

local FALL_MAX_DOWN_VEL   = -45
local FALL_RECENT_WINDOW  = 2.5

local AFK_ACTIVITY_INTERVAL  = 18
local AFK_POSITION_TOLERANCE = 3
local AFK_PULSE_DURATION     = 0.15
local AFK_MAX_VEL_FOR_SNAP   = 500

local AE_SNAP_DELTA          = 25
local AE_SNAP_UP_VELOCITY    = 200
local AE_SNAP_HEIGHT_ABOVE   = 40
local AE_SAFE_UPDATE_VEL_MAX = 60
local AE_SAFE_UPDATE_WAIT    = 0.4
local AE_SNAP_COOLDOWN       = 0.8

-- ==========================================
-- POSITION LOCK STATE
-- ==========================================
local LOCK_enabled = false
local LOCK_cframe  = nil
local LOCK_shield  = nil
local LOCK_forceField = nil

local LOCK_SHIELD_SIZE = 6

local function LOCK_createShield()
    if not character or not rootPart then return end

    if LOCK_shield and LOCK_shield.Parent then LOCK_shield:Destroy() end
    if LOCK_forceField and LOCK_forceField.Parent then LOCK_forceField:Destroy() end

    -- Primary: ForceField (invisible damage blocker — same as game spawn shield)
    LOCK_forceField = Instance.new("ForceField")
    LOCK_forceField.Name = "PositionLock_ForceField"
    LOCK_forceField.Visible = false
    LOCK_forceField.Parent = character

    -- Backup: invisible CanCollide shell (blocks physical touch from objects)
    local shell = Instance.new("Part")
    shell.Name = "PositionLock_Shell"
    shell.Shape = Enum.PartType.Ball
    shell.Size = Vector3.new(LOCK_SHIELD_SIZE, LOCK_SHIELD_SIZE, LOCK_SHIELD_SIZE)
    shell.Material = Enum.Material.ForceField
    shell.Color = Color3.fromRGB(80, 180, 255)
    shell.Transparency = 1
    shell.Anchored = false
    shell.CanCollide = false
    shell.CanTouch = false
    shell.CanQuery = false
    shell.Massless = true
    shell.CastShadow = false
    shell.TopSurface = Enum.SurfaceType.Smooth
    shell.BottomSurface = Enum.SurfaceType.Smooth
    shell.Parent = character

    local weld = Instance.new("Weld")
    weld.Name = "PositionLock_ShellWeld"
    weld.Part0 = rootPart
    weld.Part1 = shell
    weld.C0 = CFrame.new(0, 0, 0)
    weld.C1 = CFrame.new(0, 0, 0)
    weld.Parent = shell

    LOCK_shield = shell
end

local function LOCK_removeShield()
    if LOCK_shield and LOCK_shield.Parent then LOCK_shield:Destroy() end
    if LOCK_forceField and LOCK_forceField.Parent then LOCK_forceField:Destroy() end
    LOCK_shield = nil
    LOCK_forceField = nil
end

local AE_autoImmortal      = false
local immortalToggleSetter = nil

local AI_DANGER_DIST = 15
local AI_ESCAPE_DIST = 15
local AI_HEIGHT      = 15
local AI_LIFT_COOLDOWN = 1.0

local AI_FRIENDLY_KEYWORDS = {
    "shop","vendor","merchant","quest","trainer","citizen","dummy",
    "training","blacksmith","healer","safezone","companion","pet",
    "npc","friendly","neutral","passive","decoration","prop","statue"
}
local AI_HOSTILE_NAME_HINTS = {
    "guard","enemy","monster","boss","zombie","hunter","chaser",
    "killer","brute","mutant","beast","demon","raider","bandit",
    "reaper","stalker","fiend","wraith","predator","assassin","slayer"
}
local AI_HOSTILE_TAGS = {
    "AI","Enemy","Hostile","Monster","Guard","NPC_Hostile",
    "Chaser","Aggro","Boss","Mob","Zombie","Killer","Hunter"
}
local AI_HOSTILE_ATTRIBUTES = {
    "AIState","State","Aggro","IsAggro","Hostile","InCombat",
    "IsHostile","IsEnemy","Enemy","Attacking","Target"
}
local AI_HOSTILE_ATTR_VALUES = {
    "chase","chasing","attack","attacking","aggro","aggressive",
    "hostile","hunt","hunting","combat","pursue","seek","follow","target"
}
local AI_FRIENDLY_CONTAINER_NAMES = {
    "friendly","friendlies","neutrals","neutral","npcs","npc",
    "peaceful","passive","citizens","villagers","shops","npcs_safe",
    "decorations","props"
}
local AI_FRIENDLY_TAGS = {
    "Friendly","Neutral","NPC","Shop","Quest","Passive","NonHostile"
}

local AI_groundY       = 0
local AI_linearVel     = nil
local AI_bodyPos       = nil
local AI_attachment    = nil
local AI_registry      = setmetatable({}, {__mode = "k"})
local AI_registryBuilt = false
local AI_lastDropTime  = 0
local AI_descConn      = nil

local flyToggleEnabled    = false
local isFlying            = false
local godModeEnabled      = false
local noFallDamageEnabled = false
local runSpeedEnabled     = false
local antiFlingEnabled    = false
local antiTrapEnabled     = false
local afkStreakEnabled    = false
local isMinimized         = false
local isTeleporting       = false

local lastJumpTapTime     = 0
local lastJumpReqTime     = 0
local savedMapCFrame      = nil

local AFK_lockedPosition  = nil
local AFK_lastActivity    = 0

local character, rootPart, humanoid
local attachment, linearVelocity

local controls = nil
pcall(function()
    local playerScripts = player:WaitForChild("PlayerScripts", 5)
    if playerScripts then
        local playerModuleScript = playerScripts:WaitForChild("PlayerModule", 5)
        if playerModuleScript then
            local PlayerModule = require(playerModuleScript)
            controls = PlayerModule:GetControls()
        end
    end
end)

-- ==========================================
-- POSITION LOCK ENGINE
-- ==========================================
local function LOCK_apply()
    if not LOCK_enabled or not LOCK_cframe then return end
    if not character or not rootPart then return end

    if not LOCK_shield or not LOCK_shield.Parent then
        LOCK_createShield()
    end

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and BODY_PART_NAMES[part.Name] then
            if not part.Anchored then
                pcall(function() part.Anchored = true end)
            end
        end
    end

    local delta = (rootPart.Position - LOCK_cframe.Position).Magnitude
    if delta > 0.1 then
        pcall(function() rootPart.CFrame = LOCK_cframe end)
    end

    pcall(function()
        rootPart.AssemblyLinearVelocity  = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and BODY_PART_NAMES[part.Name] then
            if part.AssemblyLinearVelocity.Magnitude > 0 then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end
end

local function LOCK_release()
    if not character then return end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and BODY_PART_NAMES[part.Name] then
            pcall(function() part.Anchored = false end)
        end
    end
    if rootPart then
        pcall(function()
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==========================================
-- AE CLEANUP
-- ==========================================
local AE_EXCLUDED_ACTUATOR_NAMES = {
    FlightVelocity = true,
    FlightAttachment = true,
    AI_SkyWalk_Vel = true,
    AI_SkyWalk_Pos = true,
    AI_SkyWalk_Attachment = true,
}

local function AE_isForeignActuator(d)
    if AE_EXCLUDED_ACTUATOR_NAMES[d.Name] then return false end
    if d:IsA("BodyMover") then return true end
    if d:IsA("LinearVelocity") then return true end
    if d:IsA("AngularVelocity") then return true end
    if d:IsA("AlignPosition") then return true end
    if d:IsA("AlignOrientation") then return true end
    if d:IsA("VectorForce") then return true end
    if d:IsA("Torque") then return true end
    if d:IsA("RopeConstraint") then return true end
    if d:IsA("RodConstraint") then return true end
    if d:IsA("SpringConstraint") then return true end
    return false
end

local function AE_forceCleanup()
    if not character then return end
    local removed = 0

    pcall(function()
        if humanoid then humanoid:UnequipTools() end
    end)

    for _, d in ipairs(character:GetDescendants()) do
        if AE_isForeignActuator(d) then
            d:Destroy()
            removed = removed + 1
        end
    end

    if player.Backpack then
        for _, d in ipairs(player.Backpack:GetDescendants()) do
            if AE_isForeignActuator(d) then
                d:Destroy()
                removed = removed + 1
            end
        end
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("RopeConstraint") or d:IsA("RodConstraint") or d:IsA("SpringConstraint") then
            local a0 = d.Attachment0
            local a1 = d.Attachment1
            local a0Ours = a0 and hasBodyPartAncestor(a0)
            local a1Ours = a1 and hasBodyPartAncestor(a1)
            if (a0Ours and not a1Ours) or (a1Ours and not a0Ours) then
                d:Destroy()
                removed = removed + 1
            end
        end
    end

    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
            local p0 = d.Part0
            local p1 = d.Part1
            if p0 and p1 then
                local p0Ours = isOurBodyPart(p0)
                local p1Ours = isOurBodyPart(p1)
                if (p0Ours and not p1Ours) or (p1Ours and not p0Ours) then
                    local foreignPart = p0Ours and p1 or p0
                    if foreignPart and foreignPart.Parent ~= character then
                        d:Destroy()
                        removed = removed + 1
                    end
                end
            end
        end
    end

    return removed
end

local function AE_hasGameActuator()
    if not character then return false end
    for _, d in ipairs(character:GetDescendants()) do
        if AE_isForeignActuator(d) then return true end
    end
    return false
end

-- ==========================================
-- AE RECOVERY
-- ==========================================
local function AE_sendMovementPulse()
    if not humanoid or not humanoid.Parent then return end
    task.spawn(function()
        for i = 1, 3 do
            pcall(function()
                if humanoid and humanoid.Parent then
                    humanoid:Move(Vector3.new(0.05, 0, 0.05), false)
                end
            end)
            task.wait(0.1)
            pcall(function()
                if humanoid and humanoid.Parent then
                    humanoid:Move(Vector3.zero, false)
                end
            end)
            task.wait(0.1)
        end
    end)
end

local function AE_fullRecovery()
    if not character or not humanoid or not rootPart then return end

    local removed = AE_forceCleanup()

    pcall(function()
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.BreakJointsOnDeath = false
    end)

    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)

    pcall(function()
        if rootPart.Anchored and not LOCK_enabled then rootPart.Anchored = false end
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    pcall(function()
        if rootPart:GetNetworkOwner() ~= player then
            rootPart:SetNetworkOwner(player)
        end
    end)

    pcall(function()
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)

    task.delay(0.2, function()
        if humanoid and humanoid.Parent then
            pcall(function()
                if humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                else
                    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end
            end)
        end
    end)

    AE_sendMovementPulse()

    if camera and humanoid then
        pcall(function()
            camera.CameraSubject = humanoid
            camera.CameraType = Enum.CameraType.Custom
        end)
    end

    print(("[AE Recovery] Cleaned %d foreign object(s)"):format(removed))
end

-- ==========================================
-- ANTI MONSTER
-- ==========================================
local function AI_nameHasAny(name, list)
    if not name then return false end
    name = name:lower()
    for _, kw in ipairs(list) do
        if name:find(kw, 1, true) then return true end
    end
    return false
end

local function AI_inFriendlyContainer(model)
    local p = model.Parent
    local depth = 0
    while p and p ~= workspace and depth < 8 do
        if AI_nameHasAny(p.Name, AI_FRIENDLY_CONTAINER_NAMES) then return true end
        p = p.Parent
        depth = depth + 1
    end
    return false
end

local function AI_hasHostileAttribute(model)
    for _, attrName in ipairs(AI_HOSTILE_ATTRIBUTES) do
        local val = model:GetAttribute(attrName)
        if val ~= nil then
            if val == true then return true end
            if type(val) == "string" then
                local vl = val:lower()
                for _, kw in ipairs(AI_HOSTILE_ATTR_VALUES) do
                    if vl:find(kw, 1, true) then return true end
                end
            end
        end
    end
    return false
end

local function AI_hasHostileTag(model)
    for _, tag in ipairs(AI_FRIENDLY_TAGS) do
        if CollectionService:HasTag(model, tag) then return false end
    end
    for _, tag in ipairs(AI_HOSTILE_TAGS) do
        if CollectionService:HasTag(model, tag) then return true end
    end
    return false
end

local function AI_targetsUs(model, myChar)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ObjectValue") then
            local n = d.Name:lower()
            if n:find("target") or n:find("enemy") or n:find("aggro") then
                local v = d.Value
                if v == myChar or v == myChar:FindFirstChild("Humanoid") or v == myChar:FindFirstChild("HumanoidRootPart") then
                    return true
                end
            end
        end
    end
    return false
end

local function AI_hasHostileScript(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then
            local n = d.Name:lower()
            local matches = 0
            for _, kw in ipairs({"chase","aggro","attack","combat",
                                 "monster","enemy","hostile","hunt",
                                 "pursue","kill","damage"}) do
                if n:find(kw, 1, true) then
                    matches = matches + 1
                    if matches >= 2 then return true end
                end
            end
        end
    end
    return false
end

local function AI_isHostile(model)
    if not model or not model:IsA("Model") then return false end
    if model == character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then return false end
    if AI_inFriendlyContainer(model) then return false end

    for _, tag in ipairs(AI_FRIENDLY_TAGS) do
        if CollectionService:HasTag(model, tag) then
            if not AI_hasHostileTag(model) then return false end
        end
    end

    if AI_nameHasAny(model.Name, AI_FRIENDLY_KEYWORDS) then
        if not AI_nameHasAny(model.Name, AI_HOSTILE_NAME_HINTS) then return false end
    end

    local signals = 0
    if AI_hasHostileAttribute(model)                    then signals = signals + 1 end
    if AI_hasHostileTag(model)                          then signals = signals + 1 end
    if AI_nameHasAny(model.Name, AI_HOSTILE_NAME_HINTS) then signals = signals + 1 end
    if AI_hasHostileScript(model)                       then signals = signals + 1 end
    if AI_targetsUs(model, character)                   then signals = signals + 1 end

    return signals >= 1
end

local function AI_getModelPos(model)
    local ok, pivot = pcall(function() return model:GetPivot() end)
    if ok and pivot then return pivot.Position end
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("RootPart") or model:FindFirstChild("Head")
    return root and root.Position or nil
end

local function AI_register(model)
    if not model or not model:IsA("Model") then return end
    if AI_registry[model] ~= nil then return end
    AI_registry[model] = AI_isHostile(model)
end

local function AI_scanWorkspace()
    local count = 0
    local hostileCount = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
            count = count + 1
            AI_register(d)
            if AI_registry[d] then hostileCount = hostileCount + 1 end
        end
    end
    AI_registryBuilt = true
    print(("[Anti Monster] Registry built: %d models scanned, %d hostiles"):format(count, hostileCount))
end

-- ==========================================
-- ANTI MONSTER — SKY-WALK
-- ==========================================
local function AI_setNoclip(state)
    if not character then return end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and BODY_PART_NAMES[part.Name] then
            if state then
                part.CanCollide = false
            else
                if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso"
                or part.Name == "LowerTorso" or part.Name == "Torso" then
                    part.CanCollide = true
                else
                    part.CanCollide = false
                end
            end
        end
    end
end

local function AI_startSkyWalk()
    if not character or not rootPart or not humanoid then return end
    if AI_isSkyWalking then return end

    AI_groundY = rootPart.Position.Y
    AI_isSkyWalking = true

    pcall(function()
        humanoid.PlatformStand = true
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)

    AI_setNoclip(true)
    rootPart.CFrame = CFrame.new(rootPart.Position.X, AI_groundY + AI_HEIGHT, rootPart.Position.Z)

    if AI_attachment then AI_attachment:Destroy() end
    AI_attachment = Instance.new("Attachment")
    AI_attachment.Name = "AI_SkyWalk_Attachment"
    AI_attachment.Parent = rootPart

    AI_linearVel = Instance.new("LinearVelocity")
    AI_linearVel.Name = "AI_SkyWalk_Vel"
    AI_linearVel.MaxForce = math.huge
    AI_linearVel.VectorVelocity = Vector3.zero
    AI_linearVel.Attachment0 = AI_attachment
    AI_linearVel.Parent = rootPart

    AI_bodyPos = Instance.new("BodyPosition")
    AI_bodyPos.Name = "AI_SkyWalk_Pos"
    AI_bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
    AI_bodyPos.P = 10000
    AI_bodyPos.D = 1000
    AI_bodyPos.Position = Vector3.new(rootPart.Position.X, AI_groundY + AI_HEIGHT, rootPart.Position.Z)
    AI_bodyPos.Parent = rootPart

    print("[Anti Monster] LIFTING 15 STUDS")
end

local function AI_endSkyWalk()
    if not AI_isSkyWalking then return end
    AI_isSkyWalking = false

    if AI_linearVel then AI_linearVel:Destroy() AI_linearVel = nil end
    if AI_bodyPos then AI_bodyPos:Destroy() AI_bodyPos = nil end
    if AI_attachment then AI_attachment:Destroy() AI_attachment = nil end

    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {character}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(rootPart.Position + Vector3.new(0, 10, 0), Vector3.new(0, -500, 0), rp)
    local landY = res and (res.Position.Y + 3.5) or AI_groundY

    rootPart.CFrame = CFrame.new(rootPart.Position.X, landY, rootPart.Position.Z)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    pcall(function()
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)

    task.wait(0.1)
    AI_setNoclip(false)
    AI_lastDropTime = tick()
    print("[Anti Monster] DROPPING DOWN")
end

local function AI_tick()
    if not getgenv().AISkyWalkActive then return end
    if not character or not rootPart or not humanoid then return end
    if not AI_registryBuilt then return end

    if AI_isSkyWalking and AI_linearVel and AI_bodyPos then
        AI_setNoclip(true)
        humanoid.PlatformStand = true
        AI_linearVel.VectorVelocity = humanoid.MoveDirection * humanoid.WalkSpeed
        AI_bodyPos.Position = Vector3.new(rootPart.Position.X, AI_groundY + AI_HEIGHT, rootPart.Position.Z)
    end

    if humanoid.Health <= 0 then
        if AI_isSkyWalking then AI_endSkyWalk() end
        return
    end

    local myPos = rootPart.Position
    local myPosXZ = Vector3.new(myPos.X, 0, myPos.Z)
    local closest3D, closestXZ = math.huge, math.huge

    for model in pairs(AI_registry) do
        if AI_registry[model] == true then
            if model.Parent then
                local hum2 = model:FindFirstChildOfClass("Humanoid")
                if hum2 and hum2.Health > 0 then
                    local p = AI_getModelPos(model)
                    if p then
                        local d3D = (myPos - p).Magnitude
                        local dXZ = (myPosXZ - Vector3.new(p.X, 0, p.Z)).Magnitude
                        if dXZ < closestXZ then closest3D, closestXZ = d3D, dXZ end
                    end
                else
                    AI_registry[model] = nil
                end
            else
                AI_registry[model] = nil
            end
        end
    end

    if not AI_isSkyWalking then
        if closest3D <= AI_DANGER_DIST and (tick() - AI_lastDropTime) > AI_LIFT_COOLDOWN then
            AI_startSkyWalk()
        end
    else
        if closestXZ >= AI_ESCAPE_DIST then AI_endSkyWalk() end
    end
end

local function AI_connectRegistry()
    if AI_descConn then return end
    AI_descConn = workspace.DescendantAdded:Connect(function(d)
        if not getgenv().AISkyWalkActive then return end
        if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
            task.defer(AI_register, d)
        end
    end)
end

local function AI_disconnectRegistry()
    if AI_descConn then AI_descConn:Disconnect() AI_descConn = nil end
end

local function AI_start()
    if not AI_registryBuilt then task.spawn(AI_scanWorkspace) end
    AI_connectRegistry()
    print("[Anti Monster] ENABLED")
end

local function AI_stop()
    if AI_isSkyWalking then AI_endSkyWalk() end
    AI_disconnectRegistry()
    AI_registryBuilt = false
    AI_registry = setmetatable({}, {__mode = "k"})
    print("[Anti Monster] DISABLED")
end

-- ==========================================
-- ANTI EXPLOITER — SNAP-BACK ENGINE
-- ==========================================
local AE_safePos         = nil
local AE_safeGroundY     = nil
local AE_lastFramePos    = nil
local AE_lastSnapTime    = 0
local AE_suspicionTime   = 0
local AE_ownerCounter    = 0

local function AE_canGuard()
    if not getgenv().AntiExploitActive then return false end
    if getgenv().NoclipActive or isTeleporting or AI_isSkyWalking then return false end
    if isFlying then return false end
    if AE_hasGameActuator() then return false end
    return true
end

local function AE_snapBack(reason)
    if not rootPart or not AE_safePos then return end
    if LOCK_enabled then return end
    if tick() - AE_lastSnapTime < AE_SNAP_COOLDOWN then return end

    local rot = rootPart.CFrame - rootPart.CFrame.Position
    rootPart.CFrame = CFrame.new(AE_safePos) * rot
    rootPart.AssemblyLinearVelocity  = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    AE_lastFramePos = rootPart.Position
    AE_lastSnapTime = tick()
    AE_suspicionTime = tick()

    print(("[AE Snap-back] %s — returned to safe spot"):format(reason or "attack"))
end

local function AE_guardPhysics()
    if not AE_canGuard() then
        AE_lastFramePos = rootPart.Position
        return
    end

    local pos = rootPart.Position
    local vel = rootPart.AssemblyLinearVelocity

    local suspicious = false
    local reason = nil

    if AE_lastFramePos then
        local delta = (pos - AE_lastFramePos).Magnitude
        if delta > AE_SNAP_DELTA then
            suspicious = true
            reason = ("teleport (%.0f studs)"):format(delta)
        end
    end

    if not suspicious and vel.Y > AE_SNAP_UP_VELOCITY then
        suspicious = true
        reason = ("sky fling (%.0f studs/s up)"):format(vel.Y)
    end

    if not suspicious and AE_safeGroundY and pos.Y > AE_safeGroundY + AE_SNAP_HEIGHT_ABOVE then
        suspicious = true
        reason = ("%.0f studs above ground"):format(pos.Y - AE_safeGroundY)
    end

    if suspicious then
        AE_snapBack(reason)
        return
    end

    local calm = vel.Magnitude < AE_SAFE_UPDATE_VEL_MAX
    if calm and (tick() - AE_suspicionTime) > AE_SAFE_UPDATE_WAIT then
        AE_safePos = pos
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            AE_safeGroundY = pos.Y
        end
    end

    if vel.Magnitude > 2500 then
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
    if rootPart.AssemblyAngularVelocity.Magnitude > 200 then
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    AE_lastFramePos = rootPart.Position
end

local function AE_enforceState()
    if not getgenv().AntiExploitActive then return end
    if getgenv().NoclipActive or AI_isSkyWalking then return end
    if humanoid.BreakJointsOnDeath then humanoid.BreakJointsOnDeath = false end
    if humanoid.PlatformStand then humanoid.PlatformStand = false end
    if humanoid.Sit then humanoid.Sit = false end

    if rootPart.Anchored and not AE_hasGameActuator() and not isTeleporting and not LOCK_enabled then
        rootPart.Anchored = false
    end

    local st = humanoid:GetState()
    if st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Ragdoll
    or st == Enum.HumanoidStateType.FallingDown then
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

local function AE_reclaimOwnership()
    if not rootPart then return end
    if LOCK_enabled then return end
    if rootPart.AssemblyLinearVelocity.Magnitude > 80 then return end
    if AE_hasGameActuator() then return end
    local st = humanoid and humanoid:GetState()
    if st == Enum.HumanoidStateType.Freefall
    or st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Climbing then
        return
    end
    pcall(function()
        if rootPart:GetNetworkOwner() ~= player then
            rootPart:SetNetworkOwner(player)
        end
    end)
end

-- ==========================================
-- AFK STREAK
-- ==========================================
local function AFK_tick()
    if not afkStreakEnabled then return end
    if not character or not rootPart or not humanoid then return end
    if isFlying or isTeleporting or AI_isSkyWalking or LOCK_enabled then
        AFK_lockedPosition = rootPart.Position
        return
    end
    if humanoid.MoveDirection.Magnitude > 0 then
        AFK_lockedPosition = rootPart.Position
        return
    end
    if rootPart.AssemblyLinearVelocity.Magnitude > AFK_MAX_VEL_FOR_SNAP then
        AFK_lockedPosition = rootPart.Position
        return
    end

    if AFK_lockedPosition then
        local currentPos = rootPart.Position
        local delta = (currentPos - AFK_lockedPosition).Magnitude
        if delta > AFK_POSITION_TOLERANCE then
            local rot = rootPart.CFrame - rootPart.CFrame.Position
            rootPart.CFrame = CFrame.new(AFK_lockedPosition) * rot
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        else
            AFK_lockedPosition = rootPart.Position
        end
    else
        AFK_lockedPosition = rootPart.Position
    end

    if tick() - AFK_lastActivity >= AFK_ACTIVITY_INTERVAL then
        AFK_lastActivity = tick()
        task.spawn(function()
            if not humanoid or not humanoid.Parent then return end
            pcall(function() humanoid:Move(Vector3.new(0, 0, 0.01), false) end)
            task.wait(AFK_PULSE_DURATION)
            if humanoid and humanoid.Parent then
                pcall(function() humanoid:Move(Vector3.zero, false) end)
            end
        end)
    end
end

-- ==========================================
-- IMMORTAL
-- ==========================================
local function immortal_apply()
    if not character or not humanoid then return end
    pcall(function()
        humanoid.MaxHealth = IMMORTAL_MAX_HEALTH
        if humanoid.Health < IMMORTAL_TARGET_HP then humanoid.Health = IMMORTAL_TARGET_HP end
        humanoid.BreakJointsOnDeath = false
    end)
    pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
end

local function immortal_regen()
    if not getgenv().ImmortalActive then return end
    if not character or not humanoid then return end
    pcall(function()
        if humanoid.Health < IMMORTAL_TARGET_HP then humanoid.Health = IMMORTAL_TARGET_HP end
        if humanoid.MaxHealth < IMMORTAL_MAX_HEALTH then humanoid.MaxHealth = IMMORTAL_MAX_HEALTH end
    end)
end

local function immortal_hookHumanoid(hum)
    if not hum then return end
    hum.HealthChanged:Connect(function(newH)
        if getgenv().ImmortalActive and hum == humanoid and newH < IMMORTAL_TARGET_HP then
            pcall(function() hum.Health = IMMORTAL_TARGET_HP end)
        end
    end)
    hum.Died:Connect(function()
        if getgenv().ImmortalActive and hum == humanoid then
            task.defer(function()
                if character and character.Parent then
                    pcall(function()
                        hum.Health = IMMORTAL_TARGET_HP
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
            end)
        end
    end)
end

-- ==========================================
-- NO FALL DAMAGE
-- ==========================================
local lastAirborneTime = 0

local function isAirborneFalling()
    if not humanoid then return false end
    local st = humanoid:GetState()
    if st == Enum.HumanoidStateType.Freefall
    or st == Enum.HumanoidStateType.Jumping
    or st == Enum.HumanoidStateType.FallingDown then
        return true
    end
    if humanoid.FloorMaterial == Enum.Material.Air then return true end
    return false
end

local function fall_capVelocity()
    if not noFallDamageEnabled then return end
    if not rootPart or not humanoid then return end
    if isAirborneFalling() then
        lastAirborneTime = tick()
        local v = rootPart.AssemblyLinearVelocity
        if v.Y < FALL_MAX_DOWN_VEL then
            rootPart.AssemblyLinearVelocity = Vector3.new(v.X, FALL_MAX_DOWN_VEL, v.Z)
        end
    end
end

local function fall_hookHumanoid(hum)
    if not hum then return end
    hum.HealthChanged:Connect(function(newH)
        if not noFallDamageEnabled then return end
        if hum ~= humanoid then return end
        if newH < hum.MaxHealth and (tick() - lastAirborneTime) < FALL_RECENT_WINDOW then
            pcall(function() hum.Health = hum.MaxHealth end)
        end
    end)
end

-- ==========================================
-- UI
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevPanelGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = protectedParent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
mainFrame.Position = computeStartPosition()
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 45, 55)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, 40)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "GR33D Scripts"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -38, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(200, 200, 210)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.Parent = mainFrame
minimizeButton.Active = true
minimizeButton.ZIndex = 10
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 8)

do
    local dragging, dragStart, startPos
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end
    local function moveDrag(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end
    local function endDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end
    titleLabel.InputBegan:Connect(beginDrag)
    titleLabel.InputChanged:Connect(moveDrag)
    titleLabel.InputEnded:Connect(endDrag)
    minimizeButton.InputBegan:Connect(beginDrag)
    minimizeButton.InputChanged:Connect(moveDrag)
    minimizeButton.InputEnded:Connect(endDrag)
end

local toggleContainer = Instance.new("ScrollingFrame")
toggleContainer.Size = UDim2.new(1, 0, 1, -45)
toggleContainer.Position = UDim2.new(0, 0, 0, 45)
toggleContainer.BackgroundTransparency = 1
toggleContainer.BorderSizePixel = 0
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 780)
toggleContainer.ScrollBarThickness = 6
toggleContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
toggleContainer.Parent = mainFrame

local function createToggleRow(name, yPos, callback, defaultOn)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.9, 0, 0, 32)
    row.Position = UDim2.new(0.05, 0, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = toggleContainer

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.72, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local switchBg = Instance.new("TextButton")
    switchBg.Size = UDim2.new(0, 40, 0, 20)
    switchBg.Position = UDim2.new(1, -40, 0.5, -10)
    switchBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    switchBg.Text = ""
    switchBg.AutoButtonColor = false
    switchBg.Parent = row
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
    knob.Parent = switchBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local activeState = defaultOn and true or false

    local function setVisual(state, animate)
        activeState = state
        if state then
            switchBg.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            if animate then
                knob:TweenPosition(UDim2.new(1, -17, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
            else
                knob.Position = UDim2.new(1, -17, 0.5, -7)
            end
        else
            switchBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            if animate then
                knob:TweenPosition(UDim2.new(0, 3, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
            else
                knob.Position = UDim2.new(0, 3, 0.5, -7)
            end
        end
    end

    setVisual(activeState, false)

    switchBg.MouseButton1Click:Connect(function()
        setVisual(not activeState, true)
        pcall(callback, activeState)
    end)

    return row, setVisual
end

local function createInputRow(name, yPos, defaultVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.9, 0, 0, 32)
    row.Position = UDim2.new(0.05, 0, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = toggleContainer

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0, 75, 0, 24)
    textBox.Position = UDim2.new(1, -75, 0.5, -12)
    textBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    textBox.Text = tostring(defaultVal)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.Font = Enum.Font.GothamBold
    textBox.TextSize = 12
    textBox.Parent = row
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 6)

    textBox.FocusLost:Connect(function()
        local num = tonumber(textBox.Text)
        if num then pcall(callback, num) else textBox.Text = tostring(defaultVal) end
    end)
    return row
end

local function createActionButton(name, yPos, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = toggleContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() pcall(callback) end)
    return btn
end

local function absoluteTeleport(targetCFrame)
    if not character or not rootPart then return end
    isTeleporting = true
    if humanoid then
        humanoid.Sit = false
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.Anchored = true
    character:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
    task.delay(0.06, function()
        if rootPart and rootPart.Parent then
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            if not LOCK_enabled then rootPart.Anchored = false end
        end
        if humanoid and humanoid.Parent then
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        isTeleporting = false
    end)
end

local function getEntrySpawn()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") and obj.Enabled then
            return obj.CFrame + Vector3.new(0, 3, 0)
        end
    end
    return rootPart and rootPart.CFrame or CFrame.new(0, 5, 0)
end

local function setFlying(state)
    if not rootPart or not humanoid or not linearVelocity then return end
    if LOCK_enabled then return end
    isFlying = state
    if isFlying then
        linearVelocity.MaxForce = 100000
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
    else
        linearVelocity.MaxForce = 0
        linearVelocity.VectorVelocity = Vector3.zero
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
        end
    end
end

-- ==========================================
-- UI ROWS
-- ==========================================
createToggleRow("Flight Mode", 5, function(state)
    flyToggleEnabled = state
    if not state then setFlying(false) end
end)

local _, immortalSetVisual = createToggleRow("Immortal Mode", 40, function(state)
    godModeEnabled = state
    getgenv().ImmortalActive = state
    if state then
        immortal_apply()
        if humanoid then immortal_hookHumanoid(humanoid) end
    else
        if humanoid then
            pcall(function()
                humanoid.MaxHealth = 100
                humanoid.Health = math.min(humanoid.Health, 100)
            end)
        end
    end
end)
immortalToggleSetter = immortalSetVisual

createToggleRow("No Fall Damage", 75, function(state)
    noFallDamageEnabled = state
    getgenv().NoFallDamageActive = state
end)

createToggleRow("Force Noclip Bypass", 110, function(state)
    getgenv().NoclipActive = state
    if state then
        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
    else
        player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
    end
end)

createToggleRow("Anti-Ragdoll & Anti-Fling", 145, function(state)
    antiFlingEnabled = state
    getgenv().AntiFlingActive = state
    if humanoid then
        if state then
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end)
        else
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            end)
        end
    end
end)

createToggleRow("Anti Trap", 180, function(state)
    antiTrapEnabled = state
end)

createToggleRow("Super Run Speed", 215, function(state)
    runSpeedEnabled = state
end)

createInputRow("Run Speed Value", 250, 50, function(value)
    runSpeedValue = value
end)

createToggleRow("🛡 Anti Exploiter", 285, function(state)
    getgenv().AbsoluteActive = state
    getgenv().AntiExploitActive = state

    if state then
        if not getgenv().ImmortalActive then
            godModeEnabled = true
            getgenv().ImmortalActive = true
            AE_autoImmortal = true
            immortal_apply()
            if humanoid then immortal_hookHumanoid(humanoid) end
            if immortalToggleSetter then immortalToggleSetter(true, true) end
        else
            AE_autoImmortal = false
        end

        AE_safePos        = rootPart and rootPart.Position or nil
        AE_safeGroundY    = rootPart and rootPart.Position.Y or nil
        AE_lastFramePos   = rootPart and rootPart.Position or nil
        AE_suspicionTime  = tick()

        print("[Anti Exploiter] ENABLED")
    else
        if AE_autoImmortal then
            AE_autoImmortal = false
            godModeEnabled = false
            getgenv().ImmortalActive = false
            if humanoid then
                pcall(function()
                    humanoid.MaxHealth = 100
                    humanoid.Health = math.min(humanoid.Health, 100)
                end)
            end
            if immortalToggleSetter then immortalToggleSetter(false, true) end
        end

        AE_safePos = nil
        AE_safeGroundY = nil
        AE_lastFramePos = nil

        AE_fullRecovery()
        task.delay(0.5, function()
            if character and humanoid and humanoid.Parent then pcall(AE_fullRecovery) end
        end)
        task.delay(1.0, function()
            if character and humanoid and humanoid.Parent then pcall(AE_fullRecovery) end
        end)

        print("[Anti Exploiter] DISABLED (recovered)")
    end
end)

createToggleRow("🔒 Position Lock", 320, function(state)
    getgenv().PositionLockActive = state
    if state then
        if not rootPart then return end
        LOCK_cframe = rootPart.CFrame
        LOCK_enabled = true

        pcall(function()
            humanoid.PlatformStand = false
            humanoid.Sit = false
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)

        LOCK_apply()
        LOCK_createShield()

        print(("[Position Lock] LOCKED at X=%.1f Y=%.1f Z=%.1f | 🛡 Invisible shield active"):format(
            LOCK_cframe.Position.X,
            LOCK_cframe.Position.Y,
            LOCK_cframe.Position.Z
        ))
    else
        LOCK_enabled = false
        LOCK_release()
        LOCK_removeShield()
        LOCK_cframe = nil
        print("[Position Lock] UNLOCKED — shield removed")
    end
end)

createToggleRow("👾 Anti Monster", 355, function(state)
    getgenv().AISkyWalkActive = state
    if state then AI_start() else AI_stop() end
end)

createToggleRow("🌙 AFK Streak", 390, function(state)
    afkStreakEnabled = state
    getgenv().AFKStreakActive = state
    if state then
        AFK_lastActivity = tick()
        AFK_lockedPosition = rootPart and rootPart.Position or nil
        print("[AFK Streak] ENABLED")
    else
        AFK_lockedPosition = nil
        print("[AFK Streak] DISABLED")
    end
end)

-- ==========================================
-- ACTION BUTTONS
-- ==========================================
createActionButton("TP to Entry Spawn", 427, Color3.fromRGB(41, 128, 185), function()
    AE_forceCleanup()
    task.wait(0.05)
    absoluteTeleport(getEntrySpawn())
    if rootPart then
        AE_safePos = rootPart.Position
        AE_safeGroundY = rootPart.Position.Y
        AE_lastFramePos = rootPart.Position
        AFK_lockedPosition = rootPart.Position
        if LOCK_enabled then LOCK_cframe = rootPart.CFrame end
    end
end)

local saveMapButton = createActionButton("Save Current Map Location", 464, Color3.fromRGB(142, 68, 173), function()
    if not rootPart then return end
    savedMapCFrame = rootPart.CFrame
    saveMapButton.Text = "Map Location Saved!"
    task.delay(1.5, function() saveMapButton.Text = "Save Current Map Location" end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 501, Color3.fromRGB(39, 174, 96), function()
    if savedMapCFrame then
        AE_forceCleanup()
        task.wait(0.05)
        absoluteTeleport(savedMapCFrame)
        if rootPart then
            AE_safePos = rootPart.Position
            AE_safeGroundY = rootPart.Position.Y
            AE_lastFramePos = rootPart.Position
            AFK_lockedPosition = rootPart.Position
            if LOCK_enabled then LOCK_cframe = rootPart.CFrame end
        end
    else
        tpMapButton.Text = "No Location Saved Yet!"
        task.delay(1.5, function() tpMapButton.Text = "TP to Saved Map Location" end)
    end
end)

-- ==========================================
-- MINIMIZE
-- ==========================================
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
        local pos = mainFrame.AbsolutePosition
        local x = math.clamp(pos.X, 4, math.max(4, vp.X - MINIMIZED_SIZE - 4))
        local y = math.clamp(pos.Y, 4, math.max(4, vp.Y - MINIMIZED_SIZE - 4))
        mainFrame.Position = UDim2.new(0, x, 0, y)
        mainFrame.Size = UDim2.new(0, MINIMIZED_SIZE, 0, MINIMIZED_SIZE)
        toggleContainer.Visible = false
        titleLabel.Visible = false
        stroke.Transparency = 0.5
        minimizeButton.Size = UDim2.new(1, 0, 1, 0)
        minimizeButton.Position = UDim2.new(0, 0, 0, 0)
        minimizeButton.Text = "+"
        minimizeButton.TextSize = math.floor(MINIMIZED_SIZE * 0.5)
    else
        local w, h = computePanelSize()
        PANEL_W, PANEL_H = w, h
        mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
        toggleContainer.Visible = true
        titleLabel.Visible = true
        stroke.Transparency = 0
        minimizeButton.Size = UDim2.new(0, 30, 0, 30)
        minimizeButton.Position = UDim2.new(1, -38, 0, 5)
        minimizeButton.Text = "-"
        minimizeButton.TextSize = 18
        local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
        local pos = mainFrame.AbsolutePosition
        local x = math.clamp(pos.X, 4, math.max(4, vp.X - PANEL_W - 4))
        local y = math.clamp(pos.Y, 4, math.max(4, vp.Y - PANEL_H - 4))
        mainFrame.Position = UDim2.new(0, x, 0, y)
    end
end)

-- ==========================================
-- FLIGHT / JUMP TAP
-- ==========================================
local function handleJumpTap()
    if not flyToggleEnabled then return end
    if LOCK_enabled then return end
    local currentTime = os.clock()
    if (currentTime - lastJumpTapTime) <= DOUBLE_TAP_WINDOW then
        if isFlying then setFlying(false)
        elseif humanoid and (humanoid:GetState() == Enum.HumanoidStateType.Freefall
                          or humanoid:GetState() == Enum.HumanoidStateType.Jumping) then
            setFlying(true)
        end
        lastJumpTapTime = 0
    else
        lastJumpTapTime = currentTime
    end
end

UserInputService.JumpRequest:Connect(function()
    local currentTime = os.clock()
    if (currentTime - lastJumpReqTime) > 0.1 then handleJumpTap() end
    lastJumpReqTime = currentTime
end)

-- ==========================================
-- CHARACTER SETUP
-- ==========================================
local function setupCharacter(ch)
    character = ch
    rootPart = ch:WaitForChild("HumanoidRootPart")
    humanoid = ch:WaitForChild("Humanoid")
    if not rootPart or not humanoid then return end

    rootPart.CanCollide = false
    rootPart.Anchored = false

    if rootPart:FindFirstChild("FlightAttachment") then rootPart.FlightAttachment:Destroy() end
    if rootPart:FindFirstChild("FlightVelocity") then rootPart.FlightVelocity:Destroy() end

    attachment = Instance.new("Attachment")
    attachment.Name = "FlightAttachment"
    attachment.Parent = rootPart

    linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Name = "FlightVelocity"
    linearVelocity.Attachment0 = attachment
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVelocity.MaxForce = 0
    linearVelocity.VectorVelocity = Vector3.zero
    linearVelocity.Parent = rootPart

    lastAirborneTime = 0
    AE_safePos = rootPart.Position
    AE_safeGroundY = rootPart.Position.Y
    AE_lastFramePos = rootPart.Position
    AE_suspicionTime = tick()
    AFK_lockedPosition = rootPart.Position
    AFK_lastActivity = tick()

    immortal_hookHumanoid(humanoid)
    fall_hookHumanoid(humanoid)

    if getgenv().ImmortalActive then immortal_apply() end

    humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if LOCK_enabled then
            humanoid.PlatformStand = false
            return
        end
        if (antiFlingEnabled or getgenv().AbsoluteActive) and humanoid.PlatformStand
           and not AI_isSkyWalking then
            humanoid.PlatformStand = false
        end
    end)
    humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
        if LOCK_enabled then
            humanoid.Sit = false
            return
        end
        if (antiFlingEnabled or getgenv().AbsoluteActive) and humanoid.Sit
           and not AI_isSkyWalking then
            humanoid.Sit = false
        end
    end)
    humanoid:GetPropertyChangedSignal("BreakJointsOnDeath"):Connect(function()
        if getgenv().AbsoluteActive and humanoid.BreakJointsOnDeath then
            humanoid.BreakJointsOnDeath = false
        end
    end)

    if antiFlingEnabled or getgenv().AbsoluteActive then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
    end

    if flyToggleEnabled and not LOCK_enabled then setFlying(true) end
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(function(newChar)
    if linearVelocity then linearVelocity.MaxForce = 0 end
    task.wait(0.3)
    setupCharacter(newChar)
    if LOCK_enabled and rootPart then
        LOCK_cframe = rootPart.CFrame
        LOCK_apply()
        LOCK_createShield()
    end
end)

-- ==========================================
-- MAIN LOOPS
-- ==========================================
RunService.Stepped:Connect(function()
    if not character or not rootPart or not humanoid then return end

    if LOCK_enabled then
        LOCK_apply()
        return
    end

    if getgenv().NoclipActive then
        if rootPart.Anchored then rootPart.Anchored = false end
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and BODY_PART_NAMES[part.Name] then
                part.CanCollide = false
            end
        end
    end

    if noFallDamageEnabled then fall_capVelocity() end
    if rootPart.Position.Y < -50 then absoluteTeleport(getEntrySpawn()) end

    if antiFlingEnabled and not isTeleporting and not isFlying
       and not getgenv().NoclipActive and not AI_isSkyWalking
       and not AE_hasGameActuator() then
        local vel = rootPart.AssemblyLinearVelocity
        if vel.Magnitude > MAX_SPEED then
            rootPart.AssemblyLinearVelocity = vel:Lerp(vel.Unit * MAX_SPEED, SMOOTHING_FACTOR)
        end
        local angVel = rootPart.AssemblyAngularVelocity
        if angVel.Magnitude > MAX_ANGULAR then
            rootPart.AssemblyAngularVelocity = angVel:Lerp(angVel.Unit * MAX_ANGULAR, SMOOTHING_FACTOR)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not camera or not camera.Parent then
        camera = workspace.CurrentCamera
        return
    end
    if not character or not rootPart or not humanoid then return end

    if LOCK_enabled then
        if camera.CameraSubject ~= humanoid then
            pcall(function() camera.CameraSubject = humanoid end)
        end
        return
    end

    if isFlying and linearVelocity then
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            setFlying(false)
        elseif controls then
            local moveVector = controls:GetMoveVector()
            if moveVector.Magnitude > 0 then
                local camCFrame = camera.CFrame
                local flightDir = (camCFrame.RightVector * moveVector.X) - (camCFrame.LookVector * moveVector.Z)
                linearVelocity.VectorVelocity = flightDir.Unit * FLY_SPEED
            else
                linearVelocity.VectorVelocity = Vector3.zero
            end
        end
    end

    if runSpeedEnabled and not isFlying and not AI_isSkyWalking then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local currentVel = rootPart.AssemblyLinearVelocity
            rootPart.AssemblyLinearVelocity = Vector3.new(moveDir.X * runSpeedValue, currentVel.Y, moveDir.Z * runSpeedValue)
        end
    end

    if godModeEnabled then
        if humanoid.Health < IMMORTAL_TARGET_HP then humanoid.Health = IMMORTAL_TARGET_HP end
        if humanoid.MaxHealth < IMMORTAL_MAX_HEALTH then humanoid.MaxHealth = IMMORTAL_MAX_HEALTH end
    end

    if noFallDamageEnabled then fall_capVelocity() end
end)

RunService.Heartbeat:Connect(function()
    if not character or not character.Parent or not rootPart or not humanoid then return end

    if LOCK_enabled then
        LOCK_apply()
        if getgenv().ImmortalActive then immortal_regen() end
        return
    end

    if getgenv().AntiExploitActive then
        AE_guardPhysics()
        AE_enforceState()

        AE_ownerCounter = AE_ownerCounter + 1
        if AE_ownerCounter >= 60 then
            AE_ownerCounter = 0
            AE_reclaimOwnership()
        end
    end

    if getgenv().ImmortalActive then immortal_regen() end
    if afkStreakEnabled then AFK_tick() end
    if getgenv().AISkyWalkActive then AI_tick() end
end)

print("=========================================")
print("GR33D — FULL PANEL LOADED")
print("  🛡 Anti Exploiter — snap-back + cleanup")
print("  🔒 Position Lock — invisible shield + freeze")
print("  💀 Immortal Mode — 100k HP + regen")
print("  🪂 No Fall Damage")
print("  👾 Anti Monster — 15 stud lift")
print("  🌙 AFK Streak — position lock")
print("  ✈️ Flight / Noclip / Speed / TP")
print("=========================================")
