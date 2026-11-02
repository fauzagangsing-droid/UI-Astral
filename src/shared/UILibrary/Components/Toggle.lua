return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local dimensions = context.Theme.Dimensions
	local name = config.Name or "Toggle"
	local state = config.Default and true or false
	local callback = H.Callback(config.Callback)

	local row = H.Make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, dimensions.RowHeight),
		BackgroundColor3 = C.Card,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local scope = H.Scope(row)
	H.Make("UICorner", { CornerRadius = UDim.new(0, dimensions.CornerRadius), Parent = row })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = row })
	H.Make("TextLabel", {
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -80, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local switch = H.Make("Frame", {
		Name = "Switch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 20),
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = switch })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = switch })
	local knob = H.Make("Frame", {
		Name = "Knob",
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = C.SubText,
		BorderSizePixel = 0,
		Parent = switch,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local switchTween, knobTween
	local function cancelTweens()
		if switchTween then
			switchTween:Cancel()
			switchTween = nil
		end
		if knobTween then
			knobTween:Cancel()
			knobTween = nil
		end
	end
	scope:Add(cancelTweens)
	local function render(animate)
		cancelTweens()
		local switchColor = state and C.Primary or C.Border
		local knobColor = state and C.Text or C.SubText
		local position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if animate then
			switchTween = H.Tween(switch, 0.18, { BackgroundColor3 = switchColor })
			knobTween = H.Tween(knob, 0.18, { Position = position, BackgroundColor3 = knobColor })
		else
			switch.BackgroundColor3 = switchColor
			knob.Position = position
			knob.BackgroundColor3 = knobColor
		end
	end
	local function setValue(value)
		if scope.Destroyed then
			return
		end
		state = value and true or false
		render(true)
		if callback then
			callback(state)
		end
	end
	render(false)
	scope:Connect(row.MouseButton1Click, function()
		setValue(not state)
	end)

	return {
		GetValue = function()
			return state
		end,
		SetValue = setValue,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
