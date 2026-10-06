-- ==========================================
-- ABSOLUTE ANTI-CHEAT & HOOK PROTECTION
-- ==========================================
getgenv().NoclipActive = false
getgenv().AntiFlingActive = false

pcall(function()
	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	
	local oldNamecall = mt.__namecall
	local oldNewIndex = mt.__newindex
	
	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if not checkcaller() and (method == "Kick" or method == "kick") and self == game.Players.LocalPlayer then
			warn("[Anti-Cheat Shield] Blocked unauthorized Kick attempt.")
			return
		end
		return oldNamecall(self, ...)
	end)
	
	mt.__newindex = newcclosure(function(t, k, v)
		if not checkcaller() and typeof(t) == "Instance" and t:IsA("BasePart") then
			local char = game.Players.LocalPlayer.Character
			if char and t:IsDescendantOf(char) then
				if (getgenv().NoclipActive or getgenv().AntiFlingActive) and k == "Anchored" and v == true then
					return
				end
				if getgenv().NoclipActive and t.Name == "HumanoidRootPart" and k == "CanCollide" and v == true then
					return
				end
			end
		end
		return oldNewIndex(t, k, v)
	end)
	
	setreadonly(mt, true)
end)

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local protectedParent = player:WaitForChild("PlayerGui")
if protectedParent:FindFirstChild("DevPanelGui") then
	protectedParent.DevPanelGui:Destroy()
end

local camera = workspace.CurrentCamera

-- Configuration & Constants
local FLY_SPEED = 50             
local runSpeedValue = 50         
local DOUBLE_TAP_WINDOW = 0.35   

-- Anti-Fling & Anti-Ragdoll Configuration
local MAX_SPEED = 150                 
local MAX_ANGULAR = 50                
local MAX_TELEPORT_DISTANCE = 500     
local DEFAULT_WALKSPEED = 16          
local DEFAULT_JUMPPOWER = 50          
local SMOOTHING_FACTOR = 0.35         

local flyToggleEnabled = false
local isFlying = false
local godModeEnabled = false
local noFallDamageEnabled = false
local runSpeedEnabled = false
local antiFlingEnabled = false        
local antiTrapEnabled = false         
local isMinimized = false
local isTeleporting = false           
local lastPos = nil                   
local isRecovering = false            

local lastJumpTapTime = 0
local lastJumpReqTime = 0
local entrySpawnCFrame = nil
local savedMapCFrame = nil

local character, rootPart, humanoid
local attachment, linearVelocity
local isRestoringStats = false

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
-- LADDER DETECTION FUNCTION
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
-- HARD RAGDOLL RECOVERY SYSTEM
-- ==========================================
local function recoverFromRagdoll()
	if isRecovering or not character or not rootPart or not humanoid then return end
	isRecovering = true
	
	pcall(function() rootPart:SetNetworkOwner(player) end)
	if rootPart.Anchored then rootPart.Anchored = false end
	
	humanoid.PlatformStand = false
	humanoid.Sit = false
	
	rootPart.AssemblyLinearVelocity = Vector3.zero
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
-- SMOOTH STAT RESTORATION
-- ==========================================
local function smoothRestoreStats()
	if isRestoringStats or not humanoid then return end
	isRestoringStats = true
	
	task.spawn(function()
		if not runSpeedEnabled and (humanoid.WalkSpeed <= 0 or humanoid.WalkSpeed > 100) then
			local target = DEFAULT_WALKSPEED
			for i = 1, 8 do
				if not antiFlingEnabled or not humanoid or not humanoid.Parent then break end
				humanoid.WalkSpeed = humanoid.WalkSpeed + (target - humanoid.WalkSpeed) * 0.3
				task.wait(0.02)
			end
			if humanoid and humanoid.Parent then humanoid.WalkSpeed = target end
		end
		
		if humanoid and humanoid.Parent and (humanoid.JumpPower <= 0 or humanoid.JumpPower > 100) then
			local target = DEFAULT_JUMPPOWER
			for i = 1, 8 do
				if not antiFlingEnabled or not humanoid or not humanoid.Parent then break end
				humanoid.JumpPower = humanoid.JumpPower + (target - humanoid.JumpPower) * 0.3
				task.wait(0.02)
			end
			if humanoid and humanoid.Parent then humanoid.JumpPower = target end
		end
		isRestoringStats = false
	end)
end

-- ==========================================
-- UI CREATION
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevPanelGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = protectedParent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 400)
mainFrame.Position = UDim2.new(0.8, -120, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 45, 55)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
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
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 26, 0, 26)
minimizeButton.Position = UDim2.new(1, -34, 0, 7)
minimizeButton.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(200, 200, 210)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 16
minimizeButton.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minimizeButton

local toggleContainer = Instance.new("ScrollingFrame")
toggleContainer.Name = "ToggleContainer"
toggleContainer.Size = UDim2.new(1, 0, 1, -45)
toggleContainer.Position = UDim2.new(0, 0, 0, 45)
toggleContainer.BackgroundTransparency = 1
toggleContainer.BorderSizePixel = 0
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 480) 
toggleContainer.ScrollBarThickness = 4
toggleContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
toggleContainer.Parent = mainFrame

