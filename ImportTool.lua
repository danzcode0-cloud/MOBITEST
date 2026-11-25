-- Import Tool (client-side) - GUI native, tanpa library luar
-- Fitur: multi-ID, file .rbxm/.rbxl, lokasi spawn, hapus script, daftar hasil import

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local player = Players.LocalPlayer

local guiParent = (gethui and gethui()) or CoreGui
pcall(function()
	local old = guiParent:FindFirstChild("ImportTool")
	if old then old:Destroy() end
end)

local imported = {}
local placeMode = "Karakter" -- "Karakter" atau "Kamera"
local stripScripts = true

local gui = Instance.new("ScreenGui")
gui.Name = "ImportTool"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(o, r)
	make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local main = make("Frame", {
	Size = UDim2.new(0, 300, 0, 400),
	Position = UDim2.new(0.5, -150, 0.5, -200),
	BackgroundColor3 = Color3.fromRGB(28, 28, 36),
	BorderSizePixel = 0,
}, gui)
corner(main, 12)

local title = make("TextLabel", {
	Size = UDim2.new(1, -80, 0, 34),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "Import Tool",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local content = make("Frame", {
	Size = UDim2.new(1, 0, 1, -34),
	Position = UDim2.new(0, 0, 0, 34),
	BackgroundTransparency = 1,
}, main)

local minBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -66, 0, 5),
	BackgroundColor3 = Color3.fromRGB(60, 60, 75), Text = "-",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
}, main)
corner(minBtn, 6)
local closeBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -34, 0, 5),
	BackgroundColor3 = Color3.fromRGB(170, 55, 55), Text = "X",
	Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
}, main)
corner(closeBtn, 6)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	content.Visible = not minimized
	main.Size = minimized and UDim2.new(0, 300, 0, 34) or UDim2.new(0, 300, 0, 400)
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- drag (mouse + touch)
local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = i.Position
		startPos = main.Position
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- elemen UI
local function box(placeholder, y)
	local t = make("TextBox", {
		Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, y),
		BackgroundColor3 = Color3.fromRGB(42, 42, 54), Text = "",
		PlaceholderText = placeholder, ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		PlaceholderColor3 = Color3.fromRGB(140, 140, 155),
	}, content)
	corner(t, 6)
	return t
end

local function button(text, x, y, w, color, parent)
	local b = make("TextButton", {
		Size = UDim2.new(w, -12, 0, 30), Position = UDim2.new(x, 10, 0, y),
		BackgroundColor3 = color, Text = text, AutoButtonColor = true,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
	}, parent or content)
	corner(b, 6)
	return b
end

local idBox = box("ID asset (boleh banyak, pisah spasi/koma)", 4)
local importBtn = button("Import ID", 0, 40, 1, Color3.fromRGB(110, 70, 230))
importBtn.Size = UDim2.new(1, -20, 0, 30)

local fileBox = box("Nama file (contoh: model.rbxm)", 76)
local fileBtn = button("Load File", 0, 112, 1, Color3.fromRGB(70, 110, 230))
fileBtn.Size = UDim2.new(1, -20, 0, 30)

local modeBtn = button("Lokasi: Karakter", 0, 148, 0.5, Color3.fromRGB(55, 55, 70))
local scriptBtn = button("Hapus Script: ON", 0.5, 148, 0.5, Color3.fromRGB(55, 55, 70))

local status = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 184),
	BackgroundTransparency = 1, Text = "Siap.", TextWrapped = true,
	Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(190, 190, 205),
	TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -256), Position = UDim2.new(0, 10, 0, 218),
	BackgroundColor3 = Color3.fromRGB(22, 22, 30), BorderSizePixel = 0,
	ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, content)
corner(list, 8)
make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)

local clearBtn = button("Hapus Semua", 0, 0, 1, Color3.fromRGB(170, 55, 55))
clearBtn.Size = UDim2.new(1, -20, 0, 28)
clearBtn.Position = UDim2.new(0, 10, 1, -34)

local function say(msg) status.Text = msg end

