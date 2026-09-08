-- ==========================================
-- ABSOLUTE ANTI-CHEAT & HOOK PROTECTION
-- ==========================================
pcall(function()
	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	
	local oldNamecall = mt.__namecall
	local oldNewIndex = mt.__newindex
	
	-- Block Kick attempts
	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if not checkcaller() and (method == "Kick" or method == "kick") and self == game.Players.LocalPlayer then
			warn("[Anti-Cheat Shield] Blocked unauthorized Kick attempt.")
			return
		end
		return oldNamecall(self, ...)
	end)
	
	-- Block anti-cheats from modifying collisions, teleports, velocity, and ANCHORING
	mt.__newindex = newcclosure(function(t, k, v)
		if not checkcaller() and typeof(t) == "Instance" and t:IsA("BasePart") then
			local char = game.Players.LocalPlayer.Character
			if char and t:IsDescendantOf(char) then
				
				-- Keep HumanoidRootPart non-collidable
				if t.Name == "HumanoidRootPart" and k == "CanCollide" and v == true then
					return
				end
				
				-- Stop the game from freezing you mid-air
				if k == "Anchored" and v == true then
					return
				end
				
				-- Block noclip position/velocity overrides
				if getgenv().NoclipActive and (k == "CFrame" or k == "Position" or k == "AssemblyLinearVelocity") then
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

getgenv().NoclipActive = false 

local flyToggleEnabled = false
local isFlying = false
local godModeEnabled = false
local noFallDamageEnabled = false
local ragdollEnabled = false
local runSpeedEnabled = false
local isMinimized = false

local lastJumpTapTime = 0
local lastJumpReqTime = 0
local entrySpawnCFrame = nil
local savedMapCFrame = nil

local character, rootPart, humanoid
local attachment, linearVelocity

-- Controls module handler for smooth camera-relative flight
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
-- UI CREATION (GR33D Scripts)
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
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 420)
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

createToggleRow("Absolute Hit/Ragdoll Immunity", 145, function(state)
	ragdollEnabled = state
	if humanoid then
		if state then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		end
	end
end)

createToggleRow("Super Run Speed", 180, function(state)
	runSpeedEnabled = state
end)

createInputRow("Run Speed Value", 215, 50, function(value)
	runSpeedValue = value
end)

createActionButton("TP to Entry Spawn", 255, Color3.fromRGB(41, 128, 185), function()
	absoluteTeleport(getEntrySpawn())
end)

local saveMapButton = createActionButton("Save Current Map Location", 292, Color3.fromRGB(142, 68, 173), function()
	if not rootPart then return end
	savedMapCFrame = rootPart.CFrame
	saveMapButton.Text = "Map Location Saved!"
	task.delay(1.5, function() saveMapButton.Text = "Save Current Map Location" end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 329, Color3.fromRGB(39, 174, 96), function()
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
	
	if rootPart.Anchored then
		rootPart.Anchored = false
	end
	
	if getgenv().NoclipActive then
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
	else
		if rootPart.CanCollide then
			rootPart.CanCollide = false
		end
		
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 0, 0)
				part.CollisionGroup = "Default"
				
				if not part.CanTouch then part.CanTouch = true end
				if not part.CanQuery then part.CanQuery = true end
			end
		end
	end
	
	if rootPart.Position.Y < -50 then
		absoluteTeleport(getEntrySpawn())
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
	flyToggleEnabled = false
	isFlying = false
	if linearVelocity then linearVelocity.MaxForce = 0 end
	setupCharacter(newChar)
end)qmainFrame.Parent = screenGui

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
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 420)
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

createToggleRow("Absolute Hit/Ragdoll Immunity", 145, function(state)
	ragdollEnabled = state
	if humanoid then
		if state then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		end
	end
end)

createToggleRow("Super Run Speed", 180, function(state)
	runSpeedEnabled = state
end)

createInputRow("Run Speed Value", 215, 50, function(value)
	runSpeedValue = value
end)

createActionButton("TP to Entry Spawn", 255, Color3.fromRGB(41, 128, 185), function()
	absoluteTeleport(getEntrySpawn())
end)

local saveMapButton = createActionButton("Save Current Map Location", 292, Color3.fromRGB(142, 68, 173), function()
	if not rootPart then return end
	savedMapCFrame = rootPart.CFrame
	saveMapButton.Text = "Map Location Saved!"
	task.delay(1.5, function() saveMapButton.Text = "Save Current Map Location" end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 329, Color3.fromRGB(39, 174, 96), function()
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
	
	if rootPart.Anchored then
		rootPart.Anchored = false
	end
	
	if getgenv().NoclipActive then
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
	else
		if rootPart.CanCollide then
			rootPart.CanCollide = false
		end
		
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 0, 0)
				part.CollisionGroup = "Default"
				
				if not part.CanTouch then part.CanTouch = true end
				if not part.CanQuery then part.CanQuery = true end
			end
		end
	end
	
	if rootPart.Position.Y < -50 then
		absoluteTeleport(getEntrySpawn())
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
	flyToggleEnabled = false
	isFlying = false
	if linearVelocity then linearVelocity.MaxForce = 0 end
	setupCharacter(newChar)
end)toggleContainer.BackgroundTransparency = 1
toggleContainer.BorderSizePixel = 0
toggleContainer.CanvasSize = UDim2.new(0, 0, 0, 330)
toggleContainer.ScrollBarThickness = 3
toggleContainer.Parent = mainFrame