local function createToggleRow(name, yPos, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(0.9, 0, 0, 32)
	row.Position = UDim2.new(0.05, 0, 0, yPos)
	row.BackgroundTransparency = 1
	row.Parent = toggleContainer

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(200, 200, 210)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local switchBg = Instance.new("TextButton")
	switchBg.Size = UDim2.new(0, 40, 0, 20)
	switchBg.Position = UDim2.new(1, -40, 0.5, -10)
	switchBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	switchBg.Text = ""
	switchBg.AutoButtonColor = false
	switchBg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = switchBg

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
	knob.Parent = switchBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local activeState = false
	
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

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = textBox

	textBox.FocusLost:Connect(function()
		local num = tonumber(textBox.Text)
		if num then
			callback(num)
		else
			textBox.Text = tostring(defaultVal)
		end
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(callback)
	return btn
end

-- ==========================================
-- TELEPORT & FLYING LOGIC
-- ==========================================
local function absoluteTeleport(targetCFrame)
	local currentTargetChar = character
	local currentTargetRoot = rootPart
	local currentTargetHum = humanoid
	
	if not currentTargetChar or not currentTargetRoot then return end
	
	isTeleporting = true
	
	if currentTargetHum then
		currentTargetHum.Sit = false
		currentTargetHum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	currentTargetRoot.AssemblyLinearVelocity = Vector3.zero
	currentTargetRoot.AssemblyAngularVelocity = Vector3.zero
	currentTargetRoot.Anchored = true
	
	currentTargetChar:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
	
	task.delay(0.04, function()
		if currentTargetRoot and currentTargetRoot.Parent then
			currentTargetRoot.AssemblyLinearVelocity = Vector3.zero
			currentTargetRoot.AssemblyAngularVelocity = Vector3.zero
			currentTargetRoot.Anchored = false
		end
		if currentTargetHum and currentTargetHum.Parent then
			currentTargetHum:ChangeState(Enum.HumanoidStateType.Running)
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
-- UI CONTROLS BINDING
-- ==========================================
createToggleRow("Flight Mode", 5, function(state)
	flyToggleEnabled = state
	if not state then setFlying(false) end
end)

createToggleRow("God Mode", 40, function(state)
	godModeEnabled = state
	if humanoid then
		if state then
			humanoid.Health = humanoid.MaxHealth
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end
	end
end)

createToggleRow("No Fall Damage", 75, function(state)
	noFallDamageEnabled = state
end)

createToggleRow("Force Noclip Bypass", 110, function(state)
	getgenv().NoclipActive = state
	if state then
		player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	else
		player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
	end
end)

createToggleRow("Absolute Anti-Ragdoll & Anti-Fling", 145, function(state)
	antiFlingEnabled = state
	getgenv().AntiFlingActive = state
	if humanoid then
		if state then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		end
	end
end)

createToggleRow("Anti Trap (CanTouch Only)", 180, function(state)
	antiTrapEnabled = state
	if not state and character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanTouch = true
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

createActionButton("TP to Entry Spawn", 290, Color3.fromRGB(41, 128, 185), function()
	absoluteTeleport(getEntrySpawn())
end)

local saveMapButton = createActionButton("Save Current Map Location", 327, Color3.fromRGB(142, 68, 173), function()
	if not rootPart then return end
	savedMapCFrame = rootPart.CFrame
	saveMapButton.Text = "Map Location Saved!"
	task.delay(1.5, function() saveMapButton.Text = "Save Current Map Location" end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 364, Color3.fromRGB(39, 174, 96), function()
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
		mainFrame.Size = UDim2.new(0, 36, 0, 36)
		toggleContainer.Visible = false
		titleLabel.Visible = false
		stroke.Transparency = 0.5
		minimizeButton.Size = UDim2.new(1, 0, 1, 0)
		minimizeButton.Position = UDim2.new(0, 0, 0, 0)
		minimizeButton.Text = "+"
		minimizeButton.TextSize = 18
	else
		mainFrame.Size = UDim2.new(0, 240, 0, 400)
		toggleContainer.Visible = true
		titleLabel.Visible = true
		stroke.Transparency = 0
		minimizeButton.Size = UDim2.new(0, 26, 0, 26)
		minimizeButton.Position = UDim2.new(1, -34, 0, 7)
		minimizeButton.Text = "-"
		minimizeButton.TextSize = 16
	end
end)

-- ==========================================
-- GAME LOOPS & FLIGHT MECHANICS
-- ==========================================
local function handleJumpTap()
	if not flyToggleEnabled then return end
	local currentTime = os.clock()
	local timeSinceLastTap = currentTime - lastJumpTapTime

	if timeSinceLastTap <= DOUBLE_TAP_WINDOW then
		if isFlying then
			setFlying(false)
		elseif humanoid and (humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping) then
			setFlying(true)
		end
		lastJumpTapTime = 0
	else
		lastJumpTapTime = currentTime
	end
end

UserInputService.JumpRequest:Connect(function()
	local currentTime = os.clock()
	if (currentTime - lastJumpReqTime) > 0.1 then
		handleJumpTap()
	end
	lastJumpReqTime = currentTime
end)

RunService.Stepped:Connect(function()
	if not character or not rootPart then return end
	
	if getgenv().NoclipActive then
		if rootPart.Anchored then rootPart.Anchored = false end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
			
			if part:IsA("BodyForce") or part:IsA("BodyVelocity") or part:IsA("BodyPosition") or part:IsA("VectorForce") or part:IsA("AlignPosition") or part:IsA("LinearVelocity") then
				if part.Name ~= "FlightVelocity" then
					part:Destroy()
				end
			end
		end
	elseif antiTrapEnabled then
		local nearLadder = isNearLadder(character)
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if nearLadder then
					part.CanTouch = true
				else
					part.CanTouch = false
				end
			end
		end
	end
	
	if rootPart.Position.Y < -50 then
		absoluteTeleport(getEntrySpawn())
	end

    if antiFlingEnabled then
        local currentState = humanoid:GetState()
        local isBrokenState = currentState == Enum.HumanoidStateType.Physics 
            or currentState == Enum.HumanoidStateType.Ragdoll 
            or currentState == Enum.HumanoidStateType.FallingDown
            or humanoid.PlatformStand
        
        local lookVector = rootPart.CFrame.LookVector
        local isTilted = math.abs(lookVector.Y) > 0.7
        
        if isBrokenState or isTilted then
            recoverFromRagdoll()
        else
            if rootPart.Anchored and not isTeleporting then 
                rootPart.Anchored = false 
            end

            if not isFlying then
                local vel = rootPart.AssemblyLinearVelocity
                if vel.Magnitude > MAX_SPEED then
                    local targetVel = vel.Unit * MAX_SPEED
                    rootPart.AssemblyLinearVelocity = vel:Lerp(targetVel, SMOOTHING_FACTOR)
                end
            end

            local angVel = rootPart.AssemblyAngularVelocity
            if angVel.Magnitude > MAX_ANGULAR then
                local targetAng = angVel.Unit * MAX_ANGULAR
                rootPart.AssemblyAngularVelocity = angVel:Lerp(targetAng, SMOOTHING_FACTOR)
            end

            local owner = rootPart:GetNetworkOwner()
            if owner and owner ~= player then
                pcall(function() rootPart:SetNetworkOwner(player) end)
            end

            if not isTeleporting and lastPos then
                local currentPos = rootPart.Position
                local distanceMoved = (currentPos - lastPos).Magnitude
                if distanceMoved > MAX_TELEPORT_DISTANCE then
                    local correctionCFrame = CFrame.new(lastPos, lastPos + rootPart.CFrame.LookVector)
                    rootPart.CFrame = rootPart.CFrame:Lerp(correctionCFrame, 0.5)
                else
                    lastPos = currentPos
                end
            else
                lastPos = rootPart.Position
            end

            if not runSpeedEnabled and (humanoid.WalkSpeed <= 0 or humanoid.WalkSpeed > 100) then 
                smoothRestoreStats()
            end
            if humanoid.JumpPower <= 0 or humanoid.JumpPower > 100 then 
                smoothRestoreStats()
            end
        end
    else
        lastPos = rootPart.Position
    end
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
	
	if godModeEnabled and humanoid and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
end)

local function setupCharacter(char)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	humanoid = char:WaitForChild("Humanoid")
	
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
	
	lastPos = rootPart.Position
	
	humanoid.StateChanged:Connect(function(_, newState)
		if antiFlingEnabled then
			if newState == Enum.HumanoidStateType.Ragdoll
			or newState == Enum.HumanoidStateType.FallingDown
			or newState == Enum.HumanoidStateType.Physics then
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
		if antiFlingEnabled and humanoid.PlatformStand then 
			humanoid.PlatformStand = false 
		end
	end)
	
	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		if antiFlingEnabled and humanoid.Sit then 
			humanoid.Sit = false 
		end
	end)

	char.DescendantAdded:Connect(function(child)
		if antiTrapEnabled and child:IsA("BasePart") then
			if not isNearLadder(char) then
				child.CanTouch = false
			end
		end
		
		if antiFlingEnabled then
			if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") 
			or child:IsA("LinearVelocity") or child:IsA("AngularVelocity")
			or child:IsA("AlignPosition") or child:IsA("AlignOrientation")
			or child:IsA("Weld") or child:IsA("Motor6D") then
				
				if child:IsA("Motor6D") and child.Name ~= "FlingMotor" then return end
				if child.Name == "FlightVelocity" then return end
				
				task.defer(function()
					if child and child.Parent then child:Destroy() end
				end)
			end
		end
	end)
	
	if antiFlingEnabled then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	end
	
	if godModeEnabled then
		humanoid.Health = humanoid.MaxHealth
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	
	if flyToggleEnabled then
		setFlying(true)
	end
end

setupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(function(newChar)
	-- [FIX] Removed the lines that were resetting the flight toggle.
	-- Now if the UI switch is still ON, flight mode will re-activate automatically.
	if linearVelocity then linearVelocity.MaxForce = 0 end
	setupCharacter(newChar)
end)
