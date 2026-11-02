return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local UserInputService = game:GetService("UserInputService")
	local name = config.Name or "Keybind"
	local function validateKey(keyCode)
		if typeof(keyCode) ~= "EnumItem" or keyCode.EnumType ~= Enum.KeyCode then
			error("Keybind key must be an Enum.KeyCode", 3)
		end
		return keyCode
	end
	local key = validateKey(config.Default == nil and Enum.KeyCode.Unknown or config.Default)
	local callback = H.Callback(config.Callback)
	local capturing = false
	local captureConnection

	local row = H.CardRow(parent, name, context.Theme.Dimensions.RowHeight)
	local scope = H.Scope(row)
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
		Parent = row,
	})
	local keyButton = H.Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 110, 0, 28),
		BackgroundColor3 = C.Background,
		Text = (key ~= Enum.KeyCode.Unknown) and key.Name or "None",
		TextSize = 12,
		TextColor3 = C.SubText,
		Font = fonts.Medium,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = row,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = keyButton })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = keyButton })

	local function disconnectCapture()
		capturing = false
		if captureConnection then
			captureConnection:Disconnect()
			captureConnection = nil
		end
	end
	scope:Add(disconnectCapture)
	local function stopCapture()
		disconnectCapture()
		if not scope.Destroyed then
			keyButton.Text = (key ~= Enum.KeyCode.Unknown) and key.Name or "None"
			keyButton.TextColor3 = C.SubText
		end
	end

	scope:Connect(keyButton.MouseButton1Click, function()
		if scope.Destroyed then
			return
		end
		if capturing then
			stopCapture()
			return
		end
		capturing = true
		keyButton.Text = "Press a key..."
		keyButton.TextColor3 = C.Primary
		captureConnection = UserInputService.InputBegan:Connect(function(input)
			if not capturing or scope.Destroyed then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					stopCapture()
					return
				end
				if input.KeyCode == Enum.KeyCode.Unknown then
					return
				end
				key = input.KeyCode
				stopCapture()
				if callback then
					callback(key)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				local point = input.Position
				local position, size = keyButton.AbsolutePosition, keyButton.AbsoluteSize
				local inside = point.X >= position.X and point.X <= position.X + size.X
					and point.Y >= position.Y and point.Y <= position.Y + size.Y
				-- A press on the button is handled by its release/click toggle.
				if not inside then stopCapture() end
			end
		end)
	end)

	local function getKey()
		return key
	end
	local function setKey(keyCode)
		keyCode = validateKey(keyCode)
		if scope.Destroyed then
			return
		end
		key = keyCode
		stopCapture()
	end
	return {
		GetKey = getKey,
		SetKey = setKey,
		GetValue = getKey,
		SetValue = setKey,
		SetCallback = function(cb)
			callback = H.Callback(cb)
		end,
		CancelCapture = stopCapture,
		Destroy = function()
			scope:Destroy()
		end,
		_instance = row,
	}
end