local function createToggleRow(name, yPos, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(0.9, 0, 0, 34)
	row.Position = UDim2.new(0.05, 0, 0, yPos)
	row.BackgroundTransparency = 1
	row.Parent = toggleContainer

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(220, 220, 230)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local switchBg = Instance.new("TextButton")
	switchBg.Size = UDim2.new(0, 44, 0, 22)
	switchBg.Position = UDim2.new(1, -44, 0.5, -11)
	switchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	switchBg.Text = ""
	switchBg.AutoButtonColor = false
	switchBg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = switchBg

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	knob.Parent = switchBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local activeState = false
	
	switchBg.MouseButton1Click:Connect(function()
		activeState = not activeState
		if activeState then
			switchBg.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
			knob:TweenPosition(UDim2.new(1, -19, 0.5, -8), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
		else
			switchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			knob:TweenPosition(UDim2.new(0, 3, 0.5, -8), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
		end
		callback(activeState)
	end)

	return row
end

local function createActionButton(name, yPos, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 32)
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
-- PHYSICS & REFERENCES SETUP
-- ==========================================
local attachment = Instance.new("Attachment")
attachment.Name = "FlightAttachment"

local linearVelocity = Instance.new("LinearVelocity")
linearVelocity.Name = "FlightVelocity"
linearVelocity.Attachment0 = attachment
linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
linearVelocity.MaxForce = 0
linearVelocity.VectorVelocity = Vector3.zero

local jetpackAttachment = Instance.new("Attachment")
jetpackAttachment.Name = "JetpackExhaust"
jetpackAttachment.Position = Vector3.new(0, 0, 0.6)
jetpackAttachment.Orientation = Vector3.new(-90, 0, 0)

local flameEmitter = Instance.new("ParticleEmitter")
flameEmitter.Name = "ThrusterFlame"
flameEmitter.Texture = "rbxassetid://258122325"
flameEmitter.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 0))
})
flameEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.8),
	NumberSequenceKeypoint.new(1, 0.1)
})
flameEmitter.Lifetime = NumberRange.new(0.1, 0.25)
flameEmitter.Rate = 80
flameEmitter.Speed = NumberRange.new(20, 30)
flameEmitter.Enabled = false

local character, rootPart, humanoid

-- ==========================================
-- ROBUST TELEPORTATION ENGINE
-- ==========================================
local function safeTeleport(targetCFrame)
	if not character or not rootPart then return end
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
	end
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	task.wait(0.01)
	if not character or not rootPart or not rootPart.Parent then return end
	character:PivotTo(targetCFrame)
	rootPart.AssemblyLinearVelocity = Vector3.zero
end

local function getEntrySpawn()
	if entrySpawnCFrame then
		return entrySpawnCFrame
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") and obj.Enabled then
			return obj.CFrame + Vector3.new(0, 3, 0)
		end
	end
	if rootPart then
		return rootPart.CFrame
	end
	return CFrame.new(0, 5, 0)
end

-- ==========================================
-- FUNCTIONALITY IMPLEMENTATIONS
-- ==========================================
local function setFlying(state)
	if not rootPart or not humanoid then return end
	isFlying = state

	if isFlying then
		linearVelocity.MaxForce = 100000 
		flameEmitter.Enabled = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	else
		linearVelocity.MaxForce = 0
		linearVelocity.VectorVelocity = Vector3.zero
		flameEmitter.Enabled = false
		
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end
end

local function applyGodMode()
	if not humanoid then return end
	if healthConnection then healthConnection:Disconnect() healthConnection = nil end
	if stateConnection then stateConnection:Disconnect() stateConnection = nil end

	if godModeEnabled then
		humanoid.MaxHealth = GOD_HEALTH_VAL
		humanoid.Health = GOD_HEALTH_VAL
		
		healthConnection = RunService.Heartbeat:Connect(function()
			if godModeEnabled and humanoid and humanoid.Parent then
				if humanoid.MaxHealth < GOD_HEALTH_VAL then humanoid.MaxHealth = GOD_HEALTH_VAL end
				if humanoid.Health < GOD_HEALTH_VAL then humanoid.Health = GOD_HEALTH_VAL end
			end
		end)

		stateConnection = humanoid.StateChanged:Connect(function(_, newState)
			if godModeEnabled and newState == Enum.HumanoidStateType.Dead then
				humanoid.Health = GOD_HEALTH_VAL
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)
	else
		humanoid.MaxHealth = 100
		humanoid.Health = math.clamp(humanoid.Health, 0, 100)
	end
end

