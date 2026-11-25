--[[
	Import Tool v2 (client-side, GUI native, tanpa library luar)
	Tab:
	  1. Cari   : cari Toolbox (Model) -> daftar hasil -> klik Import
	  2. File   : daftar semua .rbxm / .rbxl / .rbxmx di folder workspace executor -> klik Load
	  3. ID     : import manual lewat ID (boleh banyak)
	  4. Hasil  : daftar model yang sudah di-import (Ke sini / Hapus)
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local player = Players.LocalPlayer

local guiParent = (gethui and gethui()) or CoreGui
pcall(function()
	local old = guiParent:FindFirstChild("ImportToolV2")
	if old then old:Destroy() end
end)

-- ========= STATE =========
local imported = {}
local placeMode = "Karakter" -- "Karakter" / "Kamera"
local stripScripts = true
local searchPage = 0
local lastKeyword = ""

-- ========= HELPER UI =========
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(o, r)
	make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local COLORS = {
	bg = Color3.fromRGB(28, 28, 36),
	panel = Color3.fromRGB(22, 22, 30),
	row = Color3.fromRGB(38, 38, 50),
	input = Color3.fromRGB(42, 42, 54),
	purple = Color3.fromRGB(110, 70, 230),
	blue = Color3.fromRGB(70, 110, 230),
	red = Color3.fromRGB(170, 55, 55),
	gray = Color3.fromRGB(55, 55, 70),
	text = Color3.new(1, 1, 1),
	sub = Color3.fromRGB(190, 190, 205),
}

local gui = make("ScreenGui", {Name = "ImportToolV2", ResetOnSpawn = false}, guiParent)

local main = make("Frame", {
	Size = UDim2.new(0, 330, 0, 470),
	Position = UDim2.new(0.5, -165, 0.5, -235),
	BackgroundColor3 = COLORS.bg,
	BorderSizePixel = 0,
}, gui)
corner(main, 12)

local title = make("TextLabel", {
	Size = UDim2.new(1, -80, 0, 34), Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1, Text = "Import Tool v2",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local body = make("Frame", {
	Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34),
	BackgroundTransparency = 1,
}, main)

local minBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -66, 0, 5),
	BackgroundColor3 = Color3.fromRGB(60, 60, 75), Text = "-",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.text,
}, main)
corner(minBtn, 6)
local closeBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -34, 0, 5),
	BackgroundColor3 = COLORS.red, Text = "X",
	Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLORS.text,
}, main)
corner(closeBtn, 6)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.new(0, 330, 0, 34) or UDim2.new(0, 330, 0, 470)
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

-- ========= STATUS BAR (bawah) =========
local status = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -38),
	BackgroundTransparency = 1, Text = "Siap.", TextWrapped = true,
	Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, body)
local function say(msg) status.Text = tostring(msg) end

-- ========= TAB BAR =========
local tabBar = make("Frame", {
	Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
}, body)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local pages, tabButtons = {}, {}

local function newPage(name)
	local p = make("Frame", {
		Size = UDim2.new(1, -20, 1, -76), Position = UDim2.new(0, 10, 0, 34),
		BackgroundTransparency = 1, Visible = false, Name = name,
	}, body)
	pages[name] = p
	return p
end

