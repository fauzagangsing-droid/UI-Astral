-- ASTRAL LITE shell. Client integration:
-- local UI, pages = Players.LocalPlayer.PlayerScripts.Main:WaitForChild("GetUI"):Invoke()
-- pages maps category names to ScrollingFrames; UI is the unchanged library API.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UILibrary = require(ReplicatedStorage:WaitForChild("UILibrary"))

local gui = Instance.new("ScreenGui")
gui.Name = "AstralLite"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10

local UI = UILibrary.new({ ScreenGui = gui })
local H = UI.Helpers
local theme = UI.Theme
local C = theme.Colors
local FONT = theme.Fonts.Regular
local FONT_MED = theme.Fonts.Medium
local FONT_BOLD = theme.Fonts.Bold
local D = theme.Dimensions
local W = theme.Window
local make = H.Make
local tween = H.Tween
local scope = H.Scope(gui)
scope:Add(function() UI.Destroy() end)
scope:Connect(script.Destroying, function() scope:Destroy() end)

-- This frame measures the actual GUI coordinate space, including the top inset.
-- ScreenGui is a LayerCollector, so do not rely on it having AbsoluteSize.
local bounds = make("Frame", {
	Name = "DragBounds",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = gui,
})

--// Main window ---------------------------------------------------------------
local WINDOW_SIZE = UDim2.fromOffset(D.WindowWidth, D.WindowHeight)
local TOPBAR_HEIGHT = D.TopbarHeight
local SIDEBAR_WIDTH = D.SidebarWidth

local main = make("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = WINDOW_SIZE,
	BackgroundColor3 = C.Background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = gui,
})
make("UICorner", { CornerRadius = UDim.new(0, D.CornerRadius), Parent = main })
make("UIStroke", { Color = C.Primary, Thickness = 1, Transparency = 0.35, Parent = main })
local uiScale = make("UIScale", { Parent = main })

--// Topbar --------------------------------------------------------------------
local topbar = make("Frame", {
	Name = "Topbar",
	Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
	BackgroundColor3 = C.Sidebar,
	BorderSizePixel = 0,
	Active = true,
	Parent = main,
})
make("UICorner", { CornerRadius = UDim.new(0, D.CornerRadius), Parent = topbar })
make("Frame", {
	Name = "Patch",
	Position = UDim2.new(0, 0, 1, -D.CornerRadius),
	Size = UDim2.new(1, 0, 0, D.CornerRadius),
	BackgroundColor3 = C.Sidebar,
	BorderSizePixel = 0,
	Parent = topbar,
})
make("Frame", {
	Name = "Separator",
	Position = UDim2.new(0, 0, 0, TOPBAR_HEIGHT),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = C.Border,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = main,
})
make("ImageLabel", {
	Name = "Logo",
	Position = UDim2.new(0, 12, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(57, 57),
	BackgroundTransparency = 1,
	Image = theme.Assets.Dragon,
	ScaleType = Enum.ScaleType.Fit,
	ImageColor3 = Color3.new(1, 1, 1),
	Parent = topbar,
})
make("TextLabel", {
	Name = "Title",
	Position = UDim2.new(0, 77, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(110, 16),
	BackgroundTransparency = 1,
	Text = 'ASTRAL <font color="#' .. C.Primary:ToHex() .. '">LITE</font>',
	RichText = true,
	TextSize = 13,
	TextColor3 = C.Text,
	Font = FONT_BOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topbar,
})
make("TextLabel", {
	Name = "Version",
	Position = UDim2.new(0, 191, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(40, 14),
	BackgroundTransparency = 1,
	Text = "v1.0",
	TextSize = 11,
	TextColor3 = C.SubText,
	Font = FONT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topbar,
})

local function topbarButton(name, glyph, xOffset)
	local btn = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0.5, 0),
		Size = UDim2.fromOffset(30, 26),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 1,
		Text = glyph,
		TextSize = 14,
		TextColor3 = C.SubText,
		Font = FONT_MED,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = topbar,
	})
	make("UICorner", { CornerRadius = UDim.new(0, D.CornerRadius), Parent = btn })
	scope:Connect(btn.MouseEnter, function()
		tween(btn, 0.12, { BackgroundTransparency = 0 })
	end)
	scope:Connect(btn.MouseLeave, function()
		tween(btn, 0.12, { BackgroundTransparency = 1 })
	end)
	return btn
end

local minimizeBtn = topbarButton("Minimize", "—", -8)
local closeBtn = topbarButton("Close", "✕", -42)

--// Sidebar -------------------------------------------------------------------
local sidebar = make("Frame", {
	Name = "Sidebar",
	Position = UDim2.new(0, 0, 0, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -(TOPBAR_HEIGHT + 1)),
	BackgroundColor3 = C.Sidebar,
	BorderSizePixel = 0,
	Parent = main,
})
make("Frame", {
	Position = UDim2.new(1, -1, 0, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = C.Border,
	BorderSizePixel = 0,
	Parent = sidebar,
})
local tabList = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(0, 10),
	Size = UDim2.new(1, 0, 1, -10),
	BackgroundTransparency = 1,
	Parent = sidebar,
})
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })

--// Content area --------------------------------------------------------------
local content = make("Frame", {
	Name = "Content",
	Position = UDim2.new(0, SIDEBAR_WIDTH, 0, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -(TOPBAR_HEIGHT + 1)),
	BackgroundTransparency = 1,
	Parent = main,
})
make("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	Parent = content,
})

--// Navigation ----------------------------------------------------------------
local pages = {}
local tabs = {}
local CATEGORIES = {
	{ name = "Home",     icon = "🛖" },
	{ name = "Combat",   icon = "⚔" },
	{ name = "Teleport", icon = "📍" },
	{ name = "Player",   icon = "" },
	{ name = "Visuals",  icon = "◎" },
	{ name = "World",    icon = "◍" },
	{ name = "Misc",     icon = "☰" },
	{ name = "Settings", icon = "⚙" },
}

local function selectPage(index)
	for i, tab in ipairs(tabs) do
		local active = (i == index)
		tab.indicator.Visible = active
		tab.icon.TextColor3 = active and C.Primary or C.SubText
		tab.label.TextColor3 = active and C.Text or C.SubText
		tween(tab.button, 0.15, {
			BackgroundColor3 = active and C.Secondary or C.Card,
			BackgroundTransparency = active and 0.85 or 1,
		})
		pages[CATEGORIES[i].name].Visible = active
	end
end

local function createPage(name)
	local page = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Border,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = content,
	})
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	pages[name] = page
	return page
end

local function createTab(name, glyph, pageIndex)
	local btn = make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = pageIndex,
		Parent = tabList,
	})
	make("UICorner", { CornerRadius = UDim.new(0, D.CornerRadius), Parent = btn })
	local indicator = make("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(3, 18),
		BackgroundColor3 = C.Primary,
		BorderSizePixel = 0,
		Visible = false,
		Parent = btn,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 2), Parent = indicator })
	local icon = make("TextLabel", {
		Name = "Icon",
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = glyph,
		TextSize = 18,
		TextColor3 = C.SubText,
		Font = FONT_MED,
		Parent = btn,
	})
	local label = make("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 42, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -44, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.SubText,
		Font = FONT_MED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = btn,
	})
	scope:Connect(btn.Activated, function() selectPage(pageIndex) end)
	table.insert(tabs, { button = btn, indicator = indicator, icon = icon, label = label })
end

for index, category in ipairs(CATEGORIES) do
	local page = createPage(category.name)
	make("TextLabel", {
		Name = "PageTitle",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = category.name,
		TextSize = 15,
		TextColor3 = C.Text,
		Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = page,
	})
	createTab(category.name, category.icon, index)
end
selectPage(1)

--// Window interactions -------------------------------------------------------
local dragStart, startPos
H.BindDrag(scope, topbar, function(input, began)
	if began then
		dragStart = input.Position
		startPos = main.Position
		return
	end
	local delta = input.Position - dragStart
	main.Position = UDim2.new(
		startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y
	)
end)

local floatingLogo = make("ImageButton", {
	Name = "FloatingLogo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -40, 1, -40),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = theme.Assets.Dragon,
	ScaleType = Enum.ScaleType.Fit,
	AutoButtonColor = false,
	ZIndex = 10,
	Visible = false,
	Parent = bounds,
})
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floatingLogo })
make("UIStroke", { Color = C.Primary, Thickness = 1, Transparency = 0.25, Parent = floatingLogo })

local function logoAnchorPixels()
	local position = floatingLogo.Position
	local size = bounds.AbsoluteSize
	return Vector2.new(position.X.Scale * size.X + position.X.Offset,
		position.Y.Scale * size.Y + position.Y.Offset)
end

local function clampAxis(value, extent, length, anchor)
	-- A screen smaller than the logo cannot contain it; center it safely instead.
	if extent <= length then return extent * anchor end
	return math.clamp(value, length * anchor, extent - length * (1 - anchor))
end

local function positionLogo(position)
	local size = bounds.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local logoSize = floatingLogo.AbsoluteSize
	local anchor = floatingLogo.AnchorPoint
	floatingLogo.Position = UDim2.fromOffset(
		clampAxis(position.X, size.X, logoSize.X, anchor.X),
		clampAxis(position.Y, size.Y, logoSize.Y, anchor.Y)
	)
end

local logoDragStart, logoStartPos
local logoMoved = false
local function trackLogoMovement(input)
	if logoDragStart and (input.Position - logoDragStart).Magnitude > W.DragThreshold then
		logoMoved = true
	end
end

H.BindDrag(scope, floatingLogo, function(input, began)
	if began then
		logoMoved = false
		logoDragStart = input.Position
		-- Resolve both scale and offset before switching to pixel-only coordinates.
		logoStartPos = logoAnchorPixels()
		positionLogo(logoStartPos)
		return
	end
	trackLogoMovement(input)
	local delta = input.Position - logoDragStart
	positionLogo(logoStartPos + Vector2.new(delta.X, delta.Y))
end, trackLogoMovement)

scope:Connect(minimizeBtn.Activated, function()
	main.Visible = false
	positionLogo(logoAnchorPixels())
	floatingLogo.Visible = true
end)

scope:Connect(floatingLogo.Activated, function(input)
	if input and (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch) then
		-- Activated and the gesture's end listener may run in either order.
		trackLogoMovement(input)
		if logoMoved then return end
	end
	floatingLogo.Visible = false
	main.Visible = true
	main.Size = WINDOW_SIZE
end)

scope:Connect(closeBtn.Activated, function()
	main.Visible = false
end)

scope:Connect(UserInputService.InputBegan, function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		floatingLogo.Visible = false
		main.Visible = true
	end
end)

-- Use the inset-aware bounds for scaling too, with no minimum that can overflow
-- tiny screens. Keep at most one viewport listener when CurrentCamera changes.
local function updateLayout()
	local size = bounds.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	uiScale.Scale = math.min(size.X / W.ViewportWidth, size.Y / W.ViewportHeight, W.MaxScale)
	if floatingLogo.Visible then positionLogo(logoAnchorPixels()) end
end

local viewportConnection
local function bindCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not scope.Destroyed then updateLayout() end
		end)
	end
	updateLayout()
end
scope:Add(function()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
end)
scope:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
scope:Connect(bounds:GetPropertyChangedSignal("AbsoluteSize"), updateLayout)
bindCamera()
gui.Parent = playerGui
updateLayout()

-- Publish only the fully initialized client shell, with no callback-parent race.
local getUI = Instance.new("BindableFunction")
getUI.Name = "GetUI"
getUI.OnInvoke = function()
	return UI, pages
end
scope:Add(function() getUI:Destroy() end)
getUI.Parent = script
