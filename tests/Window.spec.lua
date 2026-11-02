-- Manual client Studio runner. Requiring this ModuleScript does not run tests.
return function(libraryOverride)
	local RunService = game:GetService("RunService")
	assert(RunService:IsStudio() and RunService:IsClient(), "Run Window.spec on a Studio Play client")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local Library = libraryOverride
	if Library == nil then Library = require(ReplicatedStorage:WaitForChild("UILibrary")) end
	assert(type(Library) == "table", "Library override must be the required library table")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local passed = 0

	local function equal(actual, expected, message)
		assert(actual == expected, (message or "Values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function rejects(callback)
		assert(not pcall(callback), "Expected an error")
	end
	local function child(parent, name, className)
		local result = parent:FindFirstChild(name)
		assert(result and result:IsA(className), "Missing " .. className .. " " .. name)
		return result
	end
	local function empty(map)
		equal(next(map), nil, "Expected an empty map")
	end
	local function componentDead(api)
		for name, method in pairs(api) do
			if type(method) == "function" and name ~= "Destroy" then
				rejects(function() method(api) end)
				rejects(function() method() end)
			end
		end
		api:Destroy()
		api.Destroy()
	end
	local function tabDead(tab)
		rejects(function() tab:Select() end)
		rejects(function() tab.CreateLabel({ Text = "Rejected" }) end)
		tab:Destroy()
		tab.Destroy()
	end
	local function windowDead(window)
		equal(window:IsVisible(), false) -- Unlike other getters, IsVisible is valid after destruction.
		equal(window.IsVisible(), false)
		for _, name in ipairs({ "Show", "Hide", "Minimize", "Restore" }) do
			rejects(function() window[name](window) end)
			rejects(function() window[name]() end)
		end
		rejects(function() window:GetTab("Alive") end)
		rejects(function() window.SelectTab("Alive") end)
		rejects(function() window:CreateTab({ Name = "New" }) end)
		rejects(function() window.CreateNotification({ Title = "Rejected" }) end)
		rejects(function() window.UI:CreateNotification() end)
		window:Destroy()
		window.Destroy()
	end

	local function test(name, body)
		local cleanups = {}
		local function own(callback) table.insert(cleanups, callback) end
		local function newWindow(config, colon)
			local window
			if colon then
				if config == nil then window = Library:CreateWindow() else window = Library:CreateWindow(config) end
			else
				window = Library.CreateWindow(config)
			end
			-- Keep a GUI fallback even if explicit window cleanup itself raises an error.
			own(function() window.ScreenGui:Destroy() end)
			own(function() window:Destroy() end)
			return window
		end
		local ok, message = xpcall(function() body(newWindow, own) end, debug.traceback)
		local cleanupErrors = {}
		for index = #cleanups, 1, -1 do
			local cleaned, reason = pcall(cleanups[index])
			if not cleaned then table.insert(cleanupErrors, tostring(reason)) end
		end
		if not ok then error(name .. " failed:\n" .. tostring(message), 0) end
		assert(#cleanupErrors == 0, name .. " cleanup failed: " .. table.concat(cleanupErrors, "; "))
		passed += 1
	end

	local componentNames = {
		"Button", "ColorPicker", "Divider", "Dropdown", "Keybind", "Label", "MultiDropdown",
		"Notification", "Paragraph", "ProgressBar", "SearchBox", "Section", "Slider", "TextBox", "Toggle",
	}

	test("Metadata and default cosmic window structure without default tabs", function(newWindow)
		equal(Library.Version, "2.0.0")
		equal(#Library.ComponentNames, 15)
		for index, name in ipairs(componentNames) do equal(Library.ComponentNames[index], name) end
		local window = newWindow(nil, true)
		local gui = window.ScreenGui
		equal(gui.Name, "AstralLite")
		equal(gui.Parent, playerGui)
		equal(gui.ResetOnSpawn, false)
		equal(gui.DisplayOrder, 10)
		equal(window.Theme, window.UI.Theme)
		empty(window.Pages); empty(window.Tabs)
		equal(window:GetTab("Home"), nil)
		local main = child(gui, "Window", "Frame")
		equal(window._instance, main)
		equal(main.Size, UDim2.fromOffset(650, 420))
		equal(main.AnchorPoint, Vector2.new(0.5, 0.5))
		equal(main.ClipsDescendants, true)
		equal(main.BackgroundColor3, Color3.fromHex("10111A"))
		local stroke = main:FindFirstChildWhichIsA("UIStroke")
		assert(stroke and main:FindFirstChildWhichIsA("UICorner") and main:FindFirstChildWhichIsA("UIScale"))
		equal(stroke.Color, Color3.fromHex("A879FF"))
		local topbar = child(main, "Topbar", "Frame")
		equal(topbar.Size.Y.Offset, 65)
		local title = child(topbar, "Title", "TextLabel")
		equal(title.RichText, true)
		equal(title.Text, 'ASTRAL <font color="#' .. window.Theme.Colors.Primary:ToHex() .. '">LITE</font>')
		equal(child(topbar, "Version", "TextLabel").Text, "2.0.0")
		equal(child(topbar, "Logo", "ImageLabel").Image, window.Theme.Assets.Dragon)
		child(topbar, "Close", "TextButton"); child(topbar, "Minimize", "TextButton")
		local sidebar = child(main, "Sidebar", "Frame")
		equal(sidebar.Size.X.Offset, 150)
		local tabs = child(sidebar, "Tabs", "Frame")
		for _, item in ipairs(tabs:GetChildren()) do assert(not item:IsA("TextButton"), "No default navigation tabs") end
		local content = child(main, "Content", "Frame")
		for _, item in ipairs(content:GetChildren()) do assert(not item:IsA("ScrollingFrame"), "No default pages") end
		local bounds = child(gui, "DragBounds", "Frame")
		local logo = child(bounds, "FloatingLogo", "ImageButton")
		equal(logo.Visible, false)
		equal(logo.Size, UDim2.fromOffset(52, 52))
		child(gui, "Notifications", "Frame")
		equal(window:IsVisible(), true)
	end)

	test("Custom config, default dot call and independent window themes", function(newWindow)
		local customPrimary = Color3.fromRGB(20, 160, 230)
		local overrides = { Colors = { Primary = customPrimary }, Dimensions = { WindowWidth = 720 } }
		local a = newWindow({ Name = "WindowSpecCustom", Title = "Custom title", Version = "test-version", Theme = overrides, Parent = playerGui }, true)
		local b = newWindow(nil, false)
		equal(a.ScreenGui.Name, "WindowSpecCustom")
		local topbar = child(a._instance, "Topbar", "Frame")
		equal(child(topbar, "Title", "TextLabel").Text, "Custom title")
		equal(child(topbar, "Title", "TextLabel").RichText, false)
		equal(child(topbar, "Version", "TextLabel").Text, "test-version")
		equal(a._instance.Size.X.Offset, 720)
		equal(a.Theme.Colors.Primary, customPrimary)
		equal(b.Theme.Colors.Primary, Color3.fromHex("A879FF"))
		assert(a.Theme ~= b.Theme and a.Theme.Colors ~= b.Theme.Colors and a.UI ~= b.UI)
		overrides.Colors.Primary = Color3.new(1, 0, 0)
		equal(a.Theme.Colors.Primary, customPrimary, "Theme config must be copied")
		local ta = a:CreateTab({ Name = "Shared" })
		local tb = b.CreateTab({ Name = "Shared" })
		local pa = ta:CreateColorPicker()
		local pb = tb.CreateColorPicker()
		equal(pa:GetColor(), customPrimary)
		equal(pb:GetColor(), b.Theme.Colors.Primary)
		pa:SetColor(Color3.new(0, 1, 0))
		equal(pb:GetColor(), Color3.fromHex("A879FF"))
		a.Theme.Colors.Primary = Color3.new(1, 1, 0)
		equal(b.Theme.Colors.Primary, Color3.fromHex("A879FF"))
		a:Destroy()
		windowDead(a)
		equal(b:IsVisible(), true)
		equal(tb:Select(), tb)
	end)

	test("All 14 tab factories, default state, independent instances and call styles", function(newWindow)
		local window = newWindow({}, false)
		local tab = window:CreateTab({ Name = "Factories", Icon = "F" })
		equal(tab.Name, "Factories")
		equal(tab._instance, tab.Container)
		assert(tab.Container:IsA("ScrollingFrame"))
		equal(window.Pages.Factories, tab.Container)
		equal(window.Tabs.Factories, tab)
		equal(window.GetTab("Factories"), tab)
		equal(tab.Container.AutomaticCanvasSize, Enum.AutomaticSize.Y)
		equal(child(tab.Container, "PageTitle", "TextLabel").LayoutOrder, 0)
		equal(tab.CreateNotification, nil)
		local defaults = {
			Button = { "GetText", "Button", "SetText", "Changed" },
			ColorPicker = { "GetColor", window.Theme.Colors.Primary, "SetColor", Color3.new(0, 1, 0) },
			Dropdown = { "GetValue" },
			Keybind = { "GetKey", Enum.KeyCode.Unknown, "SetKey", Enum.KeyCode.Q },
			Label = { "GetText", "Label", "SetText", "Changed" },
			MultiDropdown = { "GetValues" },
			Paragraph = { "GetTitle", "Title", "SetTitle", "Changed" },
			ProgressBar = { "GetValue", 0, "SetValue", 25 },
			SearchBox = { "GetValue", "", "SetValue", "Changed" },
			Section = { "GetExpanded", true, "SetExpanded", false },
			Slider = { "GetValue", 0, "SetValue", 25 },
			TextBox = { "GetValue", "", "SetValue", "Changed" },
			Toggle = { "GetValue", false, "SetValue", true },
		}
		local count = 0
		for _, kind in ipairs(componentNames) do
			if kind ~= "Notification" then
				count += 1
				local factory = tab["Create" .. kind]
				assert(type(factory) == "function", "Missing tab factory " .. kind)
				local a = factory(tab)
				local b = factory(nil)
				assert(a ~= b and a._instance ~= b._instance)
				equal(a._instance.Parent, tab.Container)
				equal(b._instance.Parent, tab.Container)
				equal(a._instance.LayoutOrder, count * 2 - 1)
				equal(b._instance.LayoutOrder, count * 2)
				local spec = defaults[kind]
				if kind == "MultiDropdown" then
					empty(a:GetValues()); empty(b.GetValues())
				elseif spec then
					equal(a[spec[1]](a), spec[2])
					equal(b[spec[1]](), spec[2])
					if spec[3] then
						a[spec[3]](a, spec[4])
						equal(a[spec[1]](), spec[4])
						equal(b[spec[1]](b), spec[2])
					end
				end
				a:Destroy()
				componentDead(a)
				assert(b._instance:IsDescendantOf(window.ScreenGui))
			end
		end
		equal(count, 14)
	end)

	test("Window and tab invalid configs are transactional", function(newWindow)
		local before = #playerGui:GetChildren()
		for _, config in ipairs({ false, "bad", { Title = false }, { Name = 1 }, { Version = false }, { Parent = ReplicatedStorage }, { Theme = false }, { Theme = { Unknown = {} } }, { Theme = { Dimensions = { WindowWidth = 0 } } } }) do
			rejects(function() Library:CreateWindow(config) end)
			rejects(function() Library.CreateWindow(config) end)
			equal(#playerGui:GetChildren(), before, "Invalid window config leaked a GUI")
		end
		local window = newWindow(nil, true)
		local tab = window:CreateTab({ Name = "Alive" })
		local other = newWindow(nil, false)
		local foreign = other:CreateTab({ Name = "Alive" })
		local descendants = #window.ScreenGui:GetDescendants()
		for _, config in ipairs({ false, "bad", {}, { Name = "" }, { Name = 1 }, { Name = "New", Icon = false }, { Name = "Alive" } }) do
			rejects(function() window:CreateTab(config) end)
			rejects(function() window.CreateTab(config) end)
			equal(#window.ScreenGui:GetDescendants(), descendants)
		end
		rejects(function() window:CreateTab() end)
		rejects(function() window:GetTab(false) end)
		rejects(function() window:SelectTab("Missing") end)
		rejects(function() window.SelectTab(foreign) end)
		equal(window:GetTab("Alive"), tab)
		equal(tab.Container.Visible, true)
		equal(window:GetTab("New"), nil)
		for _, kind in ipairs(componentNames) do
			if kind ~= "Notification" then
				rejects(function() tab["Create" .. kind](false) end)
				rejects(function() tab["Create" .. kind](tab, { Callback = false }) end)
				equal(#window.ScreenGui:GetDescendants(), descendants)
			end
		end
	end)

	test("Automatic LayoutOrder, explicit order, config copies and failed creation", function(newWindow)
		local window = newWindow(nil, true)
		local tab = window:CreateTab({ Name = "Order" })
		local config = { Text = "First" }
		equal(tab:CreateLabel(config)._instance.LayoutOrder, 1)
		equal(config.LayoutOrder, nil, "Tab factory must not mutate config")
		equal(tab.CreateButton()._instance.LayoutOrder, 2)
		local explicit = { LayoutOrder = 10 }
		equal(tab:CreateDivider(explicit)._instance.LayoutOrder, 10)
		equal(explicit.LayoutOrder, 10)
		equal(tab:CreateLabel({ LayoutOrder = -2 })._instance.LayoutOrder, -2)
		equal(tab:CreateLabel()._instance.LayoutOrder, 11)
		local before = #tab.Container:GetDescendants()
		rejects(function() tab:CreateLabel({ LayoutOrder = 1.5 }) end)
		rejects(function() tab:CreateSlider({ Min = "bad", LayoutOrder = 99 }) end)
		equal(#tab.Container:GetDescendants(), before)
		equal(tab:CreateLabel()._instance.LayoutOrder, 12, "Failures must not advance automatic order")
		local other = window.CreateTab({ Name = "Other" })
		equal(other.CreateLabel()._instance.LayoutOrder, 1)
	end)

	test("Selection, selected-tab removal and name reuse", function(newWindow)
		local window = newWindow(nil, true)
		local a = window:CreateTab({ Name = "A", Icon = "a" })
		local b = window.CreateTab({ Name = "B" })
		local c = window:CreateTab({ Name = "C" })
		equal(a.Container.Visible, true)
		equal(b.Container.Visible, false)
		equal(c.Container.Visible, false)
		equal(window:SelectTab("B"), b)
		equal(a.Container.Visible, false)
		equal(b.Container.Visible, true)
		equal(window.SelectTab(c), c)
		equal(c.Select(), c)
		local tabs = child(child(window._instance, "Sidebar", "Frame"), "Tabs", "Frame")
		equal(child(child(tabs, "C", "TextButton"), "Indicator", "Frame").Visible, true)
		equal(child(child(tabs, "A", "TextButton"), "Indicator", "Frame").Visible, false)
		c:Destroy()
		tabDead(c)
		equal(window:GetTab("C"), nil)
		equal(window.Pages.C, nil)
		equal(tabs:FindFirstChild("C"), nil)
		equal(a.Container.Visible, true, "Removing selected tab selects first remaining tab")
		b:Destroy() -- Removing an inactive tab must not change the active page.
		equal(a.Container.Visible, true)
		a.Destroy()
		empty(window.Tabs); empty(window.Pages)
		local replacement = window:CreateTab({ Name = "A" })
		assert(replacement ~= a)
		equal(replacement.Container.Visible, true)
		rejects(function() window:SelectTab(a) end)
	end)

	test("External page and navigation-button destruction remove tab state", function(newWindow)
		local window = newWindow(nil, true)
		local a = window:CreateTab({ Name = "A" })
		local b = window:CreateTab({ Name = "B" })
		local component = a:CreateToggle()
		a.Container:Destroy()
		task.wait() -- External Instance destruction may deliver Destroying signals deferred.
		tabDead(a); componentDead(component)
		equal(window:GetTab("A"), nil)
		equal(window.Pages.A, nil)
		equal(b.Container.Visible, true)
		local tabs = child(child(window._instance, "Sidebar", "Frame"), "Tabs", "Frame")
		child(tabs, "B", "TextButton"):Destroy()
		task.wait()
		tabDead(b)
		equal(b.Container.Parent, nil)
		empty(window.Tabs); empty(window.Pages)
	end)

	test("Show, Hide, Minimize, Restore and Enabled visibility", function(newWindow)
		local window = newWindow(nil, true)
		local logo = child(child(window.ScreenGui, "DragBounds", "Frame"), "FloatingLogo", "ImageButton")
		local size = window._instance.Size
		window:Hide()
		equal(window.IsVisible(), false)
		equal(logo.Visible, false)
		window.Show()
		equal(window:IsVisible(), true)
		window.Minimize()
		equal(window:IsVisible(), false)
		equal(logo.Visible, true)
		window:Hide()
		equal(logo.Visible, false)
		window:Minimize()
		window._instance.Size = UDim2.fromOffset(10, 10)
		window.Restore()
		equal(window._instance.Size, size)
		equal(window:IsVisible(), true)
		equal(logo.Visible, false)
		window:Hide()
		window:Show()
		window:Minimize()
		window:Restore()
		equal(window:IsVisible(), true)
		window.ScreenGui.Enabled = false
		equal(window:IsVisible(), false)
		window.ScreenGui.Enabled = true
		equal(window.IsVisible(), true)
	end)

	test("Window notifications default calls, Show, Destroy and expiry", function(newWindow)
		local window = newWindow(nil, true)
		local a = window:CreateNotification()
		local b = window.CreateNotification(nil)
		local holder = child(window.ScreenGui, "Notifications", "Frame")
		for _, api in ipairs({ a, b }) do
			equal(api:GetTitle(), "Notification")
			equal(api._instance.Parent, holder)
			equal(api._instance.Visible, false)
			api:Show()
			api.Show()
			equal(api._instance.Visible, true)
			api:Destroy()
			componentDead(api)
		end
		local before = #window.ScreenGui:GetDescendants()
		rejects(function() window:CreateNotification(false) end)
		rejects(function() window.CreateNotification({ Callback = false }) end)
		equal(#window.ScreenGui:GetDescendants(), before)
		local expires = window:CreateNotification({ Title = "Expires", Duration = 0.1 })
		expires.Show()
		task.wait(0.3)
		equal(expires._instance.Parent, nil)
		componentDead(expires)
	end)

	test("Explicit window Destroy owns GUI, all components and tab maps immediately", function(newWindow)
		local window = newWindow(nil, true)
		local tab = window:CreateTab({ Name = "Alive" })
		local pages, tabs = window.Pages, window.Tabs
		local components = {}
		for _, kind in ipairs(componentNames) do
			if kind ~= "Notification" then table.insert(components, tab["Create" .. kind]()) end
		end
		local notification = window:CreateNotification({ Duration = 0.1 })
		notification:Show()
		table.insert(components, notification)
		window:Destroy()
		equal(window.ScreenGui.Parent, nil)
		empty(pages); empty(tabs)
		tabDead(tab)
		for _, api in ipairs(components) do componentDead(api) end
		windowDead(window)
		task.wait(0.3) -- Pass the notification deadline after explicit cleanup.
		equal(window.ScreenGui.Parent, nil)
	end)

	test("Lower-level UI Destroy leaves shell; explicit window Destroy finishes ownership", function(newWindow)
		local window = newWindow(nil, true)
		local tab = window:CreateTab({ Name = "Alive" })
		local label = tab:CreateLabel()
		window.UI:Destroy()
		componentDead(label)
		equal(window.ScreenGui.Parent, playerGui)
		equal(window:GetTab("Alive"), tab)
		window:Hide()
		window:Show()
		equal(window:IsVisible(), true)
		rejects(function() tab:CreateLabel() end)
		window:Destroy()
		empty(window.Pages); empty(window.Tabs)
		windowDead(window)
	end)

	test("External ScreenGui destruction tears down window and tabs", function(newWindow)
		local window = newWindow(nil, true)
		local tab = window:CreateTab({ Name = "Alive" })
		local key = tab:CreateKeybind()
		window.ScreenGui:Destroy()
		task.wait()
		windowDead(window); tabDead(tab); componentDead(key)
		empty(window.Pages); empty(window.Tabs)
	end)

	test("Repeated window construction and explicit destruction leave no GUI residue", function(newWindow)
		local before = #playerGui:GetChildren()
		for index = 1, 5 do
			local window = newWindow({ Name = "WindowSpecRepeat" }, index % 2 == 0)
			local tab = window:CreateTab({ Name = "Alive" })
			tab:CreateSlider()
			window:Minimize()
			window:Restore()
			window:Destroy()
			windowDead(window)
		end
		task.wait()
		equal(#playerGui:GetChildren(), before)
	end)

	print(string.format("UILibrary Window: %d tests passed", passed))
	return passed
end
