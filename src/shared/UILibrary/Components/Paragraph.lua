return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local row = H.CardRow(parent, config.Name or "Paragraph", 0)
	local scope = H.Scope(row)
	row.AutomaticSize = Enum.AutomaticSize.Y
	H.Make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = row,
	})
	H.Make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local titleLabel = H.Make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = config.Title or "Title",
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local contentLabel = H.Make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = config.Content or "",
		TextSize = 12,
		TextColor3 = C.SubText,
		Font = fonts.Regular,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = row,
	})

	return {
		GetTitle = function()
			return titleLabel.Text
		end,
		SetTitle = function(text)
			if not scope.Destroyed then
				titleLabel.Text = text or ""
			end
		end,
		GetContent = function()
			return contentLabel.Text
		end,
		SetContent = function(text)
			if not scope.Destroyed then
				contentLabel.Text = text or ""
			end
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
