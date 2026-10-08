-- ==========================================
-- GR33D PANEL — SMART DETECTION BUILD
-- Grapple-safe: only catches real flings
-- ==========================================
getgenv().NoclipActive         = false
getgenv().AntiFlingActive      = false
getgenv().AntiExploitActive    = false
getgenv().AbsoluteActive       = false
getgenv().AISkyWalkActive      = false
getgenv().ImmortalActive       = false
getgenv().NoFallDamageActive   = false

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
-- STRICT TARGET CHECKS
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
    if BODY_PART_NAMES[inst.Name] then return true end
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

-- ==========================================
-- METATABLE HOOK — ULTRA LIGHTWEIGHT
-- ==========================================
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall

    mt.__namecall = newcclosure(function(self, ...)
        if not getgenv().AbsoluteActive then
            return oldNamecall(self, ...)
        end

        if checkcaller and checkcaller() then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()

        if method == "Kick" or method == "kick" then
            if self == player then return end
            return oldNamecall(self, ...)
        end

        if method ~= "TakeDamage"
           and method ~= "BreakJoints"
           and method ~= "ChangeState"
           and method ~= "SetNetworkOwner"
           and method ~= "PivotTo"
           and method ~= "SetPrimaryPartCFrame"
           and method ~= "Destroy"
           and method ~= "Remove" then
            return oldNamecall(self, ...)
        end

        if typeof(self) ~= "Instance" then
            return oldNamecall(self, ...)
        end

        if method == "Destroy" or method == "Remove" then
            if isOurBodyPart(self) then return end
            if isOurHumanoid(self) then return end
            if isOurCharModel(self) then return end
        elseif method == "BreakJoints" then
            if isOurCharModel(self) then return end
        elseif method == "TakeDamage" then
            if isOurHumanoid(self) then return end
        elseif method == "ChangeState" then
            if isOurHumanoid(self) then
                local state = ...
                if state == Enum.HumanoidStateType.Dead
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.Physics
                or state == Enum.HumanoidStateType.PlatformStanding
                or state == Enum.HumanoidStateType.FallingDown then
                    return
                end
            end
        elseif method == "SetNetworkOwner" then
            if isOurBodyPart(self) then
                local target = ...
                if target ~= player and target ~= nil then return end
            end
        elseif method == "PivotTo" or method == "SetPrimaryPartCFrame" then
            if isOurCharModel(self) then return end
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
    local xScale  = 1
    if isMobile and (PANEL_W > vp.X * 0.5) then
        xScale  = 0.5
        xOffset = -PANEL_W / 2
    end
    local yScale  = 0.5
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
-- CONFIG — GRAPPLE-SAFE THRESHOLDS
-- ==========================================
local FLY_SPEED          = 50
local runSpeedValue      = 50
local DOUBLE_TAP_WINDOW  = 0.35

-- Legit mechanics stay under these:
--   Grapple:    200–500 studs/s
--   Dash:       400–700 studs/s
--   Fast travel: up to 800 studs/s
-- Exploiters go 3000+ studs/s so we sit safely between.
local MAX_SPEED             = 800
local MAX_ANGULAR           = 200
local SMOOTHING_FACTOR      = 0.35

local IMMORTAL_MAX_HEALTH = 100000
local IMMORTAL_TARGET_HP  = 95000

local FALL_MAX_DOWN_VEL   = -45
local FALL_RECENT_WINDOW  = 2.5

local flyToggleEnabled    = false
local isFlying            = false
local godModeEnabled      = false
local noFallDamageEnabled = false
local runSpeedEnabled     = false
local antiFlingEnabled    = false
local antiTrapEnabled     = false
local isMinimized         = false
local isTeleporting       = false

local lastJumpTapTime     = 0
local lastJumpReqTime     = 0
local savedMapCFrame      = nil

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
-- IMMORTAL
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
            dragging   = true
            dragStart  = input.Position
            startPos   = mainFrame.Position
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
        pcall(callback, activeState)
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

-- ==========================================
-- TELEPORT / FLYING
-- ==========================================
local function absoluteTeleport(targetCFrame)
    if not character or not rootPart then return end
    isTeleporting = true
    if humanoid then
        humanoid.Sit = false
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    rootPart.AssemblyLinearVelocity  = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.Anchored = true
    character:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
    task.delay(0.06, function()
        if rootPart and rootPart.Parent then
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            rootPart.Anchored = false
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

createToggleRow("Immortal Mode", 40, function(state)
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

createToggleRow("⚡ Absolute Defense", 285, function(state)
    getgenv().AbsoluteActive = state
    getgenv().AntiExploitActive = state
end)

createToggleRow("Anti Monster", 320, function(state)
    getgenv().AISkyWalkActive = state
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

local function handleJumpTap()
    if not flyToggleEnabled then return end
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
-- ANTI-EXPLOIT — SMART DETECTION
-- Only fires when BOTH delta and velocity are absurd.
-- Grapples (high delta + normal velocity) pass through.
-- Flings (high delta + huge velocity) get caught.
-- ==========================================
local AE_lastPos        = nil
local AE_lastSnapTime   = 0
local AE_MAX_DELTA      = 400       -- studs in one frame
local AE_MAX_VELOCITY   = 2500      -- studs/s
local AE_MAX_ANGULAR    = 200       -- rad/s
local AE_SNAP_VELOCITY  = 1500      -- vel must ALSO be above this to trigger snap

local function AE_guardPhysics()
    if not getgenv().AntiExploitActive then return end
    if getgenv().NoclipActive or isTeleporting then
        AE_lastPos = rootPart.Position
        return
    end

    local pos = rootPart.Position
    local vel = rootPart.AssemblyLinearVelocity

    if AE_lastPos then
        local delta = (pos - AE_lastPos).Magnitude
        -- SMART: require BOTH frame teleport AND fling velocity
        if delta > AE_MAX_DELTA
           and vel.Magnitude > AE_SNAP_VELOCITY
           and (tick() - AE_lastSnapTime) > 1.5 then
            rootPart.CFrame = CFrame.new(AE_lastPos)
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
            AE_lastSnapTime = tick()
            return
        end
    end

    -- Only zero velocity if it's clearly injected (>2500 studs/s)
    if vel.Magnitude > AE_MAX_VELOCITY then
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
    if rootPart.AssemblyAngularVelocity.Magnitude > AE_MAX_ANGULAR then
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    AE_lastPos = rootPart.Position
end

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
    AE_lastPos = rootPart.Position

    immortal_hookHumanoid(humanoid)
    fall_hookHumanoid(humanoid)

    if getgenv().ImmortalActive then immortal_apply() end

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

    if antiFlingEnabled then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
    end

    if flyToggleEnabled then setFlying(true) end
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(function(newChar)
    if linearVelocity then linearVelocity.MaxForce = 0 end
    task.wait(0.3)
    setupCharacter(newChar)
end)

-- ==========================================
-- MAIN LOOPS
-- ==========================================
RunService.Stepped:Connect(function()
    if not character or not rootPart or not humanoid then return end

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

    -- Anti-Fling: only smooth velocities way above legit range (800+)
    if antiFlingEnabled and not isTeleporting and not isFlying
       and not getgenv().NoclipActive then
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

    if runSpeedEnabled and not isFlying then
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
    if getgenv().AntiExploitActive then AE_guardPhysics() end
    if getgenv().ImmortalActive then immortal_regen() end
end)

print("=========================================")
print("GR33D — SMART DETECTION BUILD")
print("  ✅ Grapples no longer freeze")
print("  ✅ Dash abilities work")
print("  ✅ Exploiter flings still caught")
print("  ✅ Pets stay glued")
print("  ✅ Drag + Minimize work")
print("=========================================")
