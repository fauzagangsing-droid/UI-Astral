return function(context, parent, config)
	config = config or {}
	local H = context.Helpers
	local C = context.Theme.Colors
	local fonts = context.Theme.Fonts
	local notificationColors = context.Theme.NotificationColors
	local duration = math.max(0, H.Number(config.Duration, 3, "Notification.Duration"))
	local accentColor = notificationColors[config.Type or "Info"] or notificationColors.Info

	local card = H.Make("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		ZIndex = 51,
		Visible = false,
		Parent = parent,
	})
	local scope = H.Scope(card)
	H.Make("UICorner", { CornerRadius = UDim.new(0, context.Theme.Dimensions.CornerRadius), Parent = card })
	H.Make("UIStroke", { Color = C.Border, Thickness = 1, Parent = card })
	local accent = H.Make("Frame", {
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 3, 1, -12),
		BackgroundColor3 = accentColor,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = card,
	})
	H.Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accent })
	local titleLabel = H.Make("TextLabel", {
		Position = UDim2.new(0, 18, 0, 10),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		Text = config.Title or "Notification",
		TextSize = 13,
		TextColor3 = C.Text,
		Font = fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 52,
		Parent = card,
	})
	local contentLabel = H.Make("TextLabel", {
		Position = UDim2.new(0, 18, 0, 30),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		Text = config.Content or "",
		TextSize = 11,
		TextColor3 = C.SubText,
		Font = fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 52,
		Parent = card,
	})

	local shown = false
	local timer, showTween
	scope:Add(function()
		if timer then
			task.cancel(timer)
			timer = nil
		end
		if showTween then
			showTween:Cancel()
			showTween = nil
		end
	end)

	return {
		Show = function()
			if shown or scope.Destroyed then
				return
			end
			shown = true
			card.BackgroundTransparency = 1
			card.Visible = true
			showTween = H.Tween(card, 0.2, { BackgroundTransparency = 0 })
			timer = task.delay(duration, function()
				-- Clear before destroying so cleanup never cancels its own thread.
				timer = nil
				if not scope.Destroyed then
					scope:Destroy()
				end
			end)
		end,
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
		_instance = card,
	}
end