local function showPage(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and COLORS.purple or COLORS.gray
	end
end

local function addTab(name, order)
	local b = make("TextButton", {
		Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = COLORS.gray,
		Text = name, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = COLORS.text, LayoutOrder = order,
	}, tabBar)
	corner(b, 6)
	tabButtons[name] = b
	b.MouseButton1Click:Connect(function() showPage(name) end)
end

local function box(parent, placeholder, pos, size)
	local t = make("TextBox", {
		Size = size, Position = pos, BackgroundColor3 = COLORS.input, Text = "",
		PlaceholderText = placeholder, ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.text,
		PlaceholderColor3 = Color3.fromRGB(140, 140, 155),
	}, parent)
	corner(t, 6)
	return t
end

local function button(parent, text, pos, size, color)
	local b = make("TextButton", {
		Size = size, Position = pos, BackgroundColor3 = color or COLORS.purple,
		Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = COLORS.text,
	}, parent)
	corner(b, 6)
	return b
end

local function scrollList(parent, pos, size)
	local s = make("ScrollingFrame", {
		Size = size, Position = pos, BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	corner(s, 8)
	make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, s)
	return s
end

local function clearList(list)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

-- baris umum: nama (+ baris kecil), tombol kanan (1 atau 2)
local function addRow(list, order, nameText, subText, buttons)
	local row = make("Frame", {
		Size = UDim2.new(1, -6, 0, 44), BackgroundColor3 = COLORS.row,
		BorderSizePixel = 0, LayoutOrder = order,
	}, list)
	corner(row, 6)
	local width = #buttons * 56 + 8
	make("TextLabel", {
		Size = UDim2.new(1, -width - 8, 0, 22), Position = UDim2.new(0, 8, 0, 3),
		BackgroundTransparency = 1, Text = nameText, TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	make("TextLabel", {
		Size = UDim2.new(1, -width - 8, 0, 16), Position = UDim2.new(0, 8, 0, 24),
		BackgroundTransparency = 1, Text = subText, TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = COLORS.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	for idx, info in ipairs(buttons) do
		local b = make("TextButton", {
			Size = UDim2.new(0, 52, 0, 28),
			Position = UDim2.new(1, -(#buttons - idx + 1) * 56, 0, 8),
			BackgroundColor3 = info.color, Text = info.text,
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = COLORS.text,
		}, row)
		corner(b, 5)
		b.MouseButton1Click:Connect(info.callback)
	end
	return row
end

-- ========= LOGIKA IMPORT =========
local function targetCFrame()
	if placeMode == "Kamera" then
		return workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -20)
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.CFrame * CFrame.new(0, 0, -14) end
	return workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -20)
end

local refreshImported -- forward declaration

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
	if refreshImported then refreshImported() end
end

local function loadById(id)
	local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and type(res) == "table" and #res > 0 then return res end
	local ok2, res2 = pcall(function() return InsertService:LoadAsset(id) end)
	if ok2 and res2 then return res2:GetChildren() end
	return nil, tostring(res)
end

local function importId(id, label)
	task.spawn(function()
		say("Memuat " .. id .. "...")
		local objs, err = loadById(id)
		if objs then
			finish(objs, label or ("Asset_" .. id))
			say("Berhasil: " .. (label or id))
		else
			say("Gagal " .. id .. " (bukan Model / privat / dihapus). " .. (err or ""))
		end
	end)
end

local function loadFileByName(name)
	if not (isfile and getcustomasset) then
		say("Executor ini tidak mendukung getcustomasset.")
		return
	end
	if not isfile(name) then
		say("File tidak ketemu: " .. name)
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

-- ========= HTTP (untuk pencarian Toolbox) =========
local function httpGet(url)
	local req = (syn and syn.request) or request or http_request or (http and http.request) or (fluxus and fluxus.request)
	if req then
		local ok, res = pcall(req, {Url = url, Method = "GET"})
		if ok and type(res) == "table" then
			local code = tonumber(res.StatusCode or res.Status) or 0
			if type(res.Body) == "string" and (code == 0 or (code >= 200 and code < 300)) then
				return res.Body
			end
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" then return body end
	return nil
end

local HOSTS = {"apis.roblox.com", "apis.roproxy.com"}

local function apiJson(pathFmt)
	for _, host in ipairs(HOSTS) do
		local body = httpGet("https://" .. host .. pathFmt)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and type(data) == "table" then return data end
		end
	end
	return nil
end

local function searchToolbox(keyword, page)
	local q = HttpService:UrlEncode(keyword)
	local data = apiJson(("/toolbox-service/v1/marketplace/10?keyword=%s&limit=25&num=25&pageNumber=%d"):format(q, page))
	if not data or type(data.data) ~= "table" then return nil, "Pencarian gagal (API tidak bisa diakses dari executor)." end
	local ids = {}
	for _, item in ipairs(data.data) do
		if item.id then table.insert(ids, item.id) end
	end
	if #ids == 0 then return {}, nil end
	local details = apiJson("/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, ","))
	local byId = {}
	if details and type(details.data) == "table" then
		for _, d in ipairs(details.data) do
			local a = d.asset or {}
			local c = d.creator or {}
			if a.id then byId[a.id] = {name = a.name or "?", creator = c.name or "?"} end
		end
	end
	local results = {}
	for _, id in ipairs(ids) do
		local info = byId[id] or {}
		table.insert(results, {id = id, name = info.name or ("Asset " .. id), creator = info.creator or "?"})
	end
	return results, nil
end

-- ========= PAGE: CARI =========
newPage("Cari")
local pCari = pages.Cari
local searchBox = box(pCari, "Cari di Toolbox (contoh: tree, house)", UDim2.new(0, 0, 0, 0), UDim2.new(1, -70, 0, 30))
local searchBtn = button(pCari, "Cari", UDim2.new(1, -64, 0, 0), UDim2.new(0, 64, 0, 30), COLORS.purple)
local cariList = scrollList(pCari, UDim2.new(0, 0, 0, 36), UDim2.new(1, 0, 1, -72))
local prevBtn = button(pCari, "< Sebelumnya", UDim2.new(0, 0, 1, -30), UDim2.new(0.5, -3, 0, 30), COLORS.gray)
local nextBtn = button(pCari, "Berikutnya >", UDim2.new(0.5, 3, 1, -30), UDim2.new(0.5, -3, 0, 30), COLORS.gray)

local function runSearch(keyword, page)
	if keyword == "" then say("Ketik kata kunci dulu.") return end
	lastKeyword, searchPage = keyword, page
	say("Mencari '" .. keyword .. "' (halaman " .. (page + 1) .. ")...")
	task.spawn(function()
		local results, err = searchToolbox(keyword, page)
		clearList(cariList)
		if not results then say(err) return end
		if #results == 0 then say("Tidak ada hasil untuk '" .. keyword .. "'.") return end
		for i, r in ipairs(results) do
			addRow(cariList, i, r.name, "ID " .. r.id .. "  |  oleh " .. r.creator, {
				{text = "Import", color = COLORS.blue, callback = function() importId(r.id, r.name) end},
			})
		end
		say(#results .. " hasil. Tekan Import pada model yang kamu mau.")
	end)
end

searchBtn.MouseButton1Click:Connect(function() runSearch(searchBox.Text, 0) end)
searchBox.FocusLost:Connect(function(enter) if enter then runSearch(searchBox.Text, 0) end end)
nextBtn.MouseButton1Click:Connect(function() if lastKeyword ~= "" then runSearch(lastKeyword, searchPage + 1) end end)
prevBtn.MouseButton1Click:Connect(function()
	if lastKeyword ~= "" and searchPage > 0 then runSearch(lastKeyword, searchPage - 1) end
end)

-- ========= PAGE: FILE =========
newPage("File")
local pFile = pages.File
local refreshFileBtn = button(pFile, "Refresh daftar file", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 30), COLORS.purple)
local fileList = scrollList(pFile, UDim2.new(0, 0, 0, 36), UDim2.new(1, 0, 1, -36))

local function isModelFile(path)
	local l = path:lower()
	return l:sub(-5) == ".rbxm" or l:sub(-5) == ".rbxl" or l:sub(-6) == ".rbxmx" or l:sub(-6) == ".rbxlx"
end

local function refreshFiles()
	clearList(fileList)
	if not listfiles then
		say("Executor ini tidak mendukung listfiles. Pakai tab ID atau ketik nama file manual.")
		return
	end
	local ok, all = pcall(listfiles, "")
	if not ok or type(all) ~= "table" then
		ok, all = pcall(listfiles, ".")
	end
	if not ok or type(all) ~= "table" then
		say("Gagal membaca folder workspace executor.")
		return
	end
	local count = 0
	for _, path in ipairs(all) do
		if isModelFile(path) then
			count += 1
			local short = path:match("([^/\\]+)$") or path
			addRow(fileList, count, short, path, {
				{text = "Load", color = COLORS.blue, callback = function() loadFileByName(path) end},
			})
		end
	end
	if count == 0 then
		say("Tidak ada file .rbxm/.rbxl di folder workspace executor.")
	else
		say(count .. " file ditemukan. Tekan Load untuk memasukkan.")
	end
end
refreshFileBtn.MouseButton1Click:Connect(refreshFiles)

-- ========= PAGE: ID =========
newPage("ID")
local pId = pages.ID
local idBox = box(pId, "ID asset (boleh banyak, pisah spasi/koma)", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 30))
local idBtn = button(pId, "Import ID", UDim2.new(0, 0, 0, 36), UDim2.new(1, 0, 0, 30), COLORS.purple)
local fileBox = box(pId, "Nama file (contoh: model.rbxm)", UDim2.new(0, 0, 0, 78), UDim2.new(1, 0, 0, 30))
local fileBtn = button(pId, "Load File", UDim2.new(0, 0, 0, 114), UDim2.new(1, 0, 0, 30), COLORS.blue)
local modeBtn = button(pId, "Lokasi: Karakter", UDim2.new(0, 0, 0, 156), UDim2.new(0.5, -3, 0, 30), COLORS.gray)
local scriptBtn = button(pId, "Hapus Script: ON", UDim2.new(0.5, 3, 0, 156), UDim2.new(0.5, -3, 0, 30), COLORS.gray)

idBtn.MouseButton1Click:Connect(function()
	local count = 0
	for idStr in idBox.Text:gmatch("%d+") do
		count += 1
		importId(tonumber(idStr))
	end
	if count == 0 then say("Isi ID dulu (angka).") end
end)
fileBtn.MouseButton1Click:Connect(function()
	local name = fileBox.Text
	if name == "" then say("Isi nama file dulu.") return end
	if isfile and not isfile(name) and isfile(name .. ".rbxm") then name = name .. ".rbxm" end
	loadFileByName(name)
end)
modeBtn.MouseButton1Click:Connect(function()
	placeMode = (placeMode == "Karakter") and "Kamera" or "Karakter"
	modeBtn.Text = "Lokasi: " .. placeMode
end)
scriptBtn.MouseButton1Click:Connect(function()
	stripScripts = not stripScripts
	scriptBtn.Text = "Hapus Script: " .. (stripScripts and "ON" or "OFF")
end)

-- ========= PAGE: HASIL =========
newPage("Hasil")
local pHasil = pages.Hasil
local hasilList = scrollList(pHasil, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, -36))
local clearBtn = button(pHasil, "Hapus Semua", UDim2.new(0, 0, 1, -30), UDim2.new(1, 0, 0, 30), COLORS.red)

refreshImported = function()
	clearList(hasilList)
	for idx, model in ipairs(imported) do
		addRow(hasilList, idx, model.Name, model.Parent and "Ada di workspace" or "Sudah dihapus", {
			{text = "Ke sini", color = COLORS.blue, callback = function()
				if model.Parent then pcall(function() model:PivotTo(targetCFrame()) end) end
			end},
			{text = "Hapus", color = COLORS.red, callback = function()
				pcall(function() model:Destroy() end)
				local at = table.find(imported, model)
				if at then table.remove(imported, at) end
				refreshImported()
			end},
		})
	end
end

clearBtn.MouseButton1Click:Connect(function()
	for _, m in ipairs(imported) do pcall(function() m:Destroy() end) end
	table.clear(imported)
	refreshImported()
	say("Semua hasil import dihapus.")
end)

-- ========= INIT =========
addTab("Cari", 1)
addTab("File", 2)
addTab("ID", 3)
addTab("Hasil", 4)
showPage("Cari")
pcall(refreshFiles)
say("Siap. Ketik kata kunci lalu tekan Cari.")
