return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local name = config.Name or "TextBox"
	local callback = H.Callback(config.Callback)
	local numericOnly = config.NumericOnly and true or false

	local function sanitize(value)
		local text = tostring(value)
		if not numericOnly then
			return text
		end
		local cleaned = text:gsub("[^%d%.%-]", "")
		local sign = cleaned:sub(1, 1) == "-" and "-" or ""
		cleaned = cleaned:gsub("%-", "")
		local decimal = false
		cleaned = cleaned:gsub("%.", function()
			if decimal then
				return ""
			end
			decimal = true
			return "."
		end)
		return sign .. cleaned
	end

	local row = H.CardRow(parent, name, context.Theme.Dimensions.RowHeight)
	local scope = H.Scope(row)
	H.Make("TextLabel", {
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -190, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local input = H.Make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 160, 0, 28),
		BackgroundColor3 = C.Background,
		Text = sanitize(config.Default == nil and "" or config.Default),
		PlaceholderText = config.Placeholder or "",
		PlaceholderColor3 = C.SubText,
		TextSize = 12,
		TextColor3 = C.Text,
		Font = fonts.Regular,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = input })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = input })
	if numericOnly then
		scope:Connect(input:GetPropertyChangedSignal("Text"), function()
			local cleaned = sanitize(input.Text)
			if input.Text ~= cleaned then
				input.Text = cleaned
			end
		end)
	end
	scope:Connect(input.FocusLost, function(entered)
		if entered and callback then
			callback(input.Text)
		end
	end)

	return {
		GetValue = function()
			return input.Text
		end,
		SetValue = function(value)
			if not scope.Destroyed then
				input.Text = sanitize(value)
			end
		end,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		Clear = function()
			if not scope.Destroyed then
				input.Text = ""
			end
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
