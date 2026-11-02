return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local textSize = H.Number(config.TextSize, 13, "Label.TextSize")
	local label = H.Make("TextLabel", {
		Name = config.Name or "Label",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = config.Text or "Label",
		TextSize = textSize,
		TextColor3 = config.Color or context.Theme.Colors.Text,
		Font = context.Theme.Fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	local scope = H.Scope(label)

	return {
		GetText = function()
			return label.Text
		end,
		SetText = function(text)
			if not scope.Destroyed then
				label.Text = text or ""
			end
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = label,
	}
end
