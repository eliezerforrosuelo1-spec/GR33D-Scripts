-- ==========================================
-- GR33D PANEL — OPTIMIZED + MOBILE-FIT UI
-- ==========================================
getgenv().NoclipActive         = false
getgenv().AntiFlingActive      = false
getgenv().AntiExploitActive    = false
getgenv().AbsoluteActive       = false
getgenv().AISkyWalkActive      = false
getgenv().ImmortalActive       = false
getgenv().NoFallDamageActive   = false

-- ==========================================
-- UTILITY
-- ==========================================
local function isOurChar(inst)
    local char = game.Players.LocalPlayer.Character
    if not char then return false end
    if typeof(inst) ~= "Instance" then return false end
    return inst == char or inst:IsDescendantOf(char)
end

local function isJoint(inst)
    if typeof(inst) ~= "Instance" then return false end
    return inst:IsA("Motor6D") or inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Snap")
end

-- ==========================================
-- METATABLE LOCKDOWN (frame-cached game-caller check)
-- ==========================================
local RunService          = game:GetService("RunService")
local CURRENT_FRAME = 0
local cachedCallerFrame = -1
local cachedCallerResult = false

local function isGameCaller()
    if cachedCallerFrame == CURRENT_FRAME then
        return cachedCallerResult
    end
    cachedCallerFrame = CURRENT_FRAME

    local ok, result = pcall(function()
        for level = 3, 6 do
            local s = debug.info(level, "s")
            if s and type(s) == "string" then
                if s:find("ReplicatedStorage", 1, true)
                or s:find("StarterPlayer",     1, true)
                or s:find("StarterCharacter",  1, true)
                or s:find("StarterGui",        1, true)
                or s:find("StarterPack",       1, true)
                or s:find("PlayerScripts",     1, true)
                or s:find("PlayerModule",      1, true)
                or s:find("ControlModule",     1, true)
                or s:find("Modules",           1, true) then
                    return true
                end
                if s:find("DevPanelGui", 1, true) then
                    return false
                end
            end
        end
        return false
    end)
    cachedCallerResult = ok and result == true
    return cachedCallerResult
end

RunService.Heartbeat:Connect(function()
    CURRENT_FRAME = CURRENT_FRAME + 1
end)

pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)

    local oldNamecall = mt.__namecall
    local oldNewIndex = mt.__newindex

    mt.__namecall = newcclosure(function(self, ...)
        if isGameCaller() then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()

        if not checkcaller() then
            if (method == "Kick" or method == "kick") and self == game.Players.LocalPlayer then
                warn("[Absolute] Blocked Kick.")
                return
            end

            if getgenv().AbsoluteActive then
                local t = typeof(self) == "Instance" and self or nil
                if t then
                    local touchesOurs = isOurChar(t)

                    if touchesOurs then
                        if (method == "Destroy" or method == "Remove" or method == "ClearAllChildren") then
                            if t:IsA("BasePart") or t:IsA("Humanoid") or isJoint(t)
                            or (t:IsA("Model") and t == game.Players.LocalPlayer.Character) then
                                warn("[Absolute] Blocked Destroy:", t.Name)
                                return
                            end
                        end
                        if method == "BreakJoints" and t:IsA("Model") then
                            warn("[Absolute] Blocked BreakJoints.")
                            return
                        end
                        if method == "TakeDamage" and t:IsA("Humanoid") then
                            warn("[Absolute] Blocked TakeDamage.")
                            return
                        end
                        if method == "ChangeState" and t:IsA("Humanoid") then
                            local state = ...
                            if state == Enum.HumanoidStateType.Dead
                            or state == Enum.HumanoidStateType.Ragdoll
                            or state == Enum.HumanoidStateType.Physics
                            or state == Enum.HumanoidStateType.PlatformStanding
                            or state == Enum.HumanoidStateType.FallingDown then
                                warn("[Absolute] Blocked ChangeState:", tostring(state))
                                return
                            end
                        end
                        if method == "SetStateEnabled" and t:IsA("Humanoid") then
                            local state, enabled = ...
                            if enabled and (state == Enum.HumanoidStateType.Dead
                                            or state == Enum.HumanoidStateType.Ragdoll
                                            or state == Enum.HumanoidStateType.Physics
                                            or state == Enum.HumanoidStateType.PlatformStanding
                                            or state == Enum.HumanoidStateType.FallingDown) then
                                return
                            end
                        end
                        if method == "SetNetworkOwner" and t:IsA("BasePart") then
                            local target = ...
                            if target ~= game.Players.LocalPlayer and target ~= nil then
                                warn("[Absolute] Blocked SetNetworkOwner theft.")
                                return
                            end
                        end
                        if (method == "PivotTo" or method == "SetPrimaryPartCFrame")
                           and t:IsA("Model") and t == game.Players.LocalPlayer.Character then
                            warn("[Absolute] Blocked PivotTo.")
                            return
                        end
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    mt.__newindex = newcclosure(function(t, k, v)
        if isGameCaller() then
            return oldNewIndex(t, k, v)
        end

        if not checkcaller() and typeof(t) == "Instance" then
            if t:IsA("BasePart") and isOurChar(t) then
                if getgenv().AbsoluteActive then
                    if k == "Anchored" or k == "CFrame" or k == "Position"
                    or k == "Orientation" or k == "AssemblyLinearVelocity"
                    or k == "AssemblyAngularVelocity" or k == "Velocity"
                    or k == "RotVelocity" or k == "Massless"
                    or k == "CustomPhysicalProperties" then
                        return
                    end
                    if k == "CanCollide" and not getgenv().NoclipActive then return end
                end
                if (getgenv().NoclipActive or getgenv().AntiFlingActive)
                   and k == "Anchored" and v == true then
                    return
                end
            end

            if t:IsA("Humanoid") and isOurChar(t) then
                if getgenv().AbsoluteActive or getgenv().ImmortalActive then
                    if k == "Health" or k == "MaxHealth" or k == "PlatformStand"
                    or k == "Sit" or k == "JumpPower" or k == "JumpHeight"
                    or k == "MoveDirection" or k == "TargetPoint" then
                        return
                    end
                    if k == "WalkSpeed" and (v == 0 or v > 500) then return end
                end
                if getgenv().NoFallDamageActive and k == "FallDamage" and v > 0 then
                    return
                end
            end

            if isJoint(t) and isOurChar(t) then
                if getgenv().AbsoluteActive or getgenv().AntiFlingActive then
                    if k == "Parent" or k == "Part0" or k == "Part1"
                    or k == "C0" or k == "C1" then
                        return
                    end
                    if k == "Enabled" and v == false then return end
                end
            end

            if t:IsA("Model") and t == game.Players.LocalPlayer.Character then
                if getgenv().AbsoluteActive and k == "PrimaryPart" then return end
            end
        end

        return oldNewIndex(t, k, v)
    end)

    setreadonly(mt, true)
end)

