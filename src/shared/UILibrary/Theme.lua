-- Defaults are copied per library instance; requiring this module creates no UI.
local Theme = {}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

local defaults = {
	Colors = {
		Background = Color3.fromHex("10111A"), Sidebar = Color3.fromHex("151622"),
		Card = Color3.fromHex("1B1C2A"), Primary = Color3.fromHex("A879FF"),
		Secondary = Color3.fromHex("8055D9"), Border = Color3.fromHex("303044"),
		Text = Color3.fromHex("F4F2FA"), SubText = Color3.fromHex("9693A9"),
	},
	Fonts = { Regular = Enum.Font.Gotham, Medium = Enum.Font.GothamMedium, Bold = Enum.Font.GothamBold },
	NotificationColors = {
		Info = Color3.fromHex("8055D9"), Success = Color3.fromHex("6BCB77"),
		Warning = Color3.fromHex("F4B860"), Error = Color3.fromHex("FF6B6B"),
	},
	Dimensions = { RowHeight = 44, CornerRadius = 6, WindowWidth = 650, WindowHeight = 420,
		TopbarHeight = 65, SidebarWidth = 150, NotificationWidth = 260 },
	Assets = { Dragon = "rbxassetid://101879171935546" },
	Window = { ViewportWidth = 740, ViewportHeight = 500, MaxScale = 1, DragThreshold = 6 },
}

function Theme.new(overrides)
	local result = copy(defaults)
	if overrides == nil then return result end
	assert(type(overrides) == "table", "Theme must be a table")
	for group, values in pairs(overrides) do
		assert(type(result[group]) == "table" and type(values) == "table", "Unknown theme group: " .. tostring(group))
		for key, value in pairs(values) do
			local expected = result[group][key]
			assert(expected ~= nil and typeof(value) == typeof(expected), "Invalid theme field: " .. group .. "." .. tostring(key))
			if type(value) == "number" then
				assert(value == value and value > 0 and value < math.huge, "Theme dimensions/constants must be finite and positive")
			elseif typeof(expected) == "EnumItem" then
				assert(value.EnumType == expected.EnumType, "Theme font must be Enum.Font")
			end
			result[group][key] = value
		end
	end
	return result
end

return Theme
