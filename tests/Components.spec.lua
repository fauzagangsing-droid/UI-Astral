-- Manual client Studio runner. Requiring this ModuleScript does not run tests.
return function()
	local RunService = game:GetService("RunService")
	assert(RunService:IsStudio() and RunService:IsClient(), "Run Components.spec on a Studio Play client")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Library = require(ReplicatedStorage:WaitForChild("UILibrary"))
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local passed = 0

	local function equal(actual, expected, message)
		assert(actual == expected, (message or "Values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance)
		assert(math.abs(actual - expected) < (tolerance or 1e-6), "Expected approximately " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function array(actual, expected)
		equal(#actual, #expected, "Array length")
		for index, value in ipairs(expected) do equal(actual[index], value, "Array entry " .. index) end
	end
	local function rejects(callback)
		local ok = pcall(callback)
		assert(not ok, "Expected an error")
	end
	local function child(parent, name, className)
		local result = parent:FindFirstChild(name)
		assert(result and result:IsA(className), "Missing " .. className .. " " .. name)
		return result
	end
	local function buttons(parent)
		local result = {}
		for _, item in ipairs(parent:GetChildren()) do
			if item:IsA("TextButton") then table.insert(result, item.Text) end
		end
		table.sort(result)
		return result
	end

	-- Each case owns its resources, including extra libraries and unparented scope roots.
	-- Cleanup runs after xpcall even when an assertion or construction fails.
	local function test(name, body)
		local cleanups = {}
		local function own(cleanup)
			table.insert(cleanups, cleanup)
		end
		local ok, message = xpcall(function()
			local gui = Instance.new("ScreenGui")
			own(function() gui:Destroy() end)
			gui.Name = "UILibraryComponentTests"
			gui.ResetOnSpawn = false
			gui.Parent = playerGui
			local UI = Library.new({ ScreenGui = gui })
			own(function() UI:Destroy() end)
			local panel = Instance.new("Frame")
			panel.Size = UDim2.fromOffset(400, 600)
			panel.Parent = gui
			body(UI, panel, gui, own)
		end, debug.traceback)
		local cleanupErrors = {}
		for index = #cleanups, 1, -1 do
			local cleaned, reason = pcall(cleanups[index])
			if not cleaned then table.insert(cleanupErrors, tostring(reason)) end
		end
		if not ok then error(name .. " failed:\n" .. tostring(message), 0) end
		assert(#cleanupErrors == 0, name .. " cleanup failed: " .. table.concat(cleanupErrors, "; "))
		passed += 1
	end

	local factories = {
		{ "Toggle", { Default = true }, "GetValue", true, "SetValue", false },
		{ "Slider", { Min = 0, Max = 10, Default = 3 }, "GetValue", 3, "SetValue", 7 },
		{ "Button", { Text = "Initial" }, "GetText", "Initial", "SetText", "Changed" },
		{ "Dropdown", { Options = { "A", "B" }, Default = "A" }, "GetValue", "A", "SetValue", "B" },
		{ "MultiDropdown", { Options = { "A", "B" }, Default = { "A" } }, "GetValues", { "A" }, "SetValues", { "B" } },
		{ "TextBox", { Default = "Initial" }, "GetValue", "Initial", "SetValue", "Changed" },
		{ "Keybind", { Default = Enum.KeyCode.Q }, "GetKey", Enum.KeyCode.Q, "SetKey", Enum.KeyCode.E },
		{ "ColorPicker", { DefaultColor = Color3.fromRGB(12, 34, 56) }, "GetColor", Color3.fromRGB(12, 34, 56), "SetColor", Color3.fromRGB(78, 90, 123) },
		{ "Notification", { Title = "Initial", Content = "Body" }, "GetTitle", "Initial", "SetTitle", "Changed" },
		{ "Section", { Collapsible = true, DefaultExpanded = true }, "GetExpanded", true, "SetExpanded", false },
		{ "Label", { Text = "Initial" }, "GetText", "Initial", "SetText", "Changed" },
		{ "Paragraph", { Title = "Initial", Content = "Body" }, "GetTitle", "Initial", "SetTitle", "Changed" },
		{ "Divider", {} },
		{ "ProgressBar", { Min = 0, Max = 10, Default = 3 }, "GetValue", 3, "SetValue", 7 },
		{ "SearchBox", {}, "GetValue", "", "SetValue", "Changed" },
	}
	equal(#factories, 15)
	local function create(UI, panel, kind, config, colon)
		local factory = UI["Create" .. kind]
		assert(type(factory) == "function", "Missing factory " .. kind)
		if kind == "Notification" then
			if colon then return factory(UI, config) end
			return factory(config)
		end
		if colon then return factory(UI, panel, config) end
		return factory(panel, config)
	end
	local function valueEqual(actual, expected)
		if type(expected) == "table" then array(actual, expected) else equal(actual, expected) end
	end
	local function dead(api)
		api:Destroy()
		api.Destroy()
		for name, method in pairs(api) do
			if type(method) == "function" and name ~= "Destroy" then
				rejects(function() method(api) end)
				rejects(function() method() end)
			end
		end
	end

	for _, spec in ipairs(factories) do
		test(spec[1] .. " initialization, independence, call styles and destruction", function(UI, panel, gui)
			local calls = 0
			local config = table.clone(spec[2])
			config.Callback = function() calls += 1 end
			config.LayoutOrder = 17
			local a = create(UI, panel, spec[1], config, true)
			local b = create(UI, panel, spec[1], config, false)
			task.wait() -- Flush deferred property signals before checking construction silence.
			equal(calls, 0, "Construction must be silent")
			assert(a ~= b and a._instance ~= b._instance, "Factories must return independent instances")
			equal(a._instance.LayoutOrder, 17)
			equal(a._instance.Parent, spec[1] == "Notification" and gui:FindFirstChild("Notifications") or panel)
			if spec[3] then
				valueEqual(a[spec[3]](a), spec[4])
				valueEqual(b[spec[3]](), spec[4])
				a[spec[5]](a, spec[6])
				valueEqual(a[spec[3]](), spec[6])
				valueEqual(b[spec[3]](b), spec[4])
				b[spec[5]](spec[6])
				valueEqual(b[spec[3]](), spec[6])
			end
			a:Destroy()
			task.wait()
			equal(a._instance.Parent, nil)
			assert(b._instance:IsDescendantOf(gui), "Destroying a sibling must not destroy b")
			dead(a)
			b._instance:Destroy()
			task.wait()
			dead(b)
		end)
	end

	test("Callback counts and replacement", function(UI, panel)
		for _, kind in ipairs({ "Toggle", "Slider", "ProgressBar", "Dropdown", "MultiDropdown", "ColorPicker" }) do
			local count, replacement, last = 0, 0, nil
			local config = { Options = { "A", "B" }, Callback = function(value) count += 1; last = value end }
			local api = create(UI, panel, kind, config, true)
			equal(count, 0)
			local method, value = "SetValue", 5
			if kind == "Toggle" then value = true end
			if kind == "Dropdown" then value = "B" end
			if kind == "MultiDropdown" then method, value = "SetValues", { "B" } end
			if kind == "ColorPicker" then method, value = "SetColor", Color3.fromRGB(23, 87, 151) end
			api[method](api, value)
			equal(count, 1, kind .. " setter callback count")
			valueEqual(last, value)
			api.SetCallback(function() replacement += 1 end)
			api[method](value)
			equal(count, 1)
			equal(replacement, 1)
			api:SetCallback(nil)
			api[method](api, value)
			equal(replacement, 1)
		end
		local count = 0
		local search = UI:CreateSearchBox(panel, { Callback = function() count += 1 end })
		search:SetValue("one")
		task.wait()
		equal(count, 1)
		search.Clear()
		task.wait()
		equal(count, 2)
	end)

	test("Slider bounds, steps, decimals and upward ties", function(UI, panel)
		local cases = {
			{ { Min = 10, Max = -10, Default = 99 }, 10, -99, -10, "-10" },
			{ { Min = 4, Max = 4, Default = -8 }, 4, 100, 4, "4" },
			{ { Min = 0, Max = 10, Step = 0, Default = 1.4 }, 1, 2.5, 3, "3" },
			{ { Min = 0, Max = 10, Step = -2, Default = 1.6 }, 2, 3.5, 4, "4" },
			{ { Min = 0, Max = 1, Step = 0.1, Default = 0.24 }, 0.2, 0.35, 0.4, "0.4" },
			{ { Min = -1, Max = 1, Step = 0.1, Default = -0.85 }, -0.8, -0.65, -0.6, "-0.6" },
			{ { Min = 0.25, Max = 3.25, Step = 1 }, 0.25, 0.75, 1.25, "1.25" },
			{ { Min = 0, Max = 0.000001, Step = 0.0000001 }, 0, 0.00000035, 0.0000004, "0.0000004" },
		}
		for _, case in ipairs(cases) do
			local api = UI:CreateSlider(panel, case[1])
			near(api:GetValue(), case[2], 1e-12)
			api.SetValue(case[3])
			near(api.GetValue(), case[4], 1e-12)
			equal(child(api._instance, "Value", "TextLabel").Text, case[5])
			if case[1].Min == case[1].Max then
				local track = child(api._instance, "Track", "TextButton")
				equal(child(track, "Fill", "Frame").Size.X.Scale, 0)
			end
		end
	end)

	test("ColorPicker atomic RGB state and rendering", function(UI, panel)
		local function rendered(api, color)
			local actual = api:GetColor()
			near(actual.R, color.R); near(actual.G, color.G); near(actual.B, color.B)
			local header = child(api._instance, "Header", "TextButton")
			local preview = header:FindFirstChildWhichIsA("Frame")
			assert(preview, "Missing color preview")
			equal(preview.BackgroundColor3, color)
			local values = { R = color.R, G = color.G, B = color.B }
			for channel, value in pairs(values) do
				local row = child(child(api._instance, "Panel", "Frame"), channel, "Frame")
				local found = false
				for _, item in ipairs(row:GetDescendants()) do
					if item:IsA("TextLabel") and item.TextXAlignment == Enum.TextXAlignment.Right then
						equal(item.Text, tostring(math.floor(value * 255 + 0.5)))
						found = true
					end
				end
				assert(found, "Missing " .. channel .. " value label")
				local track = row:FindFirstChildWhichIsA("TextButton")
				assert(track, "Missing RGB track")
				local frames = 0
				for _, item in ipairs(track:GetChildren()) do
					if item:IsA("Frame") then
						frames += 1
						if item.AnchorPoint.X == 0.5 then near(item.Position.X.Scale, value)
						else near(item.Size.X.Scale, value) end
					end
				end
				equal(frames, 2, "RGB fill and knob")
			end
		end
		local initial = Color3.fromRGB(17, 93, 201)
		local api = UI:CreateColorPicker(panel, { DefaultColor = initial })
		rendered(api, initial)
		local count = 0
		api:SetCallback(function(color)
			count += 1
			rendered(api, color) -- All three channels must already be rendered inside the callback.
		end)
		api:SetExpanded(true)
		equal(api.GetExpanded(), true)
		api.SetColor(Color3.fromRGB(231, 45, 126))
		equal(count, 1)
		api.SetExpanded(false)
		equal(child(api._instance, "Panel", "Frame").Visible, false)
	end)

	test("Dropdown defaults, cloned options, invalidation and search hierarchy", function(UI, panel)
		local options = { "Alpha", "Beta", "Alpha", "A.b" }
		local count = 0
		local api = UI:CreateDropdown(panel, {
			Options = options, Default = "Missing", Searchable = true, Callback = function() count += 1 end,
		})
		equal(api:GetValue(), nil)
		options[1] = "Mutated"
		equal(api:SetValue("Mutated"), false)
		equal(api.SetValue("Alpha"), true)
		equal(count, 1)
		equal(api:SetValue("Missing"), false)
		equal(api:GetValue(), "Alpha")
		equal(count, 1)
		local list = child(api._instance, "List", "Frame")
		local search = child(list, "Search", "TextBox")
		local entries = child(list, "Options", "ScrollingFrame")
		assert(search.Parent == entries.Parent and search.Parent ~= entries, "Search must be outside the option layout")
		assert(entries:FindFirstChildWhichIsA("UIListLayout"), "Missing options layout")
		api:SetExpanded(true)
		array(buttons(entries), { "A.b", "Alpha", "Beta" })
		search.Text = "a.B"
		task.wait()
		array(buttons(entries), { "A.b" }) -- Literal, case-insensitive search, not a Lua pattern.
		api:SetExpanded(false)
		api.SetExpanded(true)
		task.wait()
		equal(search.Text, "")
		local replacement = { "Beta", "Gamma" }
		api:SetOptions(replacement)
		equal(api.GetValue(), nil)
		equal(count, 1, "SetOptions invalidation must be silent")
		replacement[1] = "Changed"
		equal(api:SetValue("Beta"), true)
		api.SetOptions({ "Beta" })
		equal(api:GetValue(), "Beta")
		api:SetOptions(nil)
		equal(api:GetValue(), nil)
		array(buttons(entries), {})
	end)

	test("MultiDropdown cap, deduplication and defensive copies", function(UI, panel)
		local options, defaults = { "A", "B", "C", "A" }, { "A", "A", "Missing", "B", "C" }
		local calls, payload = 0, nil
		local api = UI:CreateMultiDropdown(panel, {
			Options = options, Default = defaults, MaxSelections = 2, Searchable = true,
			Callback = function(values) calls += 1; payload = values; values[1] = "Tampered" end,
		})
		array(api:GetValues(), { "A", "B" })
		equal(calls, 0)
		options[1], defaults[1] = "Changed", "Changed"
		local copy = api.GetValues()
		copy[1] = "Changed"
		array(api:GetValues(), { "A", "B" })
		local values = { "C", "C", "B", "A" }
		api.SetValues(values)
		values[1] = "Changed"
		equal(calls, 1)
		assert(payload ~= values)
		array(api:GetValues(), { "C", "B" })
		local replacement = { "B", "A" }
		api:SetOptions(replacement)
		replacement[1] = "Changed"
		array(api:GetValues(), { "B" })
		equal(calls, 1)
		api:SetValues({ "B", "A", "C" })
		array(api:GetValues(), { "B", "A" })
		local list = child(api._instance, "List", "Frame")
		child(list, "Search", "TextBox")
		child(list, "Options", "ScrollingFrame")
		local zero = UI:CreateMultiDropdown(panel, { Options = { "A" }, Default = { "A" }, MaxSelections = 0 })
		zero:SetValues({ "A" })
		array(zero:GetValues(), {})
	end)

	test("NumericOnly default and SetValue sanitization", function(UI, panel)
		local calls = 0
		local api = UI:CreateTextBox(panel, { NumericOnly = true, Default = "a--12..3x-4", Callback = function() calls += 1 end })
		equal(api:GetValue(), "-12.34")
		api.SetValue("x1-2.3.4z")
		equal(api.GetValue(), "12.34")
		api:SetValue(-42.5)
		equal(api:GetValue(), "-42.5")
		api:SetValue("letters")
		equal(api:GetValue(), "")
		api.Clear()
		task.wait()
		equal(calls, 0, "TextBox programmatic changes are silent")
	end)

	test("Section Container, AddComponent and collapse", function(UI, panel)
		local section = UI:CreateSection(panel, { Collapsible = true, DefaultExpanded = false })
		equal(section.Container, child(section._instance, "Container", "Frame"))
		equal(section:GetExpanded(), false)
		equal(section.Container.Visible, false)
		local label = UI:CreateLabel(panel, { Text = "Moved API" })
		section:AddComponent(label)
		equal(label._instance.Parent, section.Container)
		local button = UI:CreateButton(panel, {})
		section.AddComponent(button._instance)
		equal(button._instance.Parent, section.Container)
		section:SetExpanded(true)
		equal(section.Container.Visible, true)
		assert(section._instance.Size.Y.Offset > 32)
		section.SetExpanded(false)
		equal(section._instance.Size.Y.Offset, 32)
		equal(label._instance.Parent, section.Container, "Collapse must not remove children")
		section:Destroy()
		task.wait()
		dead(label); dead(button)
	end)

	test("Keybind enum validation, aliases and cancellation", function(UI, panel)
		local count = 0
		local api = UI:CreateKeybind(panel, { Default = Enum.KeyCode.Q, Callback = function() count += 1 end })
		equal(api:GetValue(), api.GetKey())
		api.SetValue(Enum.KeyCode.E)
		equal(api:GetKey(), Enum.KeyCode.E)
		api:SetKey(Enum.KeyCode.Unknown)
		api.CancelCapture()
		api:CancelCapture()
		equal(api:GetValue(), Enum.KeyCode.Unknown)
		local button = api._instance:FindFirstChildWhichIsA("TextButton")
		assert(button)
		equal(button.Text, "None")
		for _, bad in ipairs({ "Q", 1, Enum.UserInputType.Keyboard, Enum.Font.Gotham }) do
			rejects(function() api:SetKey(bad) end)
			equal(api:GetKey(), Enum.KeyCode.Unknown)
		end
		equal(count, 0, "SetKey and CancelCapture are silent")
	end)

	test("Invalid configs are transactional; invalid setters preserve state", function(UI, panel, gui)
		local function noLeak(callback)
			local before = #gui:GetDescendants()
			rejects(callback)
			task.wait()
			equal(#gui:GetDescendants(), before, "Invalid config leaked UI")
		end
		for _, spec in ipairs(factories) do
			for _, bad in ipairs({ { Callback = true }, { Name = 123 }, { LayoutOrder = 1.5 }, { LayoutOrder = math.huge } }) do
				noLeak(function() create(UI, panel, spec[1], bad, true) end)
			end
			noLeak(function() create(UI, panel, spec[1], "not a config", false) end)
		end
		local invalid = {
			{ "Slider", { Min = "bad" } }, { "Slider", { Step = 0 / 0 } },
			{ "Dropdown", { Options = { [2] = "Sparse" } } },
			{ "MultiDropdown", { MaxSelections = -1 } }, { "MultiDropdown", { MaxSelections = 1.5 } },
			{ "MultiDropdown", { Default = { true } } }, { "Keybind", { Default = "Q" } },
			{ "ColorPicker", { DefaultColor = "red" } }, { "Notification", { Duration = math.huge } },
			{ "ProgressBar", { Max = 0 / 0 } }, { "Label", { TextSize = math.huge } },
			-- Property errors after a factory has already started constructing descendants.
			{ "TextBox", { Placeholder = {} } }, { "Paragraph", { Content = {} } },
			{ "Notification", { Content = {} } }, { "SearchBox", { Placeholder = {} } },
			{ "Button", { Text = {} } },
		}
		for _, case in ipairs(invalid) do
			noLeak(function() create(UI, panel, case[1], case[2], true) end)
		end
		noLeak(function() UI:CreateToggle(gui, {}) end)
		local count = 0
		local function callback() count += 1 end
		local slider = UI:CreateSlider(panel, { Default = 7, Callback = callback })
		local color = UI:CreateColorPicker(panel, { DefaultColor = Color3.fromRGB(1, 2, 3), Callback = callback })
		local dropdown = UI:CreateDropdown(panel, { Options = { "A", "B" }, Default = "A", Callback = callback })
		local multi = UI:CreateMultiDropdown(panel, { Options = { "A", "B" }, Default = { "A" }, Callback = callback })
		local progress = UI:CreateProgressBar(panel, { Default = 8, Callback = callback })
		local before = #gui:GetDescendants()
		for _, bad in ipairs({ "bad", math.huge, -math.huge, 0 / 0 }) do
			rejects(function() slider:SetValue(bad) end)
			rejects(function() progress:SetValue(bad) end)
		end
		rejects(function() color:SetColor("red") end)
		rejects(function() color:SetExpanded("yes") end)
		for _, bad in ipairs({ { true }, { [2] = "Sparse" }, { A = "Map" }, { math.huge } }) do
			rejects(function() dropdown:SetOptions(bad) end)
			rejects(function() multi:SetOptions(bad) end)
			rejects(function() multi:SetValues(bad) end)
		end
		for _, api in ipairs({ slider, color, dropdown, multi, progress }) do
			rejects(function() api:SetCallback(false) end)
		end
		equal(slider:GetValue(), 7); equal(progress:GetValue(), 8)
		equal(color:GetColor(), Color3.fromRGB(1, 2, 3)); equal(color:GetExpanded(), false)
		equal(dropdown:GetValue(), "A"); array(multi:GetValues(), { "A" })
		equal(#gui:GetDescendants(), before)
		equal(count, 0)
		slider:SetValue(6)
		equal(count, 1, "Rejected SetCallback must preserve the callback")
	end)

	test("Notification Show, expiry and early timer cleanup", function(UI, _, gui, own)
		local api = UI:CreateNotification({ Title = "Title", Content = "Body", Duration = 0.1 })
		equal(api._instance.Visible, false)
		equal(api:GetContent(), "Body")
		api.SetContent("Updated")
		equal(api.GetContent(), "Updated")
		local destroyed = 0
		local connection = api._instance.Destroying:Connect(function() destroyed += 1 end)
		own(function() connection:Disconnect() end)
		api:Show()
		api.Show()
		equal(api._instance.Visible, true)
		task.wait(0.3)
		equal(destroyed, 1)
		equal(api._instance.Parent, nil)
		dead(api)
		local early = UI.CreateNotification({ Duration = 0.1 })
		local earlyDestroyed = 0
		local earlyConnection = early._instance.Destroying:Connect(function() earlyDestroyed += 1 end)
		own(function() earlyConnection:Disconnect() end)
		early:Show()
		early:Destroy()
		task.wait()
		local before = #gui:GetDescendants()
		task.wait(0.3) -- Wait past the canceled timer's deadline.
		equal(earlyDestroyed, 1)
		equal(#gui:GetDescendants(), before)
		dead(early)
	end)

	test("Parent destruction and library ownership", function(UI, panel, gui)
		local nested = Instance.new("Frame")
		nested.Parent = panel
		local api = UI:CreateSlider(nested, {})
		nested:Destroy()
		task.wait()
		dead(api)
		local survivors = {}
		for _, spec in ipairs(factories) do table.insert(survivors, create(UI, panel, spec[1], spec[2], true)) end
		UI:Destroy()
		UI.Destroy()
		task.wait()
		equal(gui.Parent, playerGui, "Library must leave supplied ScreenGui alive")
		equal(panel.Parent, gui, "Library must leave caller-owned panel alive")
		equal(gui:FindFirstChild("Notifications"), nil)
		for _, survivor in ipairs(survivors) do dead(survivor) end
		for _, spec in ipairs(factories) do
			rejects(function() create(UI, panel, spec[1], {}, true) end)
			rejects(function() create(UI, panel, spec[1], {}, false) end)
		end
	end)

	test("ScreenGui destruction tears down library", function(UI, panel, gui)
		local api = UI:CreateKeybind(panel, {})
		local notification = UI:CreateNotification({ Duration = 0.1 })
		notification:Show()
		gui:Destroy()
		task.wait(0.2)
		dead(api); dead(notification)
		UI:Destroy()
		rejects(function() UI:CreateNotification({}) end)
		rejects(function() UI:CreateLabel(panel, {}) end)
	end)

	test("Repeated component create/destroy leaves no UI", function(UI, panel, gui)
		local before = #gui:GetDescendants()
		for _ = 1, 20 do
			local slider = UI:CreateSlider(panel, {})
			local picker = UI:CreateColorPicker(panel, {})
			local key = UI:CreateKeybind(panel, {})
			slider:SetValue(12); picker:SetExpanded(true); key:CancelCapture()
			slider:Destroy(); picker:Destroy(); key:Destroy()
		end
		task.wait()
		equal(#gui:GetDescendants(), before)
	end)

	test("Scope disconnects instrumented signals on explicit and root destruction", function(UI, _, _, own)
		-- This measures Scope's contract, not Roblox's private UserInputService listeners.
		local function fakeSignal()
			local signal = { Count = 0, Disconnects = 0, listeners = {} }
			function signal:Connect(callback)
				local connection = { Connected = true }
				self.Count += 1
				self.listeners[connection] = callback
				function connection:Disconnect()
					if not self.Connected then return end
					self.Connected = false
					signal.Count -= 1
					signal.Disconnects += 1
					signal.listeners[self] = nil
				end
				return connection
			end
			function signal:Fire(...)
				for _, callback in pairs(table.clone(self.listeners)) do callback(...) end
			end
			return signal
		end
		local signal = fakeSignal()
		local calls = 0
		for index = 1, 20 do
			local root = Instance.new("Frame")
			own(function() root:Destroy() end)
			local scope = UI.Helpers.Scope(root)
			own(function() scope:Destroy() end)
			local connection = scope:Connect(signal, function(value) calls += value end)
			equal(signal.Count, 1)
			signal:Fire(1)
			equal(calls, index)
			if index % 2 == 0 then root:Destroy(); task.wait() else scope:Destroy() end
			equal(scope.Destroyed, true)
			equal(connection.Connected, false)
			equal(signal.Count, 0)
			equal(signal.Disconnects, index)
			scope:Destroy()
			signal:Fire(100)
			equal(calls, index)
			rejects(function() scope:Connect(signal, function() end) end)
			local late = 0
			scope:Add(function() late += 1 end)
			equal(late, 1, "Cleanup added after destruction runs immediately")
		end
	end)

	print(string.format("UILibrary Components: %d tests passed", passed))
	return passed
end
