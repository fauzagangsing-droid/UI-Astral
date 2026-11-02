return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local callback = H.Callback(config.Callback)
	local box = H.Make("TextBox", {
		Name = config.Name or "SearchBox",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = C.Card,
		Text = "",
		PlaceholderText = config.Placeholder or "Search...",
		PlaceholderColor3 = C.SubText,
		TextSize = 12,
		TextColor3 = C.Text,
		Font = context.Theme.Fonts.Regular,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local scope = H.Scope(box)
	H.Make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })
	H.Make("UICorner", { CornerRadius = UDim.new(0, context.Theme.Dimensions.CornerRadius), Parent = box })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = box })
	scope:Connect(box:GetPropertyChangedSignal("Text"), function()
		if callback then
			callback(box.Text)
		end
	end)

	return {
		GetValue = function()
			return box.Text
		end,
		SetValue = function(value)
			if not scope.Destroyed then
				box.Text = tostring(value)
			end
		end,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		Clear = function()
			if not scope.Destroyed then
				box.Text = ""
			end
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = box,
	}
end
