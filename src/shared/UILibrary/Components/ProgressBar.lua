return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local min = H.Number(config.Min, 0, "ProgressBar.Min")
	local max = H.Number(config.Max, 100, "ProgressBar.Max")
	if max < min then
		min, max = max, min
	end
	local value = math.clamp(H.Number(config.Default, min, "ProgressBar.Default"), min, max)
	local callback = H.Callback(config.Callback)

	local row = H.CardRow(parent, config.Name or "Progress", context.Theme.Dimensions.RowHeight)
	local scope = H.Scope(row)
	H.Make("TextLabel", {
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -90, 0, 14),
		BackgroundTransparency = 1,
		Text = config.Name or "Progress",
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local valueLabel = H.Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.new(0, 70, 0, 14),
		BackgroundTransparency = 1,
		Text = "0%",
		TextSize = 12,
		TextColor3 = C.SubText,
		Font = fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local track = H.Make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0, 32),
		Size = UDim2.new(1, -24, 0, 4),
		BackgroundColor3 = C.Border,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = H.Make("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = config.Color or C.Primary,
		BorderSizePixel = 0,
		Parent = track,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

	local fillTween
	scope:Add(function()
		if fillTween then
			fillTween:Cancel()
			fillTween = nil
		end
	end)
	local function render(animate)
		local alpha = 0
		if max ~= min then
			local range = max - min
			if range == math.huge then
				-- Opposite finite extremes can overflow when subtracted directly.
				alpha = (value / 2 - min / 2) / (max / 2 - min / 2)
			else
				alpha = (value - min) / range
			end
		end
		if fillTween then
			fillTween:Cancel()
			fillTween = nil
		end
		local size = UDim2.new(alpha, 0, 1, 0)
		if animate then
			fillTween = H.Tween(fill, 0.15, { Size = size })
		else
			fill.Size = size
		end
		valueLabel.Text = tostring(math.floor(alpha * 100 + 0.5)) .. "%"
	end
	render(false)

	return {
		GetValue = function()
			return value
		end,
		SetValue = function(v)
			if scope.Destroyed then
				return
			end
			value = math.clamp(H.Number(v, nil, "ProgressBar.Value"), min, max)
			render(true)
			if callback then
				callback(value)
			end
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
