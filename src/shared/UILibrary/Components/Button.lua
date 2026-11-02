return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local name = config.Name or "Button"
	local callback = H.Callback(config.Callback)
	local isPrimary = string.lower(config.Style or "") == "primary"
	local btn = H.Make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = isPrimary and C.Primary or C.Card,
		Text = config.Text or name,
		TextSize = 13,
		TextColor3 = isPrimary and C.Background or C.Text,
		Font = context.Theme.Fonts.Medium,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local scope = H.Scope(btn)
	H.Make("UICorner", { CornerRadius = UDim.new(0, context.Theme.Dimensions.CornerRadius), Parent = btn })
	if not isPrimary then
		H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = btn })
	end
	scope:Connect(btn.MouseButton1Click, function()
		if callback then
			callback()
		end
	end)

	return {
		GetText = function()
			return btn.Text
		end,
		SetText = function(text)
			if not scope.Destroyed then
				btn.Text = text or ""
			end
		end,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = btn,
	}
end