-- ==========================================
-- SERVICES
-- ==========================================
local UserInputService    = game:GetService("UserInputService")
local Players             = game:GetService("Players")
local CollectionService   = game:GetService("CollectionService")

local player = Players.LocalPlayer
local protectedParent = player:WaitForChild("PlayerGui")
if protectedParent:FindFirstChild("DevPanelGui") then
    protectedParent.DevPanelGui:Destroy()
end

local camera = workspace.CurrentCamera

-- ==========================================
-- MOBILE-FIT UI SIZING
-- ==========================================
-- Detect touch device and current viewport
local isMobile = UserInputService.TouchEnabled
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

-- Compute a panel size that fits within the screen with margins
local function computePanelSize()
    local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    -- On mobile, use ~72% of screen width capped at 220, and ~70% of height capped at 460
    -- On PC, use the classic 240x500
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

-- Position: anchored to the right side, vertically centered, with margin
local function computeStartPosition()
    local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    local margin = 12
    -- Right-aligned, but if panel is wider than 50% of screen, center it instead
    local xOffset = -(PANEL_W + margin)
    local xScale  = 1
    if isMobile and (PANEL_W > vp.X * 0.5) then
        xScale  = 0.5
        xOffset = -PANEL_W / 2
    end
    local yScale  = 0.5
    local yOffset = -PANEL_H / 2
    -- Clamp Y so panel can't go off top/bottom
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

local MAX_SPEED             = 150
local MAX_ANGULAR           = 50
local MAX_TELEPORT_DISTANCE = 500
local DEFAULT_WALKSPEED     = 16
local DEFAULT_JUMPPOWER     = 50
local SMOOTHING_FACTOR      = 0.35

local IMMORTAL_MAX_HEALTH = 100000
local IMMORTAL_TARGET_HP  = 95000

local FALL_MAX_DOWN_VEL   = -45
local FALL_RECENT_WINDOW  = 2.5

local AI_DANGER_DIST = 15
local AI_ESCAPE_DIST = 15
local AI_HEIGHT      = 15

local AF_MAX_SPEED       = 120
local AF_MAX_ANGULAR     = 30
local AF_MAX_FRAME_MOVE  = 15
local AF_FREEZE_TIME     = 1.2

local flyToggleEnabled    = false
local isFlying            = false
local godModeEnabled      = false
local noFallDamageEnabled = false
local runSpeedEnabled     = false
local antiFlingEnabled    = false
local antiTrapEnabled     = false
local isMinimized         = false
local isTeleporting       = false
local lastPos             = nil
local isRecovering        = false

local lastJumpTapTime     = 0
local lastJumpReqTime     = 0
local entrySpawnCFrame    = nil
local savedMapCFrame      = nil

local character, rootPart, humanoid
local attachment, linearVelocity
local isRestoringStats    = false

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
-- LADDER DETECTION
-- ==========================================
local function isNearLadder(char)
    if not char or not char.PrimaryPart then return false end
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local parts = workspace:GetPartBoundsInBox(char.PrimaryPart.CFrame, Vector3.new(6, 8, 6), params)
    for _, part in ipairs(parts) do
        if part:IsA("TrussPart") or string.find(string.lower(part.Name), "ladder") then
            return true
        end
    end
    return false
end

-- ==========================================
-- RAGDOLL RECOVERY
-- ==========================================
local function recoverFromRagdoll()
    if isRecovering or not character or not rootPart or not humanoid then return end
    isRecovering = true
    pcall(function() rootPart:SetNetworkOwner(player) end)
    if rootPart.Anchored then rootPart.Anchored = false end
    humanoid.PlatformStand = false
    humanoid.Sit = false
    rootPart.AssemblyLinearVelocity  = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    local currentPos = rootPart.Position
    local lookVector = rootPart.CFrame.LookVector
    local uprightCFrame = CFrame.new(currentPos, currentPos + Vector3.new(lookVector.X, 0, lookVector.Z))
    rootPart.CFrame = uprightCFrame
    task.delay(0.1, function()
        if humanoid and humanoid.Parent then
            pcall(function()
                if humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                else
                    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                end
            end)
        end
        isRecovering = false
    end)
end

-- ==========================================
-- STAT RESTORE
-- ==========================================
local function smoothRestoreStats()
    if isRestoringStats or not humanoid then return end
    isRestoringStats = true
    task.spawn(function()
        if not runSpeedEnabled and (humanoid.WalkSpeed <= 0 or humanoid.WalkSpeed > 100) then
            local target = DEFAULT_WALKSPEED
            for i = 1, 8 do
                if not humanoid or not humanoid.Parent then break end
                humanoid.WalkSpeed = humanoid.WalkSpeed + (target - humanoid.WalkSpeed) * 0.3
                task.wait(0.02)
            end
            if humanoid and humanoid.Parent then humanoid.WalkSpeed = target end
        end
        if humanoid and humanoid.Parent and (humanoid.JumpPower <= 0 or humanoid.JumpPower > 100) then
            local target = DEFAULT_JUMPPOWER
            for i = 1, 8 do
                if not humanoid or not humanoid.Parent then break end
                humanoid.JumpPower = humanoid.JumpPower + (target - humanoid.JumpPower) * 0.3
                task.wait(0.02)
            end
            if humanoid and humanoid.Parent then humanoid.JumpPower = target end
        end
        isRestoringStats = false
    end)
