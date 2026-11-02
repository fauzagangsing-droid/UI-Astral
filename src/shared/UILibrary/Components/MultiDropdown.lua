return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local HEADER = context.Theme.Dimensions.RowHeight
	local name = config.Name or "Multi Dropdown"
	local options = H.Options(config.Options == nil and {} or config.Options)
	local maxSelections = math.huge
	if config.MaxSelections ~= nil then
		maxSelections = H.Number(config.MaxSelections, nil, "MultiDropdown.MaxSelections")
		if maxSelections < 0 or maxSelections % 1 ~= 0 then
			error("MultiDropdown.MaxSelections must be a nonnegative integer", 2)
		end
	end
	local callback = H.Callback(config.Callback)
	local searchable = config.Searchable and true or false
	local expanded = false
	local function normalizeValues(values)
		local unique = H.Options(values == nil and {} or values)
		local result = {}
		for _, value in ipairs(unique) do
			if #result >= maxSelections then
				break
			end
			for _, option in ipairs(options) do
				if option == value then
					table.insert(result, option)
					break
				end
			end
		end
		return result
	end
	local selected = normalizeValues(config.Default)

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
		Size = UDim2.new(1, -140, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local valueLabel = H.Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.5, 0),
		Size = UDim2.new(0, 130, 0, 16),
		BackgroundTransparency = 1,
		Text = "None",
		TextSize = 12,
		TextColor3 = C.SubText,
		Font = fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
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
	local listFrame = H.Make("Frame", {
		Name = "List",
		Position = UDim2.new(0, 0, 0, HEADER),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = row,
	})
	local listTop = 4
	local searchBox
	if searchable then
		searchBox = H.Make("TextBox", {
			Name = "Search",
			Position = UDim2.new(0, 8, 0, 4),
			Size = UDim2.new(1, -16, 0, 28),
			BackgroundColor3 = C.Background,
			Text = "",
			PlaceholderText = "Search...",
			PlaceholderColor3 = C.SubText,
			TextSize = 12,
			TextColor3 = C.Text,
			Font = fonts.Regular,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
			Parent = listFrame,
		})
		H.Make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = searchBox })
		H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = searchBox })
		listTop = 36
	end
	local list = H.Make("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.new(0, 8, 0, listTop),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = listFrame,
	})
	H.Make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function isSelected(value)
		for index, item in ipairs(selected) do
			if item == value then
				return index
			end
		end
		return nil
	end
	local function refreshHeader()
		local names = {}
		for index, value in ipairs(selected) do
			names[index] = tostring(value)
		end
		valueLabel.Text = #names == 0 and "None" or table.concat(names, ", ")
	end
	local visibleCount = 0
	local function updateSize()
		local listHeight = math.clamp(visibleCount * 30, 0, 120)
		local extra = listTop + listHeight + 4
		listFrame.Visible = expanded
		listFrame.Size = UDim2.new(1, 0, 0, expanded and extra or 0)
		list.Size = UDim2.new(1, -16, 0, listHeight)
		row.Size = UDim2.new(1, 0, 0, expanded and (HEADER + extra) or HEADER)
	end
	local rebuild
	rebuild = function()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local filterText = string.lower(searchBox and searchBox.Text or "")
		visibleCount = 0
		for index, option in ipairs(options) do
			if filterText == "" or string.find(string.lower(tostring(option)), filterText, 1, true) then
				visibleCount = visibleCount + 1
				local isSel = isSelected(option) ~= nil
				local button = H.Make("TextButton", {
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = isSel and C.Secondary or C.Background,
					BackgroundTransparency = isSel and 0.75 or 0.35,
					Text = (isSel and "✓ " or "") .. tostring(option),
					TextSize = 12,
					TextColor3 = isSel and C.Primary or C.SubText,
					Font = fonts.Medium,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					Parent = list,
				})
				H.Make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = button })
				-- Destroying rebuilt buttons disconnects their own signals.
				button.MouseButton1Click:Connect(function()
					if scope.Destroyed then
						return
					end
					local selectedIndex = isSelected(option)
					if selectedIndex then
						table.remove(selected, selectedIndex)
					elseif #selected < maxSelections then
						table.insert(selected, option)
					else
						return
					end
					refreshHeader()
					rebuild()
					if callback then
						callback(table.clone(selected))
					end
				end)
			end
		end
		updateSize()
	end
	local function setExpanded(open)
		if scope.Destroyed then
			return
		end
		expanded = open and true or false
		chevron.Text = expanded and "▴" or "▾"
		if expanded then
			if searchBox then
				searchBox.Text = ""
			end
			rebuild()
		else
			if searchBox and searchBox:IsFocused() then searchBox:ReleaseFocus(false) end
			updateSize()
		end
	end

	if searchBox then
		scope:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
			if not scope.Destroyed then
				rebuild()
			end
		end)
	end
	scope:Connect(header.MouseButton1Click, function()
		setExpanded(not expanded)
	end)
	refreshHeader()
	rebuild()

	return {
		GetValues = function()
			return table.clone(selected)
		end,
		SetValues = function(values)
			local nextSelected = normalizeValues(values)
			if scope.Destroyed then
				return
			end
			selected = nextSelected
			refreshHeader()
			rebuild()
			if callback then
				callback(table.clone(selected))
			end
		end,
		SetOptions = function(newOptions)
			local nextOptions = H.Options(newOptions == nil and {} or newOptions)
			if scope.Destroyed then
				return
			end
			options = nextOptions
			selected = normalizeValues(selected)
			refreshHeader()
			rebuild()
		end,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		SetExpanded = setExpanded,
		GetExpanded = function()
			return expanded
		end,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
