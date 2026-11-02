-- Destroy the window explicitly before destroying this script when possible;
-- a script's own Destroying callback is only best-effort with deferred signals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILibrary = require(ReplicatedStorage:WaitForChild("UILibrary"))
local window = UILibrary:CreateWindow()

for _, category in ipairs({
	{ Name = "Home", Icon = "🛖" },
	{ Name = "Combat", Icon = "⚔" },
	{ Name = "Teleport", Icon = "📍" },
	{ Name = "Player", Icon = "" },
	{ Name = "Visuals", Icon = "◎" },
	{ Name = "World", Icon = "◍" },
	{ Name = "Misc", Icon = "☰" },
	{ Name = "Settings", Icon = "⚙" },
}) do
	window:CreateTab(category)
end

local getUI = Instance.new("BindableFunction")
getUI.Name = "GetUI"
getUI.OnInvoke = function()
	return window.UI, window.Pages, window
end
-- The hook scope releases both connections when the getter or GUI is destroyed.
local hooks = window.UI.Helpers.Scope(getUI)
hooks:Connect(window.ScreenGui.Destroying, function() hooks:Destroy() end)
hooks:Connect(script.Destroying, function()
	window:Destroy()
	hooks:Destroy()
end)
getUI.Parent = script
