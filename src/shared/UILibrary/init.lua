local RunService = game:GetService("RunService")
local Theme = require(script.Theme)
local Helpers = require(script.Helpers)
local Components = require(script.Components)
local UILibrary = {}

function UILibrary.new(config)
	assert(RunService:IsClient(), "UILibrary must be initialized on the client")
	if config == nil then config = {} end
	assert(type(config) == "table", "Library config must be a table")
	local gui = config.ScreenGui
	assert(typeof(gui) == "Instance" and gui:IsA("ScreenGui"), "ScreenGui is required")
	local theme = Theme.new(config.Theme)
	local H = Helpers.new(theme)
	local context = { Theme = theme, Helpers = H }
	local UI = { Theme = theme, Helpers = H }
	local components = {}
	local holder = H.Make("Frame", {
		Name = "Notifications", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, theme.Dimensions.NotificationWidth, 1, -24),
		BackgroundTransparency = 1, ZIndex = 50, Parent = gui,
	})
	H.Make("UIListLayout", {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = holder,
	})
	local scope = H.Scope(holder)
	scope:Add(function()
		local pending = {}
		for api in pairs(components) do table.insert(pending, api) end
		for _, api in ipairs(pending) do api.Destroy() end
		table.clear(components)
	end)
	scope:Connect(gui.Destroying, function() scope:Destroy() end)

	local function create(kind, parent, settings)
		assert(not scope.Destroyed, "Library is destroyed")
		assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Component parent must be a GuiObject")
		if settings == nil then settings = {} end
		assert(type(settings) == "table", "Component config must be a table")
		H.Callback(settings.Callback)
		if settings.Name ~= nil then assert(type(settings.Name) == "string", "Name must be a string") end
		local order = H.Number(settings.LayoutOrder, 1, "LayoutOrder")
		assert(order % 1 == 0, "LayoutOrder must be an integer")
		-- Build transactionally: malformed config cannot strand partial UI/connections.
		local staging = Instance.new("Frame")
		local ok, result = pcall(function()
			local api = Components[kind](context, staging, settings)
			api._instance.LayoutOrder = order
			return api
		end)
		if not ok then staging:Destroy(); error(result, 3) end
		local api = result
		local componentScope = H.GetScope(api._instance)
		assert(componentScope, "Component factory must own a lifecycle scope")
		components[api] = true
		componentScope:Add(function() components[api] = nil end)
		for name, method in pairs(api) do
			if type(method) == "function" then
				api[name] = function(first, ...)
					if name == "Destroy" and componentScope.Destroyed then return end
					assert(not componentScope.Destroyed, "Component is destroyed")
					if first == api then return method(...) end
					return method(first, ...)
				end
			end
		end
		-- Publish only after ownership is installed: parent observers may destroy UI.
		local published, message = pcall(function()
			api._instance.Parent = parent
			assert(not scope.Destroyed and not componentScope.Destroyed, "Component destroyed during publication")
		end)
		staging:Destroy()
		if not published then api.Destroy(); error(message, 3) end
		return api
	end

	for kind in pairs(Components) do
		if kind ~= "Notification" then
			UI["Create" .. kind] = function(first, second, third)
				if first == UI then return create(kind, second, third) end
				return create(kind, first, second)
			end
		end
	end
	function UI.CreateNotification(first, second)
		if first == UI then return create("Notification", holder, second) end
		return create("Notification", holder, first)
	end
	function UI.Destroy()
		scope:Destroy()
	end
	return UI
end

return UILibrary
