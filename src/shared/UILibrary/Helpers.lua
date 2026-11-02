local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Helpers = {}

function Helpers.new(theme)
	local H = {}
	local scopes = setmetatable({}, { __mode = "k" })

	function H.GetScope(root)
		return scopes[root]
	end

	function H.Number(value, default, name)
		if value == nil then value = default end
		assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
			(name or "Value") .. " must be a finite number")
		return value
	end

	function H.Callback(callback)
		assert(callback == nil or type(callback) == "function", "Callback must be a function or nil")
		return callback
	end

	function H.Options(values)
		if values == nil then return {} end
		assert(type(values) == "table", "Options/values must be an array")
		local count = 0
		for key in pairs(values) do
			assert(type(key) == "number" and key >= 1 and key % 1 == 0, "Options/values must be a dense array")
			count += 1
		end
		local result, seen = {}, {}
		for index = 1, count do
			local value = values[index]
			assert(type(value) == "string" or (type(value) == "number" and value == value and math.abs(value) < math.huge),
				"Options/values must be a dense array of strings or finite numbers")
			if not seen[value] then
				seen[value] = true
				table.insert(result, value)
			end
		end
		return result
	end

	function H.Make(className, props)
		local inst = Instance.new(className)
		-- Invalid properties must not leave a partially constructed Instance behind.
		local ok, message = pcall(function()
			for key, value in pairs(props) do
				if key ~= "Parent" then inst[key] = value end
			end
			inst.Parent = props.Parent
		end)
		if not ok then inst:Destroy(); error(message, 2) end
		return inst
	end

	function H.Tween(inst, duration, goal)
		local animation = TweenService:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		local destroying, completed
		local function disconnect()
			if destroying then destroying:Disconnect(); destroying = nil end
			if completed then completed:Disconnect(); completed = nil end
		end
		destroying = inst.Destroying:Connect(function()
			disconnect()
			animation:Cancel()
		end)
		completed = animation.Completed:Connect(disconnect)
		animation:Play()
		return animation
	end

	function H.CardRow(parent, name, height)
		local row = H.Make("Frame", {
			Name = name, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = theme.Colors.Card,
			BorderSizePixel = 0, Parent = parent,
		})
		H.Make("UICorner", { CornerRadius = UDim.new(0, theme.Dimensions.CornerRadius), Parent = row })
		H.Make("UIStroke", { Color = theme.Colors.Border, Thickness = 1, Parent = row })
		return row
	end

	function H.Scope(root)
		local scope = { Destroyed = false }
		scopes[root] = scope
		local cleanups = {}
		local destroying
		local function clean()
			if scope.Destroyed then return end
			scope.Destroyed = true
			scopes[root] = nil
			if destroying then destroying:Disconnect(); destroying = nil end
			for index = #cleanups, 1, -1 do
				local ok, message = pcall(cleanups[index])
				if not ok then warn("Astral cleanup: " .. tostring(message)) end
			end
			table.clear(cleanups)
		end
		function scope:Add(cleanup)
			assert(type(cleanup) == "function", "Cleanup must be a function")
			if self.Destroyed then cleanup() else table.insert(cleanups, cleanup) end
			return cleanup
		end
		function scope:Connect(signal, callback)
			assert(not self.Destroyed, "Scope is destroyed")
			local connection = signal:Connect(function(...)
				if not self.Destroyed then callback(...) end
			end)
			self:Add(function() connection:Disconnect() end)
			return connection
		end
		function scope:Destroy()
			if self.Destroyed then return end
			clean()
			-- Explicit parent teardown is synchronous even with deferred Roblox
			-- signals: child gestures/capture must stop before Destroy returns.
			for _, descendant in ipairs(root:GetDescendants()) do
				local childScope = scopes[descendant]
				if childScope then childScope:Destroy() end
			end
			root:Destroy()
		end
		destroying = root.Destroying:Connect(clean)
		return scope
	end

	-- Global input listeners exist only during an active gesture. Track the exact
	-- touch object so another finger cannot move or terminate this gesture.
	function H.BindDrag(scope, target, onUpdate, onEnd)
		local active, changed, ended, focusLost
		local function stop(notify)
			local previous = active
			active = nil
			if changed then changed:Disconnect(); changed = nil end
			if ended then ended:Disconnect(); ended = nil end
			if focusLost then focusLost:Disconnect(); focusLost = nil end
			if previous and notify and onEnd and not scope.Destroyed then onEnd(previous) end
		end
		scope:Add(function() stop(false) end)
		scope:Connect(target.InputBegan, function(input)
			local kind = input.UserInputType
			if active or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then return end
			active = input
			changed = UserInputService.InputChanged:Connect(function(update)
				if scope.Destroyed or not active then return end
				if (kind == Enum.UserInputType.Touch and update == active)
					or (kind == Enum.UserInputType.MouseButton1 and update.UserInputType == Enum.UserInputType.MouseMovement) then
					onUpdate(update, false)
				end
			end)
			ended = UserInputService.InputEnded:Connect(function(update)
				if update == active or (kind == Enum.UserInputType.MouseButton1 and update.UserInputType == kind) then stop(true) end
			end)
			focusLost = UserInputService.WindowFocusReleased:Connect(function() stop(false) end)
			onUpdate(input, true)
		end)
	end

	return H
end

return Helpers