-- logika
local function targetCFrame()
	if placeMode == "Kamera" then
		local cam = workspace.CurrentCamera
		return cam.CFrame * CFrame.new(0, 0, -20)
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.CFrame * CFrame.new(0, 0, -14) end
	return workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -20)
end

local function refreshList()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for idx, model in ipairs(imported) do
		local row = make("Frame", {
			Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = Color3.fromRGB(38, 38, 50),
			BorderSizePixel = 0, LayoutOrder = idx,
		}, list)
		corner(row, 6)
		make("TextLabel", {
			Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1, Text = model.Name, TextTruncate = Enum.TextTruncate.AtEnd,
			Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local goBtn = make("TextButton", {
			Size = UDim2.new(0, 52, 0, 22), Position = UDim2.new(1, -112, 0, 4),
			BackgroundColor3 = Color3.fromRGB(70, 110, 230), Text = "Ke sini",
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
		}, row)
		corner(goBtn, 5)
		local delBtn = make("TextButton", {
			Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -56, 0, 4),
			BackgroundColor3 = Color3.fromRGB(170, 55, 55), Text = "Hapus",
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
		}, row)
		corner(delBtn, 5)
		goBtn.MouseButton1Click:Connect(function()
			if model.Parent then pcall(function() model:PivotTo(targetCFrame()) end) end
		end)
		delBtn.MouseButton1Click:Connect(function()
			pcall(function() model:Destroy() end)
			table.remove(imported, table.find(imported, model))
			refreshList()
		end)
	end
end

local function finish(objects, name)
	local container = Instance.new("Model")
	container.Name = name
	for _, o in ipairs(objects) do o.Parent = container end
	if stripScripts then
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then pcall(function() d:Destroy() end) end
		end
	end
	container.Parent = workspace
	pcall(function() container:PivotTo(targetCFrame()) end)
	table.insert(imported, container)
	refreshList()
end

local function loadById(id)
	local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and type(res) == "table" and #res > 0 then return res end
	local ok2, res2 = pcall(function() return InsertService:LoadAsset(id) end)
	if ok2 and res2 then return res2:GetChildren() end
	return nil, tostring(res)
end

local function importIds()
	local count = 0
	for idStr in idBox.Text:gmatch("%d+") do
		count += 1
		local id = tonumber(idStr)
		task.spawn(function()
			say("Memuat " .. id .. "...")
			local objs, err = loadById(id)
			if objs then
				finish(objs, "Asset_" .. id)
				say("Berhasil: " .. id)
			else
				say("Gagal " .. id .. " (bukan Model / privat / dihapus). " .. (err or ""))
			end
		end)
	end
	if count == 0 then say("Isi ID dulu (angka).") end
end

local function loadFile()
	local name = fileBox.Text
	if name == "" then say("Isi nama file dulu.") return end
	if not (isfile and getcustomasset) then
		say("Executor ini tidak mendukung getcustomasset.")
		return
	end
	if not isfile(name) and isfile(name .. ".rbxm") then name = name .. ".rbxm" end
	if not isfile(name) then
		say("File tidak ketemu di folder workspace executor.")
		return
	end
	local ok, res = pcall(function() return game:GetObjects(getcustomasset(name)) end)
	if ok and type(res) == "table" and #res > 0 then
		finish(res, name)
		say("Berhasil load file: " .. name)
	else
		say("Gagal load file: " .. tostring(res))
	end
end

importBtn.MouseButton1Click:Connect(importIds)
fileBtn.MouseButton1Click:Connect(loadFile)
modeBtn.MouseButton1Click:Connect(function()
	placeMode = (placeMode == "Karakter") and "Kamera" or "Karakter"
	modeBtn.Text = "Lokasi: " .. placeMode
end)
scriptBtn.MouseButton1Click:Connect(function()
	stripScripts = not stripScripts
	scriptBtn.Text = "Hapus Script: " .. (stripScripts and "ON" or "OFF")
end)
clearBtn.MouseButton1Click:Connect(function()
	for _, m in ipairs(imported) do pcall(function() m:Destroy() end) end
	table.clear(imported)
	refreshList()
	say("Semua hasil import dihapus.")
end)