end

-- ==========================================
-- IMMORTAL ENGINE
-- ==========================================
local function immortal_apply()
    if not character or not humanoid then return end
    pcall(function()
        humanoid.MaxHealth = IMMORTAL_MAX_HEALTH
        if humanoid.Health < IMMORTAL_TARGET_HP then humanoid.Health = IMMORTAL_TARGET_HP end
        humanoid.BreakJointsOnDeath = false
    end)
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end)
end

local function immortal_regen()
    if not getgenv().ImmortalActive then return end
    if not character or not humanoid then return end
    if humanoid.Health < IMMORTAL_TARGET_HP then
        pcall(function() humanoid.Health = IMMORTAL_TARGET_HP end)
    end
    if humanoid.MaxHealth < IMMORTAL_MAX_HEALTH then
        pcall(function() humanoid.MaxHealth = IMMORTAL_MAX_HEALTH end)
    end
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
    hum.StateChanged:Connect(function(_, newState)
        if getgenv().ImmortalActive and hum == humanoid then
            if newState == Enum.HumanoidStateType.Dead then
                pcall(function()
                    hum.Health = IMMORTAL_TARGET_HP
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
        end
    end)
end

-- ==========================================
-- NO FALL DAMAGE ENGINE
-- ==========================================
local lastAirborneTime = 0
local wasAirborne      = false

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
        wasAirborne = true
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
            pcall(function()
                hum.Health = hum.MaxHealth
                lastAirborneTime = 0
            end)
        end
    end)
    hum.StateChanged:Connect(function(_, newState)
        if not noFallDamageEnabled then return end
        if hum ~= humanoid then return end
        if newState == Enum.HumanoidStateType.FallingDown
        or newState == Enum.HumanoidStateType.Landed
        or newState == Enum.HumanoidStateType.GettingUp then
            pcall(function()
                if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
                if hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end
    end)
    hum.Died:Connect(function()
        if not noFallDamageEnabled then return end
        if hum ~= humanoid then return end
        if (tick() - lastAirborneTime) < FALL_RECENT_WINDOW then
            task.defer(function()
                if character and character.Parent then
                    pcall(function()
                        hum.Health = hum.MaxHealth
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
            end)
        end
    end)
end

-- ==========================================
-- ENHANCED ANTI-RAGDOLL / ANTI-FLING ENGINE
-- ==========================================
local AF_poseSnapshot    = {}
local AF_lastGoodPos     = nil
local AF_freezeMode      = false
local AF_freezeCFrame    = nil
local AF_freezeRelease   = 0

local function AF_snapshotPose()
    AF_poseSnapshot = {}
    if not character then return end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("Motor6D") then
            AF_poseSnapshot[d] = { C0 = d.C0, C1 = d.C1 }
        end
    end
end

local function AF_restoreJoints()
    for joint, base in pairs(AF_poseSnapshot) do
        if joint.Parent then
            if joint.C0 ~= base.C0 then joint.C0 = base.C0 end
            if joint.C1 ~= base.C1 then joint.C1 = base.C1 end
        end
    end
end

local function AF_isUnderAttack(curPos)
    if not rootPart then return false end
    local vel = rootPart.AssemblyLinearVelocity
    local angVel = rootPart.AssemblyAngularVelocity

    if vel.Magnitude > AF_MAX_SPEED then return true end
    if angVel.Magnitude > AF_MAX_ANGULAR then return true end

    if AF_lastGoodPos then
        local frameDelta = (curPos - AF_lastGoodPos).Magnitude
        if frameDelta > AF_MAX_FRAME_MOVE and not isTeleporting then
            return true
        end
    end
    return false
end

local AF_jointTickCount = 0
local function AF_tick()
    if not antiFlingEnabled then
        if AF_freezeMode then AF_freezeMode = false end
        return
    end
    if not character or not rootPart or not humanoid then return end

    if isTeleporting or isFlying or getgenv().NoclipActive or AI_isSkyWalking then
        AF_freezeMode = false
        AF_lastGoodPos = rootPart.Position
        return
    end

    if humanoid.PlatformStand then humanoid.PlatformStand = false end
    if humanoid.Sit then humanoid.Sit = false end
    local st = humanoid:GetState()
    if st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Ragdoll
    or st == Enum.HumanoidStateType.FallingDown then
        pcall(function()
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            else
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end

    local curPos = rootPart.Position
    if AF_isUnderAttack(curPos) then
        if not AF_freezeMode then
            AF_freezeMode = true
            AF_freezeCFrame = AF_lastGoodPos and CFrame.new(AF_lastGoodPos) or rootPart.CFrame
            print("[ANTI-FLING] Attack detected — FROZEN")
        end
        AF_freezeRelease = tick() + AF_FREEZE_TIME
    end

    if AF_freezeMode then
        if AF_freezeCFrame then rootPart.CFrame = AF_freezeCFrame end
        rootPart.AssemblyLinearVelocity  = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        AF_restoreJoints()
        if tick() > AF_freezeRelease then
            AF_freezeMode = false
            AF_lastGoodPos = rootPart.Position
            print("[ANTI-FLING] Released — unfroze")
        end
        return
    end

    local vel = rootPart.AssemblyLinearVelocity
    if vel.Magnitude > MAX_SPEED then
        rootPart.AssemblyLinearVelocity = vel:Lerp(vel.Unit * MAX_SPEED, SMOOTHING_FACTOR)
    end
    local angVel = rootPart.AssemblyAngularVelocity
    if angVel.Magnitude > MAX_ANGULAR then
        rootPart.AssemblyAngularVelocity = angVel:Lerp(angVel.Unit * MAX_ANGULAR, SMOOTHING_FACTOR)
    end

    local owner = rootPart:GetNetworkOwner()
    if owner and owner ~= player then
        pcall(function() rootPart:SetNetworkOwner(player) end)
    end

    AF_jointTickCount = AF_jointTickCount + 1
    if AF_jointTickCount >= 4 then
        AF_jointTickCount = 0
        AF_restoreJoints()
    end

    AF_lastGoodPos = rootPart.Position
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

-- Title row height scales with panel size
local TITLE_H = 40
local MINIMIZED_SIZE = isMobile and 56 or 44   -- bigger tap target on mobile

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, TITLE_H)
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
minimizeButton.Active = false
minimizeButton.ZIndex = 10
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 8)

-- ==========================================
-- SMART DRAG (clamped to viewport, works on mobile)
-- ==========================================
do
    local dragging, dragStart, startPos
    local function getVP()
        return (camera and camera.ViewportSize) or Vector2.new(800, 600)
    end
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = input.Position
            startPos   = mainFrame.AbsolutePosition
        end
    end
    local function moveDrag(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local vp = getVP()
            local size = mainFrame.AbsoluteSize
            local margin = 4

            local newX = startPos.X + delta.X
            local newY = startPos.Y + delta.Y

            -- Clamp so the panel never goes off-screen
            newX = math.clamp(newX, margin, vp.X - size.X - margin)
            newY = math.clamp(newY, margin, vp.Y - size.Y - margin)

            mainFrame.Position = UDim2.new(0, newX, 0, newY)
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

-- Recalculate size + reposition on viewport change (rotation, resize)
local function onViewportResize()
    PANEL_W, PANEL_H = computePanelSize()
    if not isMinimized then
        mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
    end
    -- Clamp current position back into bounds
    local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    local pos = mainFrame.AbsolutePosition
    local size = mainFrame.AbsoluteSize
    local margin = 4
    local x = math.clamp(pos.X, margin, math.max(margin, vp.X - size.X - margin))
    local y = math.clamp(pos.Y, margin, math.max(margin, vp.Y - size.Y - margin))
    mainFrame.Position = UDim2.new(0, x, 0, y)
end

if camera then
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportResize)
end

local toggleContainer = Instance.new("ScrollingFrame")
toggleContainer.Size = UDim2.new(1, 0, 1, -45)
toggleContainer.Position = UDim2.new(0, 0, 0, 45)
toggleContainer.BackgroundTransparency = 1
toggleContainer.BorderSizePixel = 0
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 620)
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
    if activeState then
        switchBg.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Position = UDim2.new(1, -17, 0.5, -7)
    end

    switchBg.MouseButton1Click:Connect(function()
        activeState = not activeState
        if activeState then
            switchBg.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob:TweenPosition(UDim2.new(1, -17, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        else
            switchBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
            knob:TweenPosition(UDim2.new(0, 3, 0.5, -7), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        end
        callback(activeState)
    end)
    return row
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
        if num then callback(num) else textBox.Text = tostring(defaultVal) end
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
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- ==========================================
-- TELEPORT & FLYING
-- ==========================================
local function absoluteTeleport(targetCFrame)
    local cChar, cRoot, cHum = character, rootPart, humanoid
    if not cChar or not cRoot then return end
    isTeleporting = true
    if cHum then
        cHum.Sit = false
        cHum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    cRoot.AssemblyLinearVelocity  = Vector3.zero
    cRoot.AssemblyAngularVelocity = Vector3.zero
    cRoot.Anchored = true
    cChar:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
    task.delay(0.04, function()
        if cRoot and cRoot.Parent then
            cRoot.AssemblyLinearVelocity  = Vector3.zero
            cRoot.AssemblyAngularVelocity = Vector3.zero
            cRoot.Anchored = false
        end
        if cHum and cHum.Parent then
            cHum:ChangeState(Enum.HumanoidStateType.Running)
        end
        isTeleporting = false
    end)
end

local function getEntrySpawn()
    if entrySpawnCFrame then return entrySpawnCFrame end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") and obj.Enabled then
            return obj.CFrame + Vector3.new(0, 3, 0)
        end
    end
    return rootPart and rootPart.CFrame or CFrame.new(0, 5, 0)
end

local function setFlying(state)
    if not rootPart or not humanoid or not linearVelocity then return end
    isFlying = state
    if isFlying then
        linearVelocity.MaxForce = 100000
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    else
        linearVelocity.MaxForce = 0
        linearVelocity.VectorVelocity = Vector3.zero
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
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

createToggleRow("Immortal Mode", 40, function(state)
    godModeEnabled = state
    getgenv().ImmortalActive = state
    if state then
        immortal_apply()
        if humanoid then immortal_hookHumanoid(humanoid) end
        warn("[Immortal] ENABLED")
    else
        if humanoid then
            pcall(function()
                humanoid.MaxHealth = 100
                humanoid.Health = math.min(humanoid.Health, 100)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            end)
        end
        warn("[Immortal] DISABLED")
    end
end)

createToggleRow("No Fall Damage", 75, function(state)
    noFallDamageEnabled = state
    getgenv().NoFallDamageActive = state
    if state then
        if humanoid then
            pcall(function() humanoid.FallDamage = 0 end)
            pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
        end
        warn("[NoFallDamage] ENABLED")
    end
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
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            AF_snapshotPose()
            AF_lastGoodPos = rootPart and rootPart.Position or nil
            AF_freezeMode = false
            warn("[Anti-Fling] Pose lock ARMED")
        else
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            AF_freezeMode = false
            warn("[Anti-Fling] Pose lock DISARMED")
        end
    end
end)

createToggleRow("Anti Trap", 180, function(state)
    antiTrapEnabled = state
    if not state and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanTouch = true
                part.CanQuery = true
            end
        end
    end
end)

createToggleRow("Super Run Speed", 215, function(state)
    runSpeedEnabled = state
end)

createInputRow("Run Speed Value", 250, 50, function(value)
    runSpeedValue = value
end)

createToggleRow("⚡ Absolute Defense", 285, function(state)
    getgenv().AbsoluteActive = state
    getgenv().AntiExploitActive = state
    if state then
        AE_armCharacter()
        warn("[Absolute] DEFENSE ENABLED")
    else
        AE_disarm()
        warn("[Absolute] DEFENSE DISABLED")
    end
end)

createToggleRow("Anti Monster", 320, function(state)
    getgenv().AISkyWalkActive = state
    if state then AI_start() else AI_stop() end
end)

createActionButton("TP to Entry Spawn", 355, Color3.fromRGB(41, 128, 185), function()
    absoluteTeleport(getEntrySpawn())
end)

local saveMapButton = createActionButton("Save Current Map Location", 392, Color3.fromRGB(142, 68, 173), function()
    if not rootPart then return end
    savedMapCFrame = rootPart.CFrame
    saveMapButton.Text = "Map Location Saved!"
    task.delay(1.5, function() saveMapButton.Text = "Save Current Map Location" end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 429, Color3.fromRGB(39, 174, 96), function()
    if savedMapCFrame then
        absoluteTeleport(savedMapCFrame)
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
        -- Remember current position, snap to a corner-safe spot
        local vp = (camera and camera.ViewportSize) or Vector2.new(800, 600)
        local pos = mainFrame.AbsolutePosition
        local x = math.clamp(pos.X, 4, vp.X - MINIMIZED_SIZE - 4)
        local y = math.clamp(pos.Y, 4, vp.Y - MINIMIZED_SIZE - 4)
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

        -- Make sure the expanded panel is fully on-screen
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
    local currentTime = os.clock()
    local timeSinceLastTap = currentTime - lastJumpTapTime
    if timeSinceLastTap <= DOUBLE_TAP_WINDOW then
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
-- ANTI-EXPLOIT SHIELD
-- ==========================================
local AE_motorSnapshot     = {}
local AE_allowedChildren   = {}
local AE_whitelistCharacter = nil
local AE_lastPos           = nil
local AE_lastSnapTime      = 0
local AE_reported          = {}
local AE_active            = false

local AE_MAX_DELTA    = 100
local AE_MAX_VELOCITY = 500
local AE_MAX_ANGULAR  = 40
local AE_LOG          = true

local function AE_log(...)
    if AE_LOG then print("[ABSOLUTE]", ...) end
end

local function AE_whitelistBuild()
    AE_allowedChildren = {}
    AE_whitelistCharacter = character
    if not character then return end
    for _, c in ipairs(character:GetChildren()) do
        AE_allowedChildren[c] = true
    end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("Accessory") or d:IsA("BodyColors") or d:IsA("Shirt")
        or d:IsA("Pants") or d:IsA("CharacterMesh") or d:IsA("Decal")
        or d:IsA("Sound") or d:IsA("Animator") then
            AE_allowedChildren[d] = true
        end
    end
end

local function AE_snapshotMotors()
    AE_motorSnapshot = {}
    if not character then return end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("Snap") then
            AE_motorSnapshot[d.Name] = {
                Class = d.ClassName, Part0 = d.Part0, Part1 = d.Part1,
                C0 = d.C0, C1 = d.C1, Parent = d.Parent,
            }
        end
    end
end

function AE_armCharacter()
    if not character or not rootPart then return end
    AE_active = true
    AE_lastPos = rootPart.Position
    AE_whitelistBuild()
    AE_snapshotMotors()
    pcall(function()
        if rootPart:GetNetworkOwner() ~= player then
            rootPart:SetNetworkOwner(player)
        end
    end)
    AE_log("Armed.")
end

function AE_disarm()
    AE_active = false
    AE_motorSnapshot = {}
    AE_allowedChildren = {}
    AE_whitelistCharacter = nil
end

local function AE_restoreMotors()
    if not character then return end
    for name, info in pairs(AE_motorSnapshot) do
        local exists = false
        for _, d in ipairs(character:GetDescendants()) do
            if d.Name == name and (d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("Snap")) then
                exists = true break
            end
        end
        if not exists
        and info.Part0 and info.Part0.Parent == character
        and info.Part1 and info.Part1.Parent == character then
            local j = Instance.new(info.Class)
            j.Name = name; j.Part0 = info.Part0; j.Part1 = info.Part1
            j.C0 = info.C0; j.C1 = info.C1; j.Parent = info.Parent
            AE_log("Restored joint:", name)
        end
    end
end

local function AE_cleanForeign()
    if getgenv().NoclipActive or AI_isSkyWalking then return end
    if not character then return end
    if AE_whitelistCharacter ~= character then return end
    if not next(AE_allowedChildren) then return end
    for _, d in ipairs(character:GetDescendants()) do
        if not AE_allowedChildren[d] and not AE_motorSnapshot[d.Name] then
            if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D")
            or d:IsA("BodyVelocity") or d:IsA("BodyPosition") or d:IsA("BodyGyro")
            or d:IsA("LinearVelocity") or d:IsA("AlignPosition")
            or d:IsA("AlignOrientation") or d:IsA("VectorForce")
            or d:IsA("RocketPropulsion") then
                local n = d.Name
                if n ~= "FlightVelocity"
                   and n ~= "FlightAttachment"
                   and n ~= "AI_SkyWalk_Vel"
                   and n ~= "AI_SkyWalk_Pos"
                   and n ~= "AI_SkyWalk_Attachment" then
                    AE_log("Removed foreign:", n, d.ClassName)
                    d:Destroy()
                end
            end
        end
    end
end

local function AE_guardPhysics(dt)
    if getgenv().NoclipActive or AI_isSkyWalking or isTeleporting then
        AE_lastPos = rootPart.Position
        return
    end
    local pos = rootPart.Position
    local vel = rootPart.AssemblyLinearVelocity
    if AE_lastPos then
        local delta = (pos - AE_lastPos).Magnitude
        if delta > AE_MAX_DELTA and (tick() - AE_lastSnapTime) > 1.5 then
            AE_log(("Teleport detected (%.0f) — snapping back."):format(delta))
            rootPart.CFrame = CFrame.new(AE_lastPos)
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            AE_lastSnapTime = tick()
            return
        end
    end
    if vel.Magnitude > AE_MAX_VELOCITY then
        AE_log(("Injected velocity (%.0f) — zeroing."):format(vel.Magnitude))
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
    if rootPart.AssemblyAngularVelocity.Magnitude > AE_MAX_ANGULAR then
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end
    AE_lastPos = rootPart.Position
end

local function AE_enforceState()
    if getgenv().NoclipActive or AI_isSkyWalking then return end
    if humanoid.PlatformStand then
        AE_log("PlatformStand forced — resetting.")
        humanoid.PlatformStand = false
    end
    if humanoid.Sit then
        AE_log("Sit forced — resetting.")
        humanoid.Sit = false
    end
    local st = humanoid:GetState()
    if st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Ragdoll
    or st == Enum.HumanoidStateType.FallingDown
    or st == Enum.HumanoidStateType.Dead then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
end

local function AE_reclaimOwnership()
    if getgenv().NoclipActive or AI_isSkyWalking then return end
    if rootPart then
        pcall(function()
            if rootPart:GetNetworkOwner() ~= player then
                rootPart:SetNetworkOwner(player)
            end
        end)
    end
end

local function AE_watchNearby()
    local myPos = rootPart.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local oc = plr.Character
            local ohrp = oc and oc:FindFirstChild("HumanoidRootPart")
            if ohrp then
                local d  = (ohrp.Position - myPos).Magnitude
                local ov = ohrp.AssemblyLinearVelocity.Magnitude
                local ohum = oc:FindFirstChildOfClass("Humanoid")
                if d < 4 and (ov > 250 or (ohum and ohum.PlatformStand)) then
                    if not AE_reported[plr.Name] then
                        AE_reported[plr.Name] = true
                        AE_log(("SUSPICIOUS: %s d=%.1f v=%.1f"):format(plr.Name, d, ov))
                    end
                end
            end
        end
    end
end

-- ==========================================
-- ANTI MONSTER
-- ==========================================
AI_isSkyWalking = false
local AI_groundY       = 0
local AI_linearVel     = nil
local AI_bodyPos       = nil
local AI_registry      = setmetatable({}, {__mode = "k"})
local AI_registryBuilt = false

local AI_FRIENDLY_KEYWORDS = {
    "shop","vendor","merchant","quest","trainer","citizen","dummy",
    "training","blacksmith","healer","safezone","companion","pet"
}
local AI_HOSTILE_NAME_HINTS = {
    "guard","enemy","monster","boss","zombie","hunter","chaser",
    "killer","brute","mutant","beast","demon","raider","bandit",
    "reaper","stalker","fiend","wraith"
}
local AI_HOSTILE_TAGS = {
    "AI","Enemy","Hostile","Monster","Guard","NPC_Hostile",
    "Chaser","Aggro","Boss","Mob"
}

local function AI_nameHasAny(name, list)
    if not name then return false end
    name = name:lower()
    for _, kw in ipairs(list) do
        if name:find(kw, 1, true) then return true end
    end
    return false
end

local function AI_looksLikeRig(model)
    if not model:IsA("Model") then return false end
    local hasRoot = model:FindFirstChild("HumanoidRootPart")
                  or model:FindFirstChild("RootPart")
                  or model:FindFirstChild("Root")
                  or model:FindFirstChild("Torso")
    local hasHead = model:FindFirstChild("Head")
    return (hasRoot and hasHead) or (hasRoot and #model:GetChildren() > 3)
end

local function AI_isHostile(model)
    if not model or not model:IsA("Model") then return false end
    if model == character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then
        return false
    end
    if AI_nameHasAny(model.Name, AI_FRIENDLY_KEYWORDS) then
        if not AI_nameHasAny(model.Name, AI_HOSTILE_NAME_HINTS) then return false end
    end
    for _, a in ipairs({"AIState","State","Aggro","IsAggro","Hostile",
                        "Target","IsNPC","IsAI","AI","Enemy"}) do
        if model:GetAttribute(a) ~= nil then return true end
    end
    for _, tag in ipairs(AI_HOSTILE_TAGS) do
        if CollectionService:HasTag(model, tag) then return true end
    end
    if AI_nameHasAny(model.Name, AI_HOSTILE_NAME_HINTS) then return true end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then
            if AI_nameHasAny(d.Name, {"ai","chase","aggro","attack","combat",
                                       "monster","enemy","hostile","guard"}) then
                return true
            end
        end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ObjectValue") and d.Name:lower():find("target") then
            local v = d.Value
            if v == character or v == character:FindFirstChild("Humanoid")
               or v == character:FindFirstChild("HumanoidRootPart") then
                return true
            end
        end
    end
    if hum then return true end
    if AI_looksLikeRig(model) then return true end
    return false
end

local function AI_getModelPos(model)
    local ok, pivot = pcall(function() return model:GetPivot() end)
    if ok and pivot then return pivot.Position end
    local root = model:FindFirstChild("HumanoidRootPart")
             or model:FindFirstChild("RootPart")
             or model:FindFirstChild("Head")
    return root and root.Position or nil
end

local function AI_register(model)
    if not model or not model:IsA("Model") then return end
    if AI_registry[model] ~= nil then return end
    AI_registry[model] = AI_isHostile(model)
end

local function AI_scanWorkspace()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") then
            if d:FindFirstChildOfClass("Humanoid") or AI_looksLikeRig(d) then
                AI_register(d)
            end
        end
    end
    AI_registryBuilt = true
end

local function AI_setNoclip(state)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if state then
                part.CanCollide = false
                part.CanTouch   = false
                part.CanQuery   = false
            else
                if getgenv().NoclipActive then
                    part.CanCollide = false
                else
                    if part.Name == "HumanoidRootPart"
                    or part.Name == "UpperTorso"
                    or part.Name == "LowerTorso"
                    or part.Name == "Torso" then
                        part.CanCollide = true
                    else
                        part.CanCollide = false
                    end
                end
                part.CanTouch = true
                part.CanQuery = true
            end
        end
    end
end

local function AI_startSkyWalk()
    if not character or not rootPart or not humanoid then return end
    AI_groundY       = rootPart.Position.Y
    AI_isSkyWalking  = true
    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    AI_setNoclip(true)
    rootPart.CFrame = CFrame.new(rootPart.Position.X, AI_groundY + AI_HEIGHT, rootPart.Position.Z)
    AI_linearVel = Instance.new("LinearVelocity")
    AI_linearVel.Name = "AI_SkyWalk_Vel"
    AI_linearVel.MaxForce       = math.huge
    AI_linearVel.VectorVelocity = Vector3.zero
    AI_linearVel.Attachment0    = rootPart.RootAttachment
    AI_linearVel.Parent         = rootPart
    AI_bodyPos = Instance.new("BodyPosition")
    AI_bodyPos.Name = "AI_SkyWalk_Pos"
    AI_bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
    AI_bodyPos.P = 10000
    AI_bodyPos.D = 1000
    AI_bodyPos.Position = Vector3.new(rootPart.Position.X, AI_groundY + AI_HEIGHT, rootPart.Position.Z)
    AI_bodyPos.Parent = rootPart
    warn("[Anti Monster] LIFTING 15 STUDS.")
end

local function AI_endSkyWalk()
    if not character or not rootPart or not humanoid then return end
    AI_isSkyWalking = false
    if AI_linearVel then AI_linearVel:Destroy() AI_linearVel = nil end
    if AI_bodyPos   then AI_bodyPos:Destroy()   AI_bodyPos   = nil end
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {character}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(rootPart.Position + Vector3.new(0,10,0), Vector3.new(0,-500,0), rp)
    local landY = res and (res.Position.Y + 3.5) or AI_groundY
    rootPart.CFrame = CFrame.new(rootPart.Position.X, landY, rootPart.Position.Z)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
    task.wait(0.1)
    AI_setNoclip(false)
    AE_lastPos = rootPart.Position
    warn("[Anti Monster] DROPPING DOWN.")
end

function AI_start()
    if not AI_registryBuilt and character then
        task.spawn(AI_scanWorkspace)
    end
    warn("[Anti Monster] ENABLED")
end

function AI_stop()
    if AI_isSkyWalking then AI_endSkyWalk() end
    warn("[Anti Monster] DISABLED")
end

-- ==========================================
-- HOOK: character respawn
-- ==========================================
local function AE_onRespawn()
    AE_reported = {}
    if getgenv().AntiExploitActive then
        AE_armCharacter()
    end
end

-- ==========================================
-- MAIN LOOPS
-- ==========================================
local AE_acc = 0
local immortalApplyAcc = 0

RunService.Stepped:Connect(function(_, dt)
    if not character or not rootPart or not humanoid then return end

    if getgenv().NoclipActive then
        if rootPart.Anchored then rootPart.Anchored = false end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            end
            if part:IsA("BodyForce") or part:IsA("BodyVelocity") or part:IsA("BodyPosition")
            or part:IsA("VectorForce") or part:IsA("AlignPosition") or part:IsA("LinearVelocity") then
                if part.Name ~= "FlightVelocity"
                   and part.Name ~= "AI_SkyWalk_Vel"
                   and part.Name ~= "AI_SkyWalk_Pos" then
                    part:Destroy()
                end
            end
        end
    elseif antiTrapEnabled then
        local nearLadder = isNearLadder(character)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanTouch = nearLadder and true or false
                part.CanQuery = nearLadder and true or false
            end
        end
    end

    if noFallDamageEnabled then fall_capVelocity() end
    if rootPart.Position.Y < -50 then absoluteTeleport(getEntrySpawn()) end

    if getgenv().AbsoluteActive then
        if rootPart.Anchored then rootPart.Anchored = false end
        for _, p in ipairs(character:GetChildren()) do
            if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
        end
        if humanoid.PlatformStand then humanoid.PlatformStand = false end
        if humanoid.Sit then humanoid.Sit = false end
    end

    if antiFlingEnabled then AF_tick() end
    lastPos = rootPart.Position
end)

RunService.RenderStepped:Connect(function()
    if not camera or not camera.Parent then
        camera = workspace.CurrentCamera
        return
    end
    if isFlying and linearVelocity and humanoid and rootPart then
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
    if runSpeedEnabled and rootPart and humanoid and not isFlying then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local currentVel = rootPart.AssemblyLinearVelocity
            rootPart.AssemblyLinearVelocity = Vector3.new(moveDir.X * runSpeedValue, currentVel.Y, moveDir.Z * runSpeedValue)
        end
    end
    if godModeEnabled and humanoid then
        if humanoid.Health < IMMORTAL_TARGET_HP then humanoid.Health = IMMORTAL_TARGET_HP end
        if humanoid.MaxHealth < IMMORTAL_MAX_HEALTH then humanoid.MaxHealth = IMMORTAL_MAX_HEALTH end
    end
    if noFallDamageEnabled then fall_capVelocity() end
end)

-- MERGED HEARTBEAT
RunService.Heartbeat:Connect(function(dt)
    if not character or not character.Parent or not rootPart or not humanoid then return end

    if getgenv().AntiExploitActive then
        AE_guardPhysics(dt)
        AE_enforceState()
        AE_acc = AE_acc + dt
        local interval = getgenv().AbsoluteActive and 0.1 or 0.3
        if AE_acc >= interval then
            AE_acc = 0
            AE_restoreMotors()
            AE_cleanForeign()
            AE_reclaimOwnership()
            AE_watchNearby()
        end
    end

    if getgenv().ImmortalActive then
        immortal_regen()
        immortalApplyAcc = immortalApplyAcc + dt
        if immortalApplyAcc >= 0.75 then
            immortalApplyAcc = 0
            immortal_apply()
        end
    end

    if getgenv().AISkyWalkActive then
        if AI_isSkyWalking and AI_linearVel and AI_bodyPos then
            AI_setNoclip(true)
            humanoid.PlatformStand = true
            AI_linearVel.VectorVelocity = humanoid.MoveDirection * humanoid.WalkSpeed
            AI_bodyPos.Position = Vector3.new(
                rootPart.Position.X,
                AI_groundY + AI_HEIGHT,
                rootPart.Position.Z
            )
        end

        if humanoid.Health <= 0 then
            if AI_isSkyWalking then AI_endSkyWalk() end
        else
            local myPos   = rootPart.Position
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
                if closest3D <= AI_DANGER_DIST then AI_startSkyWalk() end
            else
                if closestXZ >= AI_ESCAPE_DIST then AI_endSkyWalk() end
            end
        end
    end
end)

workspace.DescendantAdded:Connect(function(d)
    if not getgenv().AISkyWalkActive then return end
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
        task.defer(AI_register, d.Parent)
    end
    if d:IsA("Model") then task.defer(AI_register, d) end
end)

workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then AI_registry[d] = nil end
end)

for _, tag in ipairs(AI_HOSTILE_TAGS) do
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
        if not getgenv().AISkyWalkActive then return end
        local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
        if m then AI_registry[m] = true end
    end)
end

-- ==========================================
-- CHARACTER SETUP
-- ==========================================
local function setupCharacter(char)
    character = char
    rootPart  = char:WaitForChild("HumanoidRootPart")
    humanoid  = char:WaitForChild("Humanoid")

    rootPart.CanCollide = false
    rootPart.Anchored   = false

    if rootPart:FindFirstChild("FlightAttachment") then rootPart.FlightAttachment:Destroy() end
    if rootPart:FindFirstChild("FlightVelocity")   then rootPart.FlightVelocity:Destroy()   end

    attachment = Instance.new("Attachment")
    attachment.Name   = "FlightAttachment"
    attachment.Parent = rootPart

    linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Name = "FlightVelocity"
    linearVelocity.Attachment0 = attachment
    linearVelocity.RelativeTo   = Enum.ActuatorRelativeTo.World
    linearVelocity.MaxForce     = 0
    linearVelocity.VectorVelocity = Vector3.zero
    linearVelocity.Parent = rootPart

    lastPos = rootPart.Position
    lastAirborneTime = 0
    wasAirborne = false

    immortal_hookHumanoid(humanoid)
    fall_hookHumanoid(humanoid)

    task.defer(function()
        task.wait(0.3)
        AF_snapshotPose()
        AF_lastGoodPos = rootPart and rootPart.Position or nil
    end)

    if getgenv().ImmortalActive then immortal_apply() end
    if noFallDamageEnabled then
        pcall(function() humanoid.FallDamage = 0 end)
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
    end
    if getgenv().AntiExploitActive then AE_onRespawn() end

    humanoid.StateChanged:Connect(function(_, newState)
        if antiFlingEnabled or getgenv().AbsoluteActive then
            if newState == Enum.HumanoidStateType.Ragdoll
            or newState == Enum.HumanoidStateType.FallingDown
            or newState == Enum.HumanoidStateType.Physics
            or newState == Enum.HumanoidStateType.Dead then
                task.defer(function()
                    if humanoid and humanoid.Parent then
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                        else
                            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
                        end
                    end
                end)
            end
        end
    end)

    humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if (antiFlingEnabled or getgenv().AbsoluteActive) and humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
    end)
    humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
        if (antiFlingEnabled or getgenv().AbsoluteActive) and humanoid.Sit then
            humanoid.Sit = false
        end
    end)

    char.DescendantAdded:Connect(function(child)
        if antiTrapEnabled and child:IsA("BasePart") then
            if not isNearLadder(char) then
                child.CanTouch = false
                child.CanQuery = false
            end
        end
        if antiFlingEnabled or getgenv().AbsoluteActive then
            if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity")
            or child:IsA("LinearVelocity") or child:IsA("AngularVelocity")
            or child:IsA("AlignPosition") or child:IsA("AlignOrientation")
            or child:IsA("Weld") or child:IsA("Motor6D") then
                if child:IsA("Motor6D") and child.Name ~= "FlingMotor" then return end
                if child.Name == "FlightVelocity" then return end
                if child.Name == "AI_SkyWalk_Vel" or child.Name == "AI_SkyWalk_Pos" then return end
                task.defer(function()
                    if child and child.Parent then child:Destroy() end
                end)
            end
        end
    end)

    if antiFlingEnabled or getgenv().AbsoluteActive then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end

    if flyToggleEnabled then setFlying(true) end
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(function(newChar)
    if linearVelocity then linearVelocity.MaxForce = 0 end
    setupCharacter(newChar)
end)

print("=========================================")
print("GR33D — OPTIMIZED + MOBILE-FIT UI loaded")
print("  📱 Panel auto-sizes to fit screen")
print("  📌 Dragging is clamped on-screen")
print("  🔄 Repositions on rotation/resize")
print("=========================================")
