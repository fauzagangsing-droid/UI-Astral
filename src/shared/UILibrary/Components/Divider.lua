return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local holder = H.Make("Frame", {
		Name = config.Name or "Divider",
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local scope = H.Scope(holder)
	H.Make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = context.Theme.Colors.Border,
		BorderSizePixel = 0,
		Parent = holder,
	})

	return {
		Destroy = function()
			scope:Destroy()
		end,
		_instance = holder,
	}
end
