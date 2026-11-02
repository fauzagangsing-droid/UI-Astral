return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local name = config.Name or "Section"
	local collapsible = config.Collapsible and true or false
	local expanded = config.DefaultExpanded ~= false

	local section = H.Make("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local scope = H.Scope(section)
	H.Make("UICorner", { CornerRadius = UDim.new(0, context.Theme.Dimensions.CornerRadius), Parent = section })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = section })
	local header = H.Make("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = section,
	})
	H.Make("TextLabel", {
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -40, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local arrow = H.Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundTransparency = 1,
		Text = expanded and "▾" or "▸",
		TextSize = 14,
		TextColor3 = collapsible and C.SubText or C.Border,
		Font = fonts.Medium,
		Parent = header,
	})
	local container = H.Make("Frame", {
		Name = "Container",
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Visible = expanded,
		Parent = section,
	})
	local layout = H.Make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	H.Make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = container,
	})

	local function resize()
		if scope.Destroyed then
			return
		end
		-- AbsoluteContentSize is screen pixels; offsets are unscaled UI units.
		-- The fixed-height header measures cumulative ancestor UIScale directly.
		local scale = header.AbsoluteSize.Y / 32
		if scale <= 0 then return end
		local height = layout.AbsoluteContentSize.Y / scale + 4 + 8
		container.Size = UDim2.new(1, 0, 0, height)
		section.Size = UDim2.new(1, 0, 0, 32 + (expanded and height or 0))
	end
	local function setExpanded(open)
		if scope.Destroyed then
			return
		end
		expanded = open and true or false
		container.Visible = expanded
		arrow.Text = expanded and "▾" or "▸"
		resize()
	end
	scope:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), resize)
	scope:Connect(header:GetPropertyChangedSignal("AbsoluteSize"), resize)
	if collapsible then
		scope:Connect(header.MouseButton1Click, function()
			setExpanded(not expanded)
		end)
	end
	resize()

	return {
		Container = container,
		AddComponent = function(component)
			if scope.Destroyed then
				return
			end
			local inst
			if typeof(component) == "Instance" then
				inst = component
			elseif type(component) == "table" then
				inst = component._instance
			end
			if typeof(inst) == "Instance" then
				inst.Parent = container
				resize()
			end
		end,
		SetExpanded = setExpanded,
		GetExpanded = function()
			return expanded
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = section,
	}
end
