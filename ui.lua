local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.Name = "ZannHub"

local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

-- MAIN FRAME
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 500, 0, 300)
main.Position = UDim2.new(0.5, -250, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(20,20,20)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- TITLE
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,40)
title.Text = "Zann Hub"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220,220,220)
title.Font = Enum.Font.GothamBold
title.TextSize = 16

-- SIDEBAR
local sidebar = Instance.new("Frame", main)
sidebar.Size = UDim2.new(0,140,1,-40)
sidebar.Position = UDim2.new(0,0,0,40)
sidebar.BackgroundColor3 = Color3.fromRGB(25,25,25)
sidebar.BorderSizePixel = 0
Instance.new("UICorner", sidebar)

-- CONTENT
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1,-150,1,-50)
content.Position = UDim2.new(0,150,0,45)
content.BackgroundColor3 = Color3.fromRGB(30,30,30)
content.BorderSizePixel = 0
Instance.new("UICorner", content)

-- FUNCTION BUAT TAB
local tabs = {}

local function createTab(name, order)
	-- button
	local btn = Instance.new("TextButton", sidebar)
	btn.Size = UDim2.new(1,-10,0,35)
	btn.Position = UDim2.new(0,5,0,(order-1)*40)
	btn.Text = name
	btn.BackgroundColor3 = Color3.fromRGB(35,35,35)
	btn.TextColor3 = Color3.fromRGB(200,200,200)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	Instance.new("UICorner", btn)

	-- frame content
	local frame = Instance.new("Frame", content)
	frame.Size = UDim2.new(1,0,1,0)
	frame.BackgroundTransparency = 1
	frame.Visible = false

	tabs[name] = frame

	btn.MouseButton1Click:Connect(function()
		for i,v in pairs(tabs) do
			v.Visible = false
		end
		frame.Visible = true
	end)

	return frame
end

-- BUAT TAB
local infoTab = createTab("Info",1)
local playerTab = createTab("Player",2)
local mainTab = createTab("Main",3)

-- DEFAULT TAB
infoTab.Visible = true

-- ISI TAB INFO
local infoText = Instance.new("TextLabel", infoTab)
infoText.Size = UDim2.new(1,0,0,30)
infoText.Text = "Ini Info Panel"
infoText.BackgroundTransparency = 1
infoText.TextColor3 = Color3.new(1,1,1)

-- ISI TAB MAIN (contoh toggle)
local toggle = Instance.new("TextButton", mainTab)
toggle.Size = UDim2.new(0,150,0,35)
toggle.Position = UDim2.new(0,20,0,20)
toggle.Text = "Toggle: OFF"
toggle.BackgroundColor3 = Color3.fromRGB(40,40,40)
toggle.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", toggle)

local state = false
toggle.MouseButton1Click:Connect(function()
	state = not state
	toggle.Text = "Toggle: " .. (state and "ON" or "OFF")
end)

-- DRAG
local dragging, dragStart, startPos

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
		dragStart = input.Position
		startPos = main.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)