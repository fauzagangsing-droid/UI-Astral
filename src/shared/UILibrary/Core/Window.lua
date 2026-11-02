-- Dependency-injected shell; requiring this module creates no UI or listeners.
return function(library, config)
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	assert(RunService:IsClient(), "CreateWindow must be called on the client")
	if config == nil then config = {} end
	assert(type(config) == "table", "Window config must be a table")
	for _, key in ipairs({ "Title", "Version", "Name" }) do
		assert(config[key] == nil or type(config[key]) == "string", key .. " must be a string")
	end
	assert(config.Theme == nil or type(config.Theme) == "table", "Theme must be a table")
	local title = config.Title
	if title == nil then title = "ASTRAL LITE" end
	local version = config.Version
	if version == nil then version = library.Version end
	assert(type(version) == "string", "Library Version must be a string")
	local playerGui = config.Parent
	if playerGui ~= nil then
		assert(typeof(playerGui) == "Instance" and playerGui:IsA("PlayerGui"), "Parent must be a PlayerGui")
	else
		assert(Players.LocalPlayer, "CreateWindow requires a local player")
		playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local gui = Instance.new("ScreenGui")
	local scope
	local ok, result = pcall(function()
		gui.Name = config.Name == nil and "AstralLite" or config.Name
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 10

		local UI = library.new({ ScreenGui = gui, Theme = config.Theme })
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
		scope = H.Scope(gui)
		scope:Add(function() UI:Destroy() end)
		local window = { UI = UI, Theme = theme, ScreenGui = gui, Pages = {}, Tabs = {} }
		local function alive()
			assert(not scope.Destroyed, "Window is destroyed")
		end
		local function method(api, name, callback)
			api[name] = function(first, ...)
				if first == api then return callback(...) end
				return callback(first, ...)
			end
		end

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
		window._instance = main
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
			Text = title == "ASTRAL LITE" and ('ASTRAL <font color="#' .. C.Primary:ToHex() .. '">LITE</font>') or title,
			RichText = title == "ASTRAL LITE",
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
			Text = version,
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
		local pages = window.Pages
		local tabs = window.Tabs
		local navigation = {}
		local selected
		local tabOrder = 0

		local function selectPage(target)
			selected = target
			for _, tab in ipairs(navigation) do
				local active = (tab.api == target)
				tab.indicator.Visible = active
				tab.icon.TextColor3 = active and C.Primary or C.SubText
				tab.label.TextColor3 = active and C.Text or C.SubText
				tween(tab.button, 0.15, {
					BackgroundColor3 = active and C.Secondary or C.Card,
					BackgroundTransparency = active and 0.85 or 1,
				})
				tab.api.Container.Visible = active
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
			})
			make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
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
			return { button = btn, indicator = indicator, icon = icon, label = label }
		end

		-- Only this one cleanup belongs to the window; tab-local connections never
		-- accumulate in its scope as dynamic tabs are created and removed.
		scope:Add(function()
			local pending = table.clone(navigation)
			for _, record in ipairs(pending) do record.scope:Destroy() end
			table.clear(pages)
			table.clear(tabs)
		end)

		method(window, "GetTab", function(name)
			alive()
			assert(type(name) == "string", "Tab name must be a string")
			return tabs[name]
		end)
		method(window, "SelectTab", function(target)
			alive()
			if type(target) == "string" then target = tabs[target] end
			assert(type(target) == "table" and tabs[target.Name] == target, "Tab does not belong to this window")
			selectPage(target)
			return target
		end)
		method(window, "CreateTab", function(settings)
			alive()
			assert(type(settings) == "table", "Tab config must be a table")
			local name = settings.Name
			assert(type(name) == "string" and name ~= "", "Tab Name must be a non-empty string")
			assert(settings.Icon == nil or type(settings.Icon) == "string", "Tab Icon must be a string")
			assert(tabs[name] == nil, "Duplicate tab name: " .. name)
			local page = createPage(name)
			local tabScope = H.Scope(page)
			local built, tabResult = pcall(function()
				local tab = { Name = name, Container = page, _instance = page }
				tabOrder += 1
				local record = createTab(name, settings.Icon == nil and "" or settings.Icon, tabOrder)
				record.api, record.scope = tab, tabScope
				tabScope:Add(function()
					tabs[name], pages[name] = nil, nil
					local index = table.find(navigation, record)
					if index then table.remove(navigation, index) end
					record.button:Destroy()
					if selected == tab then
						selected = nil
						if not scope.Destroyed and navigation[1] then selectPage(navigation[1].api) end
					end
				end)
				local function tabAlive()
					alive()
					assert(not tabScope.Destroyed, "Tab is destroyed")
				end
				method(tab, "Select", function()
					tabAlive()
					selectPage(tab)
					return tab
				end)
				method(tab, "Destroy", function() tabScope:Destroy() end)
				local order = 0
				for _, kind in ipairs(library.ComponentNames) do
					if kind ~= "Notification" then
						local factory = UI["Create" .. kind]
						method(tab, "Create" .. kind, function(componentConfig)
							tabAlive()
							if componentConfig == nil then componentConfig = {} end
							assert(type(componentConfig) == "table", "Component config must be a table")
							local options = table.clone(componentConfig)
							local nextOrder = H.Number(options.LayoutOrder, order + 1, "LayoutOrder")
							assert(nextOrder % 1 == 0, "LayoutOrder must be an integer")
							options.LayoutOrder = nextOrder
							local component = factory(page, options)
							order = math.max(order, nextOrder)
							return component
						end)
					end
				end
				make("TextLabel", {
					Name = "PageTitle",
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = name,
					TextSize = 15,
					TextColor3 = C.Text,
					Font = FONT_BOLD,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 0,
					Parent = page,
				})
				tabScope:Connect(record.button.Activated, function() tab.Select() end)
				tabScope:Connect(record.button.Destroying, function() tabScope:Destroy() end)
				tabs[name], pages[name] = tab, page
				table.insert(navigation, record)
				page.Parent = content
				record.button.Parent = tabList
				assert(not scope.Destroyed and not tabScope.Destroyed, "Tab destroyed during publication")
				if not selected then selectPage(tab) end
				assert(not scope.Destroyed and not tabScope.Destroyed, "Tab destroyed during initial selection")
				return tab
			end)
			if not built then tabScope:Destroy(); error(tabResult, 2) end
			return tabResult
		end)
		method(window, "CreateNotification", function(settings)
			alive()
			return UI:CreateNotification(settings)
		end)

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

		method(window, "Hide", function()
			alive()
			main.Visible = false
			floatingLogo.Visible = false
		end)
		method(window, "Minimize", function()
			alive()
			main.Visible = false
			positionLogo(logoAnchorPixels())
			floatingLogo.Visible = true
		end)
		local function restore()
			alive()
			floatingLogo.Visible = false
			main.Visible = true
			main.Size = WINDOW_SIZE
		end
		method(window, "Show", restore)
		method(window, "Restore", restore)
		method(window, "IsVisible", function()
			return not scope.Destroyed and gui.Enabled and main.Visible
		end)
		method(window, "Destroy", function() scope:Destroy() end)

		scope:Connect(minimizeBtn.Activated, function() window.Minimize() end)

		scope:Connect(floatingLogo.Activated, function(input)
			if input and (input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch) then
				-- Activated and the gesture's end listener may run in either order.
				trackLogoMovement(input)
				if logoMoved then return end
			end
			window.Restore()
		end)

		scope:Connect(closeBtn.Activated, function() window.Hide() end)

		scope:Connect(UserInputService.InputBegan, function(input, gameProcessed)
			if gameProcessed or UserInputService:GetFocusedTextBox() then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				window.Restore()
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

		assert(not scope.Destroyed, "Window destroyed during publication")
		return window
	end)
	if not ok then
		if scope then scope:Destroy() else gui:Destroy() end
		error(result, 2)
	end
	return result
end
