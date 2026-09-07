local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configuration & Constants
local FLY_SPEED = 50             
local DOUBLE_TAP_WINDOW = 0.35   
local GOD_HEALTH_VAL = 1000000   

local flyToggleEnabled = false
local isFlying = false
local godModeEnabled = false
local noFallDamageEnabled = false
local noclipEnabled = false

local lastJumpTapTime = 0
local lastJumpReqTime = 0
local healthConnection = nil
local stateConnection = nil
local fallDamageConnection = nil
local noclipConnection = nil
local charAddedConnection = nil
local isMinimized = false

local entrySpawnCFrame = nil
local savedMapCFrame = nil
local preFallHealth = 100
local originalCollisions = {}

-- Advanced Anti-Detection & Server Kick Bypass Hook
local _env = getgenv and getgenv() or shared
_env["_SECURE_HANDLER_" .. math.random(10000, 99999)] = tick()

pcall(function()
	if hookmetamethod and getnamecallmethod then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if (method == "Kick" or method == "kick") and self == player then
				return 
			end
			return oldNamecall(self, ...)
		end)
	end
end)

pcall(function()
	LogService.MessageOut:Connect(function(msg, messageType)
		if messageType == Enum.MessageType.MessageError and (string.find(msg, "Exploit") or string.find(msg, "Kick")) then
			-- Suppress exploit tracking logs
		end
	end)
end)

-- ==========================================
-- UI CREATION (GR33D Scripts Modern Panel)
-- ==========================================
local protectedParent = (gethui and gethui()) or player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoreGui_" .. math.random(100, 999)
screenGui.ResetOnSpawn = false
screenGui.Parent = protectedParent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 220, 0, 370)
mainFrame.Position = UDim2.new(0.8, -110, 0.5, -185)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 38)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "GR33D Scripts"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.Parent = mainFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.Position = UDim2.new(1, -32, 0, 7)
minimizeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 16
minimizeButton.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeButton

local toggleContainer = Instance.new("ScrollingFrame")
toggleContainer.Name = "ToggleContainer"
toggleContainer.Size = UDim2.new(1, 0, 1, -40)
toggleContainer.Position = UDim2.new(0, 0, 0, 40)
toggleContainer.BackgroundTransparency = 1
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