local function applyNoFallDamage()
	if not humanoid then return end
	if fallDamageConnection then fallDamageConnection:Disconnect() fallDamageConnection = nil end

	if noFallDamageEnabled then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		
		fallDamageConnection = humanoid.StateChanged:Connect(function(_, newState)
			if noFallDamageEnabled then
				if newState == Enum.HumanoidStateType.Freefall then
					preFallHealth = humanoid.Health
				elseif newState == Enum.HumanoidStateType.Landed then
					if isFlying then setFlying(false) end
					task.defer(function()
						if noFallDamageEnabled and humanoid and humanoid.Health < preFallHealth and not godModeEnabled then
							humanoid.Health = preFallHealth
						end
					end)
				end
			end
		end)
	else
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	end
end

local function applyNoclip()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end

	if noclipEnabled then
		originalCollisions = {}
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					originalCollisions[part] = part.CanCollide
					part.CanCollide = false
				end
			end
		end
		noclipConnection = RunService.Stepped:Connect(function()
			if character and noclipEnabled then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						originalCollisions[part] = true
						part.CanCollide = false
					end
				end
			end
		end)
	else
		if character then
			for part, originalState in pairs(originalCollisions) do
				if part and part.Parent then
					part.CanCollide = originalState
				end
			end
		end
		originalCollisions = {}
	end
end

-- ==========================================
-- UI CONTROLS BINDING
-- ==========================================
createToggleRow("Flight Mode", 5, function(state)
	flyToggleEnabled = state
	if not state then setFlying(false) end
end)

createToggleRow("God Mode", 45, function(state)
	godModeEnabled = state
	applyGodMode()
end)

createToggleRow("No Fall Damage", 85, function(state)
	noFallDamageEnabled = state
	applyNoFallDamage()
end)

createToggleRow("NoClip Through Walls", 125, function(state)
	noclipEnabled = state
	applyNoclip()
end)

createActionButton("TP to Entry Spawn", 175, Color3.fromRGB(43, 114, 186), function()
	safeTeleport(getEntrySpawn())
end)

local saveMapButton = createActionButton("Save Current Map Location", 215, Color3.fromRGB(114, 43, 186), function()
	if not rootPart then return end
	savedMapCFrame = rootPart.CFrame
	saveMapButton.Text = "Map Location Saved!"
	task.delay(1.5, function()
		saveMapButton.Text = "Save Current Map Location"
	end)
end)

local tpMapButton = createActionButton("TP to Saved Map Location", 255, Color3.fromRGB(43, 156, 114), function()
	if savedMapCFrame then
		safeTeleport(savedMapCFrame)
	else
		tpMapButton.Text = "No Location Saved Yet!"
		task.delay(1.5, function()
			tpMapButton.Text = "TP to Saved Map Location"
		end)
	end
end)

minimizeButton.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		mainFrame.Size = UDim2.new(0, 220, 0, 38)
		toggleContainer.Visible = false
		minimizeButton.Text = "+"
	else
		mainFrame.Size = UDim2.new(0, 220, 0, 370)
		toggleContainer.Visible = true
		minimizeButton.Text = "-"
	end
end)

-- ==========================================
-- CHARACTER SETUP & RESPAWN HANDLING
-- ==========================================
local function setupCharacter(char)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	humanoid = char:WaitForChild("Humanoid")

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if torso then
		jetpackAttachment.Parent = torso
		flameEmitter.Parent = jetpackAttachment
	end

	attachment.Parent = rootPart
	linearVelocity.Parent = rootPart
	
	task.delay(0.6, function()
		if rootPart and not entrySpawnCFrame then
			entrySpawnCFrame = rootPart.CFrame
		end
	end)

	applyGodMode()
	applyNoFallDamage()
	if noclipEnabled then
		applyNoclip()
	end
end

setupCharacter(player.Character or player.CharacterAdded:Wait())

if charAddedConnection then charAddedConnection:Disconnect() end
charAddedConnection = player.CharacterAdded:Connect(function(newChar)
	flyToggleEnabled = false
	isFlying = false
	linearVelocity.MaxForce = 0
	setupCharacter(newChar)
end)

local function handleJumpTap()
	if not flyToggleEnabled then return end
	
	local currentTime = os.clock()
	local timeSinceLastTap = currentTime - lastJumpTapTime

	if timeSinceLastTap <= DOUBLE_TAP_WINDOW then
		if isFlying then
			setFlying(false)
		elseif humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping then
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

RunService.RenderStepped:Connect(function()
	if not isFlying or not rootPart or not humanoid then return end

	if humanoid.FloorMaterial ~= Enum.Material.Air then
		setFlying(false)
		return
	end

	if controls then
		local moveVector = controls:GetMoveVector()
		if moveVector.Magnitude > 0 then
			local camCFrame = camera.CFrame
			local flightDir = (camCFrame.RightVector * moveVector.X) - (camCFrame.LookVector * moveVector.Z)
			linearVelocity.VectorVelocity = flightDir.Unit * FLY_SPEED
		else
			linearVelocity.VectorVelocity = Vector3.zero
		end
	end
end)
