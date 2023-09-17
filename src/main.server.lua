-- Stub for local debugging, change to true to temporarily
-- disable the plugin.
if false then
	return
end

--Updated 2018:
-- * Now works with the changed options saving

--Updated Dec 2019: Edge highlight now
-- * Edge highlight is now drawn with always on top HandleAdornments
--   instead of parts.
-- * Decreased Minimum Thickness to 0.05 (the new engine allowed
--   minimum thickness at present.
-- * For very small details parts will now be created with the minimum
--   possible specialmesh scaling. For example, if a 0.01 x 0.1 x 1 part
--   would be created, it will be created at 0.05 x 0.1 x 1 with a
--   specialmesh scaling it by 0.2, 1.0, 1.0.

--Updated May 2022:
-- * Port over improved panel UX from ResizeAlign
-- * Change to copy over part Color instead of BrickColor

--Updated July 2023:
-- * Fixed handling of new PartType values (Wedge / CornerWedge)

--Updated Sept 2023:
-- * Migrated to open source Rojo repo: Beginning of Git history.

----[=[
------------------
--DEFAULT VALUES--
------------------
-- has the plugin been loaded?
local loaded = false

-- is the plugin currently active?
local on = false

local mouse;

local UserInputService = game:GetService("UserInputService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)
local createSharedToolbar = require(Packages.createSharedToolbar)
local DraggerHandler = require(Packages.DraggerHandler)
local doFill = require(Src.doFill)

local draggerHandler = DraggerHandler.new(plugin)

----------------
--PLUGIN SETUP--
----------------
-- an event that is fired before the plugin deactivates
local deactivatingEvent = Instance.new("BindableEvent")

local mouseCnList = {}

local On, Off;

-- create the plugin and toolbar, and connect them to the On/Off activation functions
plugin.Deactivation:Connect(function()
	Off()
end)

local sharedToolbarSettings = {} :: createSharedToolbar.SharedToolbarSettings
sharedToolbarSettings.CombinerName = "GeomToolsToolbar"
sharedToolbarSettings.ToolbarName = "GeomTools"
sharedToolbarSettings.ButtonName = "GapFill"
sharedToolbarSettings.ButtonIcon = "rbxassetid://4521972465"
sharedToolbarSettings.ButtonTooltip = "Generate geometry filling the space between two selected part edges."
sharedToolbarSettings.ClickedFn = function()
	if on then
		deactivatingEvent:Fire()
		Off()
	elseif loaded then
		On()
	end
end
createSharedToolbar(plugin, sharedToolbarSettings)

-- Run when the popup is activated.
function On()
	plugin:Activate(true)
	sharedToolbarSettings.Button:SetActive(true)
	on = true
	mouse = plugin:GetMouse(true)
	table.insert(mouseCnList, mouse.Button1Down:connect(function()
		MouseDown()
	end))
	table.insert(mouseCnList, mouse.Button1Up:connect(function()
		MouseUp()
	end))
	table.insert(mouseCnList, mouse.Move:connect(function()
		MouseMove()
	end))
	table.insert(mouseCnList, mouse.Idle:connect(function()
		MouseIdle()
	end))
	table.insert(mouseCnList, mouse.KeyDown:connect(function()
		KeyDown()
	end))
	--
	Selected()
end

-- Run when the popup is deactivated.
function Off()
	draggerHandler:disable()
	sharedToolbarSettings.Button:SetActive(false)
	on = false
	for i, cn in pairs(mouseCnList) do
		cn:disconnect()
		mouseCnList[i] = nil
	end
	--
	Deselected()
end

local PLUGIN_NAME = 'GapFill'
function SetSetting(setting, value)
	plugin:SetSetting(PLUGIN_NAME..setting, value)
end
function GetSetting(setting)
	return plugin:GetSetting(PLUGIN_NAME..setting)
end

-------------
--UTILITIES--
-------------

local function drawFace(parent, face, color, trans, zmod)
	local scale = math.max(face.vertexMargin, 0.15) / 8
	if scale > 0.2 then
		scale = 0.2
	end

	local segmentCFrame = CFrame.new(face.a, face.b) * CFrame.new(0, 0, -face.length/2)
	local tipLength = math.min(0.3 * face.length, scale * 15)
	local tipRadius = 0.5 * tipLength
	local shaftRadius = 0.5 * 0.5 * math.min(0.3 * face.length, scale * 7)

	local line = Instance.new('CylinderHandleAdornment')
	line.CFrame = segmentCFrame * CFrame.new(0, 0, tipLength/2) * CFrame.Angles(0, 0, math.pi/2)
	line.Adornee = workspace.Terrain
	line.ZIndex = 0 + zmod
	line.Height = face.length - tipLength
	line.Radius = shaftRadius
	line.Color3 = color
	line.Transparency = trans
	line.Parent = parent
	line.AlwaysOnTop = false

	local lineOnTop = line:Clone()
	lineOnTop.Parent = parent
	lineOnTop.Transparency = 0.7
	lineOnTop.AlwaysOnTop = true

	local head = Instance.new('ConeHandleAdornment')
	head.CFrame = segmentCFrame * CFrame.new(0, 0, -(face.length/2 - tipLength)) * CFrame.Angles(0, 0, math.pi/2)
	head.Adornee = workspace.Terrain
	head.ZIndex = 1 + zmod
	head.Height = tipLength
	head.Radius = tipRadius
	head.Color3 = color
	head.Transparency = trans
	head.Parent = parent
	head.AlwaysOnTop = false

	local headOnTop = head:Clone()
	headOnTop.Parent = parent
	headOnTop.Transparency = 0.7
	headOnTop.AlwaysOnTop = true

	return {line, head, lineOnTop, headOnTop}
end

local function show(point)
	local part = Instance.new('Part')
	part.Name = 'Point'
	part.BrickColor = BrickColor.new(21)
	part.FormFactor = 'Custom'
	part.Anchored = true
	part.Size = Vector3.new()
	part.CFrame = CFrame.new(point)
	part.Parent = game.Workspace
end

------------------
--IMPLEMENTATION--
------------------

local mTargetFilter = Instance.new('Folder')
mTargetFilter.Name = '$TargetFilter'
mTargetFilter.Archivable = false

local mState = "EdgeA" -- | "EdgeB"
local mEdgeA = nil
local mEdgeADrawn = nil
local mEdgeB = nil

local mModeScreenGui = Instance.new('ScreenGui')
local DARK_RED = Color3.new(0.705882, 0, 0)

local function MakeModeGui(ident, pos, topText, options, optionDetails, optionIcons)
	optionDetails = optionDetails or {}
	optionIcons = optionIcons or {}
	topText = topText or ""
	local H = 30
	local optCount = #options

	local this = {}

	local mHintOn = false

	local mContainer = Instance.new('ImageButton', mModeScreenGui)
	mContainer.BackgroundTransparency = 1
	mContainer.Size = UDim2.new(0, 212, 0, 6+(H+6)*optCount + 20)
	mContainer.Position = pos
	--
	local mDragConnection;
	mContainer.InputBegan:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			local initialX = mContainer.Position.X.Offset
			local initialY = mContainer.Position.Y.Offset
			local dragStart = inputObject.Position
			mDragConnection = UserInputService.InputChanged:Connect(function(inputObject: InputObject)
				if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = inputObject.Position - dragStart
					mContainer.Position = UDim2.fromOffset(initialX + delta.X, initialY + delta.Y)
				end
			end)
		end
	end)
	mContainer.InputEnded:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			if mDragConnection then
				mDragConnection:Disconnect()
				mDragConnection = nil
			end
			SetSetting('WindowPos_'..ident, {mContainer.AbsolutePosition.X, mContainer.AbsolutePosition.Y})
		end
	end)
	do
		local setting = GetSetting('WindowPos_'..ident)
		if setting then
			local tempWnd = Instance.new('ScreenGui', game:GetService('CoreGui'))
			local w = mContainer.Size.X.Offset
			local h = mContainer.Size.Y.Offset
			local fullw = tempWnd.AbsoluteSize.X
			local fullh = tempWnd.AbsoluteSize.Y
			tempWnd:Destroy()
			mContainer.Position = UDim2.new(0, math.min((setting[1] or setting['1'] or 0) + w, fullw) - w, 0, math.min((setting['2'] or setting[2] or 0) + h, fullh) - h)
		end
	end

	local mModeGui = Instance.new('Frame', mContainer)
	mModeGui.Name = "ModeGui"
	mModeGui.Position = UDim2.new(0, 0, 0, 20)
	mModeGui.Size = UDim2.new(0, 222, 0, 6+(H+6)*optCount)
	mModeGui.BackgroundTransparency = 1
	--
	local CONTENT_PADDING = UDim.new(0, 4)
	local mContent = Instance.new("Frame", mModeGui)
	mContent.AutomaticSize = Enum.AutomaticSize.Y
	mContent.Size = UDim2.new(1, 0, 0, 0)
	mContent.BackgroundColor3 = Color3.new(0, 0, 0)
	mContent.BorderSizePixel = 0
	mContent.BackgroundTransparency = 0.2
	local padding = Instance.new("UIPadding", mContent)
	padding.PaddingTop = CONTENT_PADDING
	padding.PaddingBottom = CONTENT_PADDING
	padding.PaddingRight = CONTENT_PADDING
	padding.PaddingLeft = CONTENT_PADDING
	local mLayout = Instance.new("UIListLayout", mContent)
	mLayout.Padding = UDim.new(0, 5)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	--
	local mTopText = Instance.new('TextLabel', mModeGui)
	mTopText.Name = "TopText"
	mTopText.Size = UDim2.new(0.7, 0, 0, 20)
	mTopText.Position = UDim2.new(0, 0, 0, -20)
	mTopText.BorderSizePixel = 0
	mTopText.Font = Enum.Font.SourceSansBold
	mTopText.TextSize = 16
	mTopText.TextXAlignment = Enum.TextXAlignment.Left
	mTopText.Text = " :: " .. topText
	mTopText.TextColor3 = Color3.new(1, 1, 1)
	mTopText.BackgroundColor3 = Color3.new(0, 0, 0)
	mTopText.BackgroundTransparency = 0.2
	--
	local mBottomText = Instance.new('TextLabel', mContent)
	mBottomText.Name = "BottomText"
	mBottomText.Size = UDim2.new(1, 0, 0, 0)
	mBottomText.Font = Enum.Font.SourceSans
	mBottomText.TextSize = 16
	mBottomText.TextXAlignment = Enum.TextXAlignment.Left
	mBottomText.TextYAlignment = Enum.TextYAlignment.Top
	mBottomText.Text = ""
	mBottomText.TextColor3 = Color3.new(1, 1, 1)
	mBottomText.BackgroundColor3 = Color3.new(0, 0, 0)
	mBottomText.BackgroundTransparency = 0.2
	mBottomText.BorderSizePixel = 0
	mBottomText.Visible = false
	mBottomText.TextWrapped = true
	mBottomText.LayoutOrder = 100
	mBottomText.AutomaticSize = Enum.AutomaticSize.Y
	--
	local mTopQ = Instance.new('TextButton', mModeGui)
	mTopQ.Size = UDim2.new(0, 20, 0, 20)
	mTopQ.Position = UDim2.new(1, -20, 0, -20)
	mTopQ.BorderSizePixel = 0
	mTopQ.BorderColor3 = Color3.new(1, 1, 1)
	mTopQ.TextSize = 20
	mTopQ.Font = Enum.Font.SourceSansBold
	mTopQ.TextColor3 = Color3.new(1, 1, 1)
	mTopQ.BackgroundColor3 = Color3.new(0, 0, 0)
	mTopQ.BackgroundTransparency = 0.2
	mTopQ.Text = "?"
	mTopQ.MouseButton1Down:Connect(function()
		mHintOn = not mHintOn
		if mHintOn then
			mTopQ.BorderColor3 = Color3.new(1, 0, 0)
			mTopQ.BorderSizePixel = 2
			mBottomText.Visible = true
			mBottomText.Text = "General Usage: Select two faces of parts to resize them such that they are aligned in some way.\nMouse over the options to get a description of them."
		else
			mTopQ.BorderColor3 = Color3.new(1, 1, 1)
			mTopQ.BorderSizePixel = 0
			mBottomText.Visible = false
		end
	end)
	mTopQ.MouseEnter:Connect(function()
		if not mHintOn then
			mTopQ.BorderColor3 = Color3.new(1, 1, 1)
			mTopQ.BorderSizePixel = 1
		end
	end)
	mTopQ.MouseLeave:Connect(function()
		if not mHintOn then
			mTopQ.BorderSizePixel = 0
		end
	end)
	local mTopQOutline = Instance.new("UIStroke", mTopQ)
	mTopQOutline.Color = DARK_RED
	--
	local optionGuis = {}
	local function resetOptionGuis()
		for _, gui in pairs(optionGuis) do
			gui.Border.Enabled = false
			gui.ZIndex = 1
		end
	end
	local function selectOption(option, gui)
		resetOptionGuis()
		gui.Border.Enabled = true
		gui.ZIndex = 2
		this.Mode = option
		SetSetting('Current_'..ident, option)
	end
	--
	for index, option in pairs(options) do
		local modeGui = Instance.new('TextButton', mContent)
		modeGui.Text = option
		modeGui.BackgroundColor3 = Color3.new(0, 0, 0)
		modeGui.TextColor3 = Color3.new(1, 1, 1)
		modeGui.BorderColor3 = Color3.new(0.203922, 0.203922, 0.203922)
		modeGui.TextXAlignment = Enum.TextXAlignment.Left
		modeGui.Font = Enum.Font.SourceSansBold
		modeGui.TextSize = 24
		modeGui.Size = UDim2.new(1, 0, 0, H)
		modeGui.BackgroundTransparency = 0 --1 --0.3
		modeGui.LayoutOrder = index
		modeGui.AutomaticSize = Enum.AutomaticSize.Y
		modeGui.MouseEnter:connect(function()
			if mHintOn then
				mBottomText.Text = optionDetails[index] or ""
				mBottomText.Visible = true
			end
		end)
		local padding = Instance.new("UIPadding", modeGui)
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 2)
		padding.PaddingBottom = UDim.new(0, 2)
		padding.PaddingRight = UDim.new(0, 2)
		if optionIcons[index] then
			local icon = Instance.new("ImageLabel", modeGui)
			icon.AnchorPoint = Vector2.new(1, 0)
			icon.Position = UDim2.new(1, 0, 0, 0.5)
			icon.Size = UDim2.fromOffset(64, 32)
			icon.Image = optionIcons[index]
			icon.Name = "Icon"
			icon.ZIndex = 2
		end
		local border = Instance.new("UIStroke", modeGui)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.LineJoinMode = Enum.LineJoinMode.Round
		border.Color = DARK_RED
		border.Thickness = 5
		border.Enabled = false
		border.Name = "Border"
		--
		modeGui.MouseButton1Down:connect(function()
			selectOption(option, modeGui)
		end)
		table.insert(optionGuis, modeGui)
	end
	--
	local previousOption = GetSetting('Current_'..ident)
	local hadPreviousValue = false
	if previousOption then
		for i, option in ipairs(options) do
			if option == previousOption then
				selectOption(options[i], optionGuis[i])
				hadPreviousValue = true
				break
			end
		end
	end
	-- Didn't manage to load previous choice
	if not hadPreviousValue then
		selectOption(options[1], optionGuis[1])
	end
	--
	return this
end

local FORCE_DEFAULT = "Default"
local FORCE_NEGATIVE = "Negative"

local mModeOption = MakeModeGui('Mode', UDim2.new(0, 20, 0, 20), "Force Direction", 
	{
		FORCE_DEFAULT,
		FORCE_NEGATIVE,
	},
	{
		"The plugin will guess what side is the \"top\", that you want to be flush with the edges. (In most cases, the plugin guesses right)",
		"Force the plugin to make the opposite choice to what it guessed, in case it guesses wrong."
	})

local THICKNESS_BEST_GUESS = "Best Guess"
local THICKNESS_ONE_STUD = "One Stud"
local THICKNESS_PLATE = "Plate"
local THICKNESS_THINNEST = "Thinnest"

local mThicknessOption = MakeModeGui('Thickness', UDim2.new(0, 20, 0, 120), "Part Thickness", 
	{
		THICKNESS_BEST_GUESS,
		THICKNESS_ONE_STUD,
		THICKNESS_PLATE,
		THICKNESS_THINNEST,
	},
	{
		"Make the spanning parts about as thick as the parts whose edges you selected.",
		"Make the spanning parts 1 studs thick.",
		"Make the spanning parts 0.2 studs thick. (Thin, but they will still have good collision properties)",
		"Make the spanning parts as thin as possible. (0.05 studs)"
	})

local mIgnoreNextTargetFilterDeparent = false

local function FixTargetFilter()
	if not mTargetFilter.Parent then
		if mEdgeADrawn then
			for _, o in pairs(mEdgeADrawn) do
				o:Destroy()
			end
		end
		mTargetFilter = Instance.new('Model')
		mTargetFilter.Name = '$TargetFilter'
		mTargetFilter.Archivable = false
		if on then
			mTargetFilter.Parent = workspace
			mouse.TargetFilter = mTargetFilter
		end
	end
end

-- Hover Face
local mHoverFaceDrawn = {}
function showHoverEdge(face)
	hideHoverEdge()
	local color = (mState == "EdgeA") and Color3.new(1, 0, 0) or Color3.new(0, 0, 1)
	mHoverFaceDrawn = drawFace(mTargetFilter, face, color, 0, 2)
end
function hideHoverEdge()
	for _, ch in pairs(mHoverFaceDrawn) do
		ch:Destroy()
	end
	mHoverFaceDrawn = {}
end

function getHoverEdgeSimple(hit: RaycastResult)
	local point = hit.Position
	local geom = Geometry.getGeometry(hit.Instance, point)
	--
	local bestEdge = nil
	local bestDist = math.huge
	--
	for _, edge in pairs(geom.edges) do
		local dist = (point - edge.a - edge.direction*(point - edge.a):Dot(edge.direction)).magnitude
		if dist < bestDist then
			bestDist = dist
			bestEdge = edge
		end
	end
	--
	if bestEdge then
		bestEdge.click = point
		--
		if (bestEdge.a - bestEdge.click).magnitude < (bestEdge.b - bestEdge.click).magnitude then
			bestEdge.a, bestEdge.b = bestEdge.b, bestEdge.a
			bestEdge.direction = -bestEdge.direction
		end
	end
	--
	local bestFace = nil
	bestDist = math.huge
	--
	for _, face in pairs(geom.faces) do
		local dist = math.abs((point - face.point):Dot(face.normal))
		if dist < bestDist then
			bestDist = dist
			bestFace = face
		end
	end
	--
	return bestEdge, bestFace
end

local function mouseRaycast(): RaycastResult?
	local screenLoc = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ScreenPointToRay(screenLoc.X, screenLoc.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 9999)
end

local function getPrimaryEdge(result: RaycastResult)
	-- Try to use raycasts to identify the closest mesh edge for MeshParts / Unions
	if result.Instance:IsA("MeshPart") or result.Instance:IsA("UnionOperation") then
		local edge = Geometry.blackboxFindClosestMeshEdge(result, workspace.CurrentCamera.CFrame.LookVector)
		if edge then
			edge.click = result.Position
			return edge
		end
	end

	-- Failing that, just use the simple getGeometry based result
	return getHoverEdgeSimple(result)
end

local function getSimpleExtension(fromPart: BasePart, point: Vector3, dir: Vector3): (BasePart?, number?)
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {fromPart}
	local parts = workspace:GetPartBoundsInBox(CFrame.new(point), Vector3.new(0.1, 0.1, 0.1), params)
	for _, part in parts do
		local geometry = Geometry.getGeometry(part, point)
		for _, edge in geometry.edges do
			local dot = edge.direction:Dot(dir)
			if dot > 0.99 and (edge.a - point).Magnitude < 0.01 then
				return part, edge.length
			elseif dot < -0.99 and (edge.b - point).Magnitude < 0.01 then
				return part, edge.length
			end
		end
	end
	return nil, nil
end

-- Try to extend an edge out in each direction
local function tryExtendEdgePositive(fromPart, edge): BasePart?
	-- Try to extend the edge in each direction
	local newFrom, extB = getSimpleExtension(fromPart, edge.b, edge.direction)
	if extB then
		edge.b += edge.direction * extB
		edge.length += extB
		return newFrom
	end
	return nil
end
	
local function tryExtendEdgeNegative(fromPart, edge): BasePart?
	local newFrom, extA = getSimpleExtension(fromPart, edge.a, -edge.direction)
	if extA then
		edge.a -= edge.direction * extA
		edge.length += extA
		return newFrom
	end
	return nil
end

local EXTEND_EDGE = false

local function getHoverEdge()
	local result = mouseRaycast()
	if result then
		local primaryEdge, bestFace = getPrimaryEdge(result)
		if EXTEND_EDGE then
			local fromPart = primaryEdge.part
			while fromPart do
				fromPart = tryExtendEdgePositive(fromPart, primaryEdge)
			end
			fromPart = primaryEdge.part
			while fromPart do
				fromPart = tryExtendEdgeNegative(fromPart, primaryEdge)
			end
			--local edges = {primaryEdge}
		end
		return primaryEdge, bestFace
	else
		return nil
	end
end

function UpdateHover()
	FixTargetFilter()
	if mouse.Target and not mouse.Target.Locked then
		local hoverEdge = getHoverEdge()
		if hoverEdge then
			showHoverEdge(hoverEdge)
		else
			hideHoverEdge()
		end
	else
		hideHoverEdge()
	end
end

function Selected()
	mModeScreenGui.Parent = game:GetService('CoreGui')
	mTargetFilter.Parent = game:GetService('CoreGui')
	mouse.TargetFilter = mTargetFilter
	mState = "EdgeA"
end

function Deselected()
	mModeScreenGui.Parent = nil
	mIgnoreNextTargetFilterDeparent = true
	mTargetFilter.Parent = nil
	hideHoverEdge()
	if mEdgeADrawn then
		for _, o in pairs(mEdgeADrawn) do
			o:Destroy()
		end
		mEdgeADrawn = nil
	end
end

local function isCtrlHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local function enableDragger(initialMouseDown)
	if not draggerHandler:isEnabled() then
		mTargetFilter.Parent = nil
		hideHoverEdge()
		if mEdgeADrawn then
			for _, o in pairs(mEdgeADrawn) do
				o:Destroy()
			end
			mEdgeADrawn = nil
		end
		mState = "EdgeA"
		draggerHandler:enable(initialMouseDown)
	end
end

function MouseDown()
	if draggerHandler:isEnabled() then
		-- Let the DraggerFramework handle it
		return
	elseif isCtrlHeld() then
		enableDragger(true)
	end
	
	if mouse.Target and not mouse.Target.Locked then
		if mState == "EdgeA" then
			-- Set face A
			mEdgeA = getHoverEdge()
			if mEdgeA then
				mEdgeADrawn = drawFace(mTargetFilter, mEdgeA, Color3.new(1, 0, 0), 0, 0)
				mState = "EdgeB"
			end
		else
			-- Remove FaceA
			for _, o in pairs(mEdgeADrawn) do
				o:Destroy()
			end
			mEdgeADrawn = nil
			mState = "EdgeA"
			--
			hideHoverEdge()
			local hoverFace, theFace = getHoverEdge()
			if not hoverFace then
				return
			end
			--
			local thicknessOverride;
			if mThicknessOption.Mode == THICKNESS_ONE_STUD then
				thicknessOverride = 1
			elseif mThicknessOption.Mode == THICKNESS_PLATE then
				thicknessOverride = 0.2
			elseif mThicknessOption.Mode == THICKNESS_THINNEST then
				thicknessOverride = 0.05
			elseif mThicknessOption.Mode == THICKNESS_BEST_GUESS then
				thicknessOverride = nil
			else
				assert(false, "Unreachable")
			end
			--
			local forceFactor;
			if mModeOption.Mode == FORCE_DEFAULT then
				forceFactor = 1
			elseif mModeOption.Mode == FORCE_NEGATIVE then
				forceFactor = -1
			else
				assert(false, "Unreachable")
			end
			--
			if theFace and mEdgeA.part == hoverFace.part then --and mEdgeA.id == hoverFace.id then
				-- On the same part... do extrude on the selected face
				local function prepEdge(edge)
					edge.length = (edge.b - edge.a).magnitude
					edge.direction = (edge.b - edge.a).unit
					edge.part = hoverFace.part
					edge.click = 0.25*edge.a + 0.75*edge.b
					return edge
				end
				local edge1, edge2;
				if #theFace.vertices == 4 then
					-- 4 verts, extrude square
					edge1 = prepEdge{
						a = theFace.vertices[1];
						b = theFace.vertices[2];
					}
					edge2 = prepEdge{
						a = theFace.vertices[4];
						b = theFace.vertices[3];
					}
					doFill(edge1, edge2, -1, thicknessOverride, forceFactor)
				elseif #theFace.vertices == 3 then
					-- 3 verts, extrude wedge
					edge1 = prepEdge{
						a = theFace.vertices[1];
						b = theFace.vertices[2];
					}
					edge2 = prepEdge{
						a = theFace.vertices[1];
						b = theFace.vertices[3];
					}
					doFill(edge1, edge2, -1, thicknessOverride, forceFactor)
				else
					-- Can't extrude shape otherwise, must have <3 or >4 edges
					-- TODO: Maybe such faces will be valid extrude targets in the
					--       future. We will have to handle them then, and it will
					--       take a non-trivial algorithm to decompose the face into
					--       triangles and squares, which will each be extruded.
					--       Something like this:
					--         for edge1, edge2 in decompose(theFace) do
					--             DoFill(edge1, edge2, -1)
					--         end
				end
			else
				-- Act
				mEdgeB = hoverFace
				doFill(mEdgeA, mEdgeB, 1, thicknessOverride, forceFactor)
			end
			--
			mEdgeA = nil
			mEdgeB = nil
		end
	else
		if mState == "EdgeB" then
			-- Remove FaceA
			for _, o in pairs(mEdgeADrawn) do
				o:Destroy()
			end
			mEdgeADrawn = nil
			mState = "EdgeA"
			hideHoverEdge()
			mEdgeA = nil
			mEdgeB = nil
		end
	end
end

function MouseUp()
	if draggerHandler:isEnabled() and not isCtrlHeld() then
		draggerHandler:disable()
		mouse.Icon = "" -- Disabling DraggerFramework does not reset Icon
		UpdateHover()
	end
end

function MouseMove()
	if not draggerHandler:isEnabled() then
		UpdateHover()
	end
end

function MouseIdle()
	if isCtrlHeld() then
		enableDragger()
	else
		if draggerHandler:isEnabled() then
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				draggerHandler:disable()
				mouse.Icon = "" -- Disabling DraggerFramework does not reset Icon
				UpdateHover()
			end
		else
			UpdateHover()
		end
	end
end

function KeyDown(key)
	
end

-- and we're finally done loading
loaded = true

--]=]