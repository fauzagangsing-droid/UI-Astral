return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local dimensions = context.Theme.Dimensions
	local name = config.Name or "Slider"
	local min = H.Number(config.Min, 0, "Slider.Min")
	local max = H.Number(config.Max, 100, "Slider.Max")
	local step = H.Number(config.Step, 1, "Slider.Step")
	if max < min then
		min, max = max, min
	end
	if step <= 0 then
		step = 1
	end
	local defaultValue = H.Number(config.Default, min, "Slider.Default")
	local callback = H.Callback(config.Callback)

	local row = H.Make("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, dimensions.RowHeight),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local scope = H.Scope(row)
	H.Make("UICorner", { CornerRadius = UDim.new(0, dimensions.CornerRadius), Parent = row })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = row })

	H.Make("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -90, 0, 14),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local valueLabel = H.Make("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.new(0, 70, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 12,
		TextColor3 = C.SubText,
		Font = fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local track = H.Make("TextButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0, 32),
		Size = UDim2.new(1, -24, 0, 4),
		BackgroundColor3 = C.Border,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = H.Make("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = C.Primary,
		BorderSizePixel = 0,
		Parent = track,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	local knob = H.Make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		Parent = track,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	H.Make("UIStroke", { Color = C.Primary, Thickness = 1, Parent = knob })

	local function decimalPlaces(number)
		local mantissa, exponent = string.match(string.format("%.15g", number), "^([^eE]+)[eE]?(.*)$")
		local fraction = string.match(mantissa, "%.(%d+)") or ""
		return math.max(0, #fraction - (tonumber(exponent) or 0))
	end
	-- Include the bounds: integer steps can still have a fractional origin or endpoint.
	local precision = math.max(decimalPlaces(min), decimalPlaces(max), decimalPlaces(step))
	local numberFormat = "%." .. precision .. "f"
	local value
	local function snap(v)
		v = math.clamp(v, min, max)
		local increments = (v - min) / step
		-- Half-step ties must not round down because of binary division drift.
		local tolerance = math.min(1e-7, math.abs(increments) * 1e-14)
		local snapped = min + math.floor(increments + 0.5 + tolerance) * step
		-- Decimal rounding removes binary drift without forcing six decimal places.
		snapped = tonumber(string.format(numberFormat, snapped))
		return math.clamp(snapped, min, max)
	end
	local function render()
		local alpha = (max ~= min) and (value - min) / (max - min) or 0
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		local shown = string.format(numberFormat, value)
		if precision > 0 then
			shown = string.gsub(string.gsub(shown, "0+$", ""), "%.$", "")
		end
		valueLabel.Text = shown == "-0" and "0" or shown
	end
	local function setValue(v, silent)
		if scope.Destroyed then
			return
		end
		value = snap(v)
		render()
		if callback and not silent then
			callback(value)
		end
	end

	H.BindDrag(scope, track, function(input)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		setValue(min + alpha * (max - min), false)
	end)
	setValue(defaultValue, true)

	return {
		GetValue = function()
			return value
		end,
		SetValue = function(v)
			setValue(H.Number(v, nil, "Slider.Value"), false)
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
