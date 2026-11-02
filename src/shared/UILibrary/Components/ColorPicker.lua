return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local name = config.Name or "Color Picker"
	local callback = H.Callback(config.Callback)
	local function validateColor(value)
		if typeof(value) ~= "Color3" then
			error("ColorPicker color must be a Color3", 3)
		end
		H.Number(value.R, nil, "ColorPicker.Color.R")
		H.Number(value.G, nil, "ColorPicker.Color.G")
		H.Number(value.B, nil, "ColorPicker.Color.B")
		return value
	end
	local color = validateColor(config.DefaultColor == nil and C.Primary or config.DefaultColor)
	local expanded = false
	local HEADER = context.Theme.Dimensions.RowHeight
	local PANEL = 104

	local row = H.CardRow(parent, name, HEADER)
	local scope = H.Scope(row)
	local header = H.Make("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("TextLabel", {
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -90, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local preview = H.Make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.5, 0),
		Size = UDim2.new(0, 22, 0, 22),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = preview })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = preview })
	local chevron = H.Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundTransparency = 1,
		Text = "▾",
		TextSize = 14,
		TextColor3 = C.SubText,
		Font = fonts.Medium,
		Parent = header,
	})
	local panel = H.Make("Frame", {
		Name = "Panel",
		Position = UDim2.new(0, 0, 0, HEADER),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = row,
	})
	H.Make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = panel,
	})
	H.Make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = panel,
	})

	local renderers = {}
	local function applyColor(newColor, fire)
		if scope.Destroyed then
			return
		end
		color = newColor
		preview.BackgroundColor3 = color
		-- Renderers never mutate color or emit callbacks, so updates are atomic.
		renderers[1](color.R * 255)
		renderers[2](color.G * 255)
		renderers[3](color.B * 255)
		if fire and callback then
			callback(color)
		end
	end
	local function channelRow(chanLabel, order, onChange)
		local holder = H.Make("Frame", {
			Name = chanLabel,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Parent = panel,
		})
		H.Make("TextLabel", {
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundTransparency = 1,
			Text = chanLabel,
			TextSize = 12,
			TextColor3 = C.SubText,
			Font = fonts.Medium,
			Parent = holder,
		})
		local valLabel = H.Make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 28, 0, 14),
			BackgroundTransparency = 1,
			Text = "0",
			TextSize = 11,
			TextColor3 = C.SubText,
			Font = fonts.Regular,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = holder,
		})
		local track = H.Make("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 22, 0.5, 0),
			Size = UDim2.new(1, -56, 0, 4),
			BackgroundColor3 = C.Border,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Parent = holder,
		})
		H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
		local fill = H.Make("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = C.Primary,
			BorderSizePixel = 0,
			Parent = track,
		})
		H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
		local knob = H.Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 12, 0, 12),
			BackgroundColor3 = C.Text,
			BorderSizePixel = 0,
			Parent = track,
		})
		H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
		H.Make("UIStroke", { Color = C.Primary, Thickness = 1, Parent = knob })

		H.BindDrag(scope, track, function(input)
			local width = track.AbsoluteSize.X
			if not expanded or width <= 0 then
				return
			end
			local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
			onChange(alpha)
		end)
		return function(v)
			v = math.clamp(v, 0, 255)
			valLabel.Text = tostring(math.floor(v + 0.5))
			local alpha = v / 255
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		end
	end

	renderers[1] = channelRow("R", 1, function(v)
		applyColor(Color3.new(v, color.G, color.B), true)
	end)
	renderers[2] = channelRow("G", 2, function(v)
		applyColor(Color3.new(color.R, v, color.B), true)
	end)
	renderers[3] = channelRow("B", 3, function(v)
		applyColor(Color3.new(color.R, color.G, v), true)
	end)
	applyColor(color, false)

	local function setExpanded(open)
		if type(open) ~= "boolean" then
			error("ColorPicker.SetExpanded expects a boolean", 2)
		end
		if scope.Destroyed then
			return
		end
		expanded = open
		chevron.Text = open and "▴" or "▾"
		panel.Visible = open
		panel.Size = UDim2.new(1, 0, 0, open and PANEL or 0)
		row.Size = UDim2.new(1, 0, 0, open and (HEADER + PANEL) or HEADER)
	end
	setExpanded(false)
	scope:Connect(header.MouseButton1Click, function()
		setExpanded(not expanded)
	end)

	return {
		GetColor = function()
			return color
		end,
		SetColor = function(newColor)
			applyColor(validateColor(newColor), true)
		end,
		SetExpanded = setExpanded,
		GetExpanded = function()
			return expanded
		end,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
