--[[
	Import Tool v6 by zeezee (client-side, GUI native, tanpa library luar)
	Tema biru. Baru v6: pulihkan isi script dari file .rbxm. Juga: auto spawn di atas SpawnLocation, Mode Ringan, proses bertahap. Tab:
	  Cari  : cari Toolbox, hasil lengkap dengan gambar -> klik Import
	  File  : daftar .rbxm / .rbxl / .rbxmx di folder workspace executor -> klik Load
	  ID    : import manual lewat ID (boleh banyak) + pengaturan
	  Hasil : daftar model yang sudah di-import (Ke sini / Hapus)
	  Save  : auto save + Load Save Terakhir (memuat semua model sekaligus, paralel)
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local player = Players.LocalPlayer

local guiParent = (gethui and gethui()) or CoreGui
pcall(function()
	for _, n in ipairs({"ImportToolV3", "ImportToolV4", "ImportToolV5", "ImportToolV6"}) do
		local old = guiParent:FindFirstChild(n)
		if old then old:Destroy() end
	end
end)

-- ========= STATE =========
local imported = {} -- {model, kind("id"/"file"), id, file, name}
local MODES = {"Spawn", "Karakter", "Kamera"}
local placeMode = "Spawn"
local lightMode = true   -- anchor semua part + matikan efek berat
local collide = true     -- model bisa ditabrak
local stripScripts = false -- default: script ikut masuk
local searchPage = 0
local lastKeyword = ""

local SAVE_FILE = "ImportTool_" .. tostring(game.PlaceId) .. ".json"
local canFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
local autoSave = true
local replaceExisting = true
local pauseAuto = false
local lastKey = ""

-- ========= TEMA =========
local C = {
	bg = Color3.fromRGB(13, 17, 28),
	header = Color3.fromRGB(20, 28, 48),
	header2 = Color3.fromRGB(12, 17, 30),
	panel = Color3.fromRGB(15, 20, 33),
	row = Color3.fromRGB(23, 31, 50),
	input = Color3.fromRGB(25, 33, 54),
	accent = Color3.fromRGB(56, 132, 255),
	red = Color3.fromRGB(196, 66, 78),
	green = Color3.fromRGB(40, 150, 105),
	gray = Color3.fromRGB(36, 46, 70),
	stroke = Color3.fromRGB(44, 60, 98),
	text = Color3.fromRGB(240, 246, 255),
	sub = Color3.fromRGB(150, 168, 202),
}

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

local function outline(o, color, thickness)
	make("UIStroke", {
		Color = color or C.stroke, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function pad(o, left)
	make("UIPadding", {PaddingLeft = UDim.new(0, left or 8), PaddingRight = UDim.new(0, 8)}, o)
end

local gui = make("ScreenGui", {Name = "ImportToolV6", ResetOnSpawn = false}, guiParent)

local WIDTH, HEIGHT = 340, 480
local SCALES = {0.65, 0.75, 0.9, 1}
local scaleIdx = 2
local main = make("Frame", {
	Size = UDim2.new(0, WIDTH, 0, HEIGHT),
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0.5, -WIDTH * SCALES[scaleIdx] / 2, 0.5, -HEIGHT * SCALES[scaleIdx] / 2),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 14)
local uiScale = make("UIScale", {Scale = SCALES[scaleIdx]}, main)

-- border dengan gradasi biru yang berputar
local mainStroke = make("UIStroke", {
	Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, main)
local spin = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 50, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 205, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 50, 120)),
	}),
}, mainStroke)

local header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.header, BorderSizePixel = 0,
}, main)
make("UIGradient", {
	Color = ColorSequence.new(C.header, C.header2), Rotation = 90,
}, header)
make("Frame", {
	Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
	BackgroundColor3 = C.accent, BorderSizePixel = 0,
}, header)

local title = make("TextLabel", {
	Size = UDim2.new(1, -140, 0, 22), Position = UDim2.new(0, 14, 0, 4),
	BackgroundTransparency = 1, Text = "Import Tool",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("TextLabel", {
	Size = UDim2.new(1, -140, 0, 14), Position = UDim2.new(0, 14, 0, 25),
	BackgroundTransparency = 1, Text = "v6  -  by zeezee",
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local body = make("Frame", {
	Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 42),
	BackgroundTransparency = 1,
}, main)

local minBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 26), Position = UDim2.new(1, -68, 0, 8),
	BackgroundColor3 = C.gray, Text = "-",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text,
}, header)
corner(minBtn, 7)
local sizeBtn = make("TextButton", {
	Size = UDim2.new(0, 38, 0, 26), Position = UDim2.new(1, -110, 0, 8),
	BackgroundColor3 = C.gray, Text = math.floor(SCALES[scaleIdx] * 100) .. "%",
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text,
}, header)
corner(sizeBtn, 7)
sizeBtn.MouseButton1Click:Connect(function()
	scaleIdx = (scaleIdx % #SCALES) + 1
	uiScale.Scale = SCALES[scaleIdx]
	sizeBtn.Text = math.floor(SCALES[scaleIdx] * 100) .. "%"
end)
local closeBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 26), Position = UDim2.new(1, -36, 0, 8),
	BackgroundColor3 = C.red, Text = "X",
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text,
}, header)
corner(closeBtn, 7)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.new(0, WIDTH, 0, 42) or UDim2.new(0, WIDTH, 0, HEIGHT)
end)

-- drag (mouse + touch)
local dragging, dragStart, startPos
header.InputBegan:Connect(function(i)
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
		local d = (i.Position - dragStart) / uiScale.Scale
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- ========= STATUS BAR (bawah) =========
local statusBox = make("Frame", {
	Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 1, -42),
	BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, body)
corner(statusBox, 8)
outline(statusBox, C.stroke, 1)
local status = make("TextLabel", {
	Size = UDim2.new(1, -84, 1, 0), Position = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1, Text = "Siap.", TextWrapped = true,
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left,
}, statusBox)
local function say(msg) status.Text = tostring(msg) end

-- watermark
make("TextLabel", {
	Size = UDim2.new(0, 68, 1, 0), Position = UDim2.new(1, -74, 0, 0),
	BackgroundTransparency = 1, Text = "by zeezee",
	Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.accent,
	TextXAlignment = Enum.TextXAlignment.Right,
}, statusBox)

-- ========= TAB BAR =========
local tabBar = make("Frame", {
	Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 8),
	BackgroundTransparency = 1,
}, body)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local pages, tabButtons = {}, {}

local function newPage(name)
	local p = make("Frame", {
		Size = UDim2.new(1, -20, 1, -94), Position = UDim2.new(0, 10, 0, 44),
		BackgroundTransparency = 1, Visible = false, Name = name,
	}, body)
	pages[name] = p
	return p
end

local function showPage(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and C.accent or C.gray
		b.TextColor3 = (n == name) and Color3.new(1, 1, 1) or C.sub
	end
end

local function addTab(name, order)
	local b = make("TextButton", {
		Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = C.gray,
		Text = name, Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = C.sub, LayoutOrder = order, AutoButtonColor = false,
	}, tabBar)
	corner(b, 7)
	tabButtons[name] = b
	b.MouseButton1Click:Connect(function() showPage(name) end)
end

local function box(parent, placeholder, pos, size)
	local t = make("TextBox", {
		Size = size, Position = pos, BackgroundColor3 = C.input, Text = "",
		PlaceholderText = placeholder, ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text,
		PlaceholderColor3 = Color3.fromRGB(110, 128, 165),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	corner(t, 8)
	outline(t, C.stroke, 1)
	pad(t, 10)
	return t
end

local function button(parent, text, pos, size, color)
	local b = make("TextButton", {
		Size = size, Position = pos, BackgroundColor3 = color or C.accent,
		Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
	}, parent)
	corner(b, 8)
	return b
end

local function scrollList(parent, pos, size)
	local s = make("ScrollingFrame", {
		Size = size, Position = pos, BackgroundColor3 = C.panel, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	corner(s, 10)
	outline(s, C.stroke, 1)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
		PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
	}, s)
	make("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, s)
	return s
end

local function clearList(list)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

-- baris umum. opts: {thumb = assetId, name, sub, buttons = {{text,color,callback}}}
local function addRow(list, order, opts)
	local hasThumb = opts.thumb ~= nil
	local rowH = hasThumb and 62 or 46
	local row = make("Frame", {
		Size = UDim2.new(1, -4, 0, rowH), BackgroundColor3 = C.row,
		BorderSizePixel = 0, LayoutOrder = order,
	}, list)
	corner(row, 9)
	local textX = 10
	if hasThumb then
		local img = make("ImageLabel", {
			Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 6, 0.5, -25),
			BackgroundColor3 = C.input, BorderSizePixel = 0,
			Image = "rbxthumb://type=Asset&id=" .. tostring(opts.thumb) .. "&w=150&h=150",
			ScaleType = Enum.ScaleType.Crop,
		}, row)
		corner(img, 7)
		textX = 64
	end
	local btnW = #opts.buttons * 58 + 4
	make("TextLabel", {
		Size = UDim2.new(1, -(textX + btnW), 0, 20), Position = UDim2.new(0, textX, 0.5, -19),
		BackgroundTransparency = 1, Text = opts.name, TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	make("TextLabel", {
		Size = UDim2.new(1, -(textX + btnW), 0, 16), Position = UDim2.new(0, textX, 0.5, 2),
		BackgroundTransparency = 1, Text = opts.sub or "", TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	for idx, info in ipairs(opts.buttons) do
		local b = make("TextButton", {
			Size = UDim2.new(0, 54, 0, 28),
			Position = UDim2.new(1, -(#opts.buttons - idx + 1) * 58, 0.5, -14),
			BackgroundColor3 = info.color, Text = info.text,
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
		}, row)
		corner(b, 7)
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

-- ========= PEMULIH ISI SCRIPT (parser file .rbxm biner) =========
-- Tujuan: Source script tidak ikut terbaca saat GetObjects, jadi file dibaca sendiri,
-- teks tiap Script/LocalScript/ModuleScript diambil, lalu ditulis ke script hasil import
-- (butuh executor yang bisa menulis Source: setscriptable / sethiddenproperty).
local byte, char = string.byte, string.char

local function u32le(d, p)
	local a, b, c, e = byte(d, p, p + 3)
	return a + b * 256 + c * 65536 + e * 16777216
end

local function lz4(src)
	local out = {}
	local si, di, n, counter = 1, 0, #src, 0
	while si <= n do
		local token = byte(src, si)
		si += 1
		local lit = token // 16
		if lit == 15 then
			repeat
				local b = byte(src, si)
				si += 1
				lit += b
			until b ~= 255
		end
		for k = 0, lit - 1 do out[di + 1 + k] = byte(src, si + k) end
		si += lit
		di += lit
		counter += lit
		if si > n then break end
		local off = byte(src, si) + byte(src, si + 1) * 256
		si += 2
		local ml = token % 16
		if ml == 15 then
			repeat
				local b = byte(src, si)
				si += 1
				ml += b
			until b ~= 255
		end
		ml += 4
		local pos = di - off
		for k = 1, ml do out[di + k] = out[pos + k] end
		di += ml
		counter += ml
		if counter > 150000 then
			counter = 0
			task.wait()
		end
	end
	return out, di
end

local function bytesToString(t, n)
	local parts = {}
	for i = 1, n, 4000 do
		parts[#parts + 1] = char(table.unpack(t, i, math.min(i + 3999, n)))
	end
	return table.concat(parts)
end

local function readInts(d, p, n)
	local r = {}
	for i = 0, n - 1 do
		local b0, b1, b2, b3 = byte(d, p + i), byte(d, p + n + i), byte(d, p + 2 * n + i), byte(d, p + 3 * n + i)
		local v = b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
		if v % 2 == 0 then v = v // 2 else v = -((v + 1) // 2) end
		r[i + 1] = v
	end
	return r, p + 4 * n
end

local function deltaDecode(arr)
	local acc = 0
	for i = 1, #arr do
		acc += arr[i]
		arr[i] = acc
	end
	return arr
end

-- return info (referent -> {class,name,source,children}), roots (urutan referent tanpa parent)
local function parseRbxm(data)
	if data:sub(1, 8) ~= "<roblox!" then
		return nil, "file bukan .rbxm biner (format XML .rbxmx belum didukung)"
	end
	local classes, info, roots = {}, {}, {}
	local pos, len = 33, #data
	while pos + 15 <= len do
		local name = data:sub(pos, pos + 3)
		local comp = u32le(data, pos + 4)
		local uncomp = u32le(data, pos + 8)
		pos += 16
		local chunk
		if comp == 0 then
			chunk = data:sub(pos, pos + uncomp - 1)
			pos += uncomp
		else
			local t, n = lz4(data:sub(pos, pos + comp - 1))
			chunk = bytesToString(t, n)
			pos += comp
		end
		if name == "INST" then
			local cid = u32le(chunk, 1)
			local nl = u32le(chunk, 5)
			local cname = chunk:sub(9, 8 + nl)
			local p = 9 + nl + 1 -- lewati byte format
			local count = u32le(chunk, p)
			p += 4
			local ids = deltaDecode((readInts(chunk, p, count)))
			classes[cid] = {name = cname, ids = ids}
			for _, id in ipairs(ids) do
				info[id] = {class = cname, name = cname, children = {}}
			end
		elseif name == "PROP" then
			local cid = u32le(chunk, 1)
			local pl = u32le(chunk, 5)
			local pname = chunk:sub(9, 8 + pl)
			local p = 9 + pl
			local ptype = byte(chunk, p)
			p += 1
			if (pname == "Name" or pname == "Source") and ptype == 1 and classes[cid] then
				for _, id in ipairs(classes[cid].ids) do
					local l = u32le(chunk, p)
					local str = chunk:sub(p + 4, p + 3 + l)
					p += 4 + l
					local node = info[id]
					if node then
						if pname == "Name" then node.name = str else node.source = str end
					end
				end
			end
		elseif name == "PRNT" then
			local count = u32le(chunk, 2)
			local p = 6
			local kids, parents
			kids, p = readInts(chunk, p, count)
			parents = readInts(chunk, p, count)
			deltaDecode(kids)
			deltaDecode(parents)
			for i = 1, count do
				local c, par = kids[i], parents[i]
				if par == -1 or not info[par] then
					roots[#roots + 1] = c
				else
					table.insert(info[par].children, c)
				end
			end
		elseif name == "END\0" then
			break
		end
	end
	return info, roots
end

local SCRIPT_CLASSES = {Script = true, LocalScript = true, ModuleScript = true}

local function setSource(inst, src)
	if pcall(function() inst.Source = src end) then return true end
	if setscriptable then
		pcall(setscriptable, inst, "Source", true)
		if pcall(function() inst.Source = src end) then return true end
	end
	if sethiddenproperty and pcall(sethiddenproperty, inst, "Source", src) then return true end
	return false
end

-- tulis ulang Source ke script hasil import. return stats atau nil, pesan
local function restoreSources(objects, data)
	local okParse, info, roots = pcall(parseRbxm, data)
	if not okParse then return nil, "parser gagal: " .. tostring(info) end
	if not info then return nil, roots end

	local function mark(ref)
		local node = info[ref]
		if node.has ~= nil then return node.has end
		local h = node.source ~= nil and SCRIPT_CLASSES[node.class] == true
		for _, c in ipairs(node.children) do
			if mark(c) then h = true end
		end
		node.has = h
		return h
	end

	local stats = {total = 0, ok = 0, fail = 0}
	local function matchTree(ref, inst)
		local node = info[ref]
		if node.source ~= nil and SCRIPT_CLASSES[node.class] and inst:IsA("LuaSourceContainer") then
			stats.total += 1
			if setSource(inst, node.source) then stats.ok += 1 else stats.fail += 1 end
			if stats.total % 40 == 0 then task.wait() end
		end
		local pool = inst:GetChildren()
		local used = {}
		for _, cref in ipairs(node.children) do
			local cn = info[cref]
			for idx, c in ipairs(pool) do
				if not used[idx] and c.Name == cn.name and c.ClassName == cn.class then
					used[idx] = true
					if mark(cref) then matchTree(cref, c) end
					break
				end
			end
		end
	end

	local used = {}
	for _, rref in ipairs(roots) do
		local rn = info[rref]
		for idx, o in ipairs(objects) do
			if not used[idx] and o.Name == rn.name and o.ClassName == rn.class then
				used[idx] = true
				if mark(rref) then matchTree(rref, o) end
				break
			end
		end
	end
	return stats
end

local refreshImported -- forward declaration
local updateSaveInfo -- forward declaration

local function spawnTop()
	local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if sp then return sp.Position + Vector3.new(0, sp.Size.Y / 2, 0) end
	return nil
end

-- taruh model di atas SpawnLocation (alas model tepat di permukaan spawn)
local function placeModel(container, cf)
	if cf then
		container:PivotTo(cf)
		return
	end
	if placeMode == "Spawn" then
		local top = spawnTop()
		if top then
			local bbCF, bbSize = container:GetBoundingBox()
			local pivot = container:GetPivot()
			local off = pivot:ToObjectSpace(bbCF * CFrame.new(0, -bbSize.Y / 2, 0))
			container:PivotTo(CFrame.new(top) * off:Inverse())
			return
		end
	end
	container:PivotTo(targetCFrame())
end

-- proses bertahap supaya game tidak freeze (dijalankan SEBELUM model masuk workspace)
local function processModel(container, quiet)
	local desc = container:GetDescendants()
	local n = #desc
	if not quiet then
		say("Memproses " .. n .. " objek..." .. (n > 5000 and " (besar, harap tunggu)" or ""))
	end
	local toDestroy = {}
	for i, d in ipairs(desc) do
		if stripScripts and d:IsA("LuaSourceContainer") then
			table.insert(toDestroy, d)
		elseif d:IsA("BasePart") then
			if lightMode then
				d.Anchored = true
				d.CastShadow = false
			end
			if not collide then d.CanCollide = false end
		elseif lightMode and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
			or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Light")) then
			d.Enabled = false
		end
		if i % 300 == 0 then task.wait() end
	end
	for i, d in ipairs(toDestroy) do
		pcall(function() d:Destroy() end)
		if i % 300 == 0 then task.wait() end
	end
	return n
end

local function finish(objects, meta, cf)
	local container = Instance.new("Model")
	container.Name = meta.name
	for _, o in ipairs(objects) do o.Parent = container end
	processModel(container, meta.quiet)
	if not stripScripts and meta.raw then
		local stats, perr = restoreSources(objects, meta.raw)
		meta.raw = nil
		if not meta.quiet then
			if not stats then
				say("Isi script tidak dipulihkan: " .. tostring(perr))
			elseif stats.total == 0 then
				say("Tidak ada script di dalam file ini.")
			elseif stats.ok == stats.total then
				say("Isi script dipulihkan: " .. stats.ok .. " script.")
			else
				say("Isi script dipulihkan " .. stats.ok .. " dari " .. stats.total .. ". Sisanya gagal (executor tidak bisa menulis Source).")
			end
		end
	end
	pcall(function() placeModel(container, cf) end)
	container.Parent = workspace
	table.insert(imported, {
		model = container, kind = meta.kind, id = meta.id, file = meta.file, name = meta.name,
	})
	if refreshImported then refreshImported() end
end

local function loadById(id)
	local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and type(res) == "table" and #res > 0 then return res end
	local ok2, res2 = pcall(function() return InsertService:LoadAsset(id) end)
	if ok2 and res2 then return res2:GetChildren() end
	return nil, tostring(res)
end

-- cf dan cb opsional. cb(success)
local function importId(id, label, cf, cb)
	task.spawn(function()
		if not cb then say("Memuat " .. id .. "...") end
		local objs, err = loadById(id)
		if objs then
			finish(objs, {kind = "id", id = id, name = label or ("Asset_" .. id), quiet = cb ~= nil}, cf)
			if not cb then say("Berhasil: " .. (label or id)) end
			if cb then cb(true) end
		else
			if not cb then say("Gagal " .. id .. " (bukan Model / privat / dihapus). " .. (err or "")) end
			if cb then cb(false) end
		end
	end)
end

local function loadFileByName(name, label, cf, cb)
	local function fail(msg)
		if not cb then say(msg) end
		if cb then cb(false) end
	end
	if not (isfile and getcustomasset) then
		fail("Executor ini tidak mendukung getcustomasset.")
		return
	end
	if not isfile(name) then
		fail("File tidak ketemu: " .. name)
		return
	end
	local ok, res = pcall(function() return game:GetObjects(getcustomasset(name)) end)
	if ok and type(res) == "table" and #res > 0 then
		local rawOk, raw = pcall(readfile, name)
		finish(res, {kind = "file", file = name, name = label or name, quiet = cb ~= nil, raw = rawOk and raw or nil}, cf)
		if not cb then say("Berhasil load file: " .. name) end
		if cb then cb(true) end
	else
		fail("Gagal load file: " .. tostring(res))
	end
end

local function clearImported()
	for _, e in ipairs(imported) do
		pcall(function() e.model:Destroy() end)
	end
	table.clear(imported)
	if refreshImported then refreshImported() end
end

-- ========= SAVE / LOAD =========
local function snapshot()
	local items = {}
	for _, e in ipairs(imported) do
		if e.model and e.model.Parent then
			local ok, cf = pcall(function() return e.model:GetPivot() end)
			if ok then
				table.insert(items, {k = e.kind, id = e.id, f = e.file, n = e.name, c = {cf:GetComponents()}})
			end
		end
	end
	return items
end

local function readSave()
	if not canFS then return nil end
	local okExists, exists = pcall(isfile, SAVE_FILE)
	if not okExists or not exists then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
	if ok and type(data) == "table" and type(data.items) == "table" then return data end
	return nil
end

local function saveNow(silent)
	if not canFS then
		if not silent then say("Executor ini tidak mendukung writefile.") end
		return false
	end
	local items = snapshot()
	if #items == 0 then
		if not silent then say("Belum ada model untuk disimpan.") end
		return false
	end
	local key = HttpService:JSONEncode(items)
	if silent and key == lastKey then return true end
	local payload = HttpService:JSONEncode({v = 1, t = os.time(), items = items})
	local ok, err = pcall(writefile, SAVE_FILE, payload)
	if ok then
		lastKey = key
		if updateSaveInfo then updateSaveInfo() end
		if not silent then say("Tersimpan: " .. #items .. " model.") end
		return true
	end
	if not silent then say("Gagal menyimpan: " .. tostring(err)) end
	return false
end

local function loadSave()
	local data = readSave()
	if not data then
		say("Belum ada save (atau file save rusak).")
		return
	end
	local total = #data.items
	if total == 0 then say("Save kosong.") return end
	if replaceExisting then clearImported() end
	pauseAuto = true
	local done, okCount = 0, 0
	say("Memuat 0/" .. total .. "...")
	local function onDone(success)
		done += 1
		if success then okCount += 1 end
		say("Memuat " .. done .. "/" .. total .. "...")
		if done >= total then
			pauseAuto = false
			say("Selesai: " .. okCount .. " dari " .. total .. " model dimuat.")
		end
	end
	for _, it in ipairs(data.items) do
		local cf
		if type(it.c) == "table" and #it.c == 12 then
			local okCf, built = pcall(function() return CFrame.new(unpack(it.c)) end)
			if okCf then cf = built end
		end
		if it.k == "file" and it.f then
			task.spawn(function() loadFileByName(it.f, it.n, cf, onDone) end)
		elseif it.id then
			importId(tonumber(it.id), it.n, cf, onDone)
		else
			onDone(false)
		end
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

local function apiJson(path)
	for _, host in ipairs(HOSTS) do
		local body = httpGet("https://" .. host .. path)
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
	if not data or type(data.data) ~= "table" then
		return nil, "Pencarian gagal (API tidak bisa diakses dari executor)."
	end
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
local searchBox = box(pCari, "Cari di Toolbox (contoh: tree, house)", UDim2.new(0, 0, 0, 0), UDim2.new(1, -72, 0, 32))
local searchBtn = button(pCari, "Cari", UDim2.new(1, -66, 0, 0), UDim2.new(0, 66, 0, 32), C.accent)
local cariList = scrollList(pCari, UDim2.new(0, 0, 0, 38), UDim2.new(1, 0, 1, -76))
local prevBtn = button(pCari, "< Sebelumnya", UDim2.new(0, 0, 1, -32), UDim2.new(0.5, -3, 0, 32), C.gray)
local nextBtn = button(pCari, "Berikutnya >", UDim2.new(0.5, 3, 1, -32), UDim2.new(0.5, -3, 0, 32), C.gray)

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
			addRow(cariList, i, {
				thumb = r.id, name = r.name, sub = "ID " .. r.id .. "  |  " .. r.creator,
				buttons = {{text = "Import", color = C.accent, callback = function() importId(r.id, r.name) end}},
			})
		end
		say(#results .. " hasil. Tekan Import pada model yang kamu mau.")
	end)
end

searchBtn.MouseButton1Click:Connect(function() runSearch(searchBox.Text, 0) end)
searchBox.FocusLost:Connect(function(enter) if enter then runSearch(searchBox.Text, 0) end end)
nextBtn.MouseButton1Click:Connect(function()
	if lastKeyword ~= "" then runSearch(lastKeyword, searchPage + 1) end
end)
prevBtn.MouseButton1Click:Connect(function()
	if lastKeyword ~= "" and searchPage > 0 then runSearch(lastKeyword, searchPage - 1) end
end)

-- ========= PAGE: FILE =========
newPage("File")
local pFile = pages.File
local refreshFileBtn = button(pFile, "Refresh daftar file", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32), C.accent)
local fileList = scrollList(pFile, UDim2.new(0, 0, 0, 38), UDim2.new(1, 0, 1, -38))

local function isModelFile(path)
	local l = path:lower()
	return l:sub(-5) == ".rbxm" or l:sub(-5) == ".rbxl" or l:sub(-6) == ".rbxmx" or l:sub(-6) == ".rbxlx"
end

local function refreshFiles()
	clearList(fileList)
	if not listfiles then
		say("Executor ini tidak mendukung listfiles. Pakai tab ID dan ketik nama file.")
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
			addRow(fileList, count, {
				name = short, sub = path,
				buttons = {{text = "Load", color = C.accent, callback = function() loadFileByName(path) end}},
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
local idBox = box(pId, "ID asset (boleh banyak, pisah spasi/koma)", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32))
local idBtn = button(pId, "Import ID", UDim2.new(0, 0, 0, 38), UDim2.new(1, 0, 0, 32), C.accent)
local fileBox = box(pId, "Nama file (contoh: model.rbxm)", UDim2.new(0, 0, 0, 82), UDim2.new(1, 0, 0, 32))
local fileBtn = button(pId, "Load File", UDim2.new(0, 0, 0, 120), UDim2.new(1, 0, 0, 32), C.accent)
local modeBtn = button(pId, "Lokasi: Spawn", UDim2.new(0, 0, 0, 164), UDim2.new(0.5, -3, 0, 32), C.gray)
local scriptBtn = button(pId, "Hapus Script: OFF", UDim2.new(0.5, 3, 0, 164), UDim2.new(0.5, -3, 0, 32), C.gray)
local lightBtn = button(pId, "Mode Ringan: ON", UDim2.new(0, 0, 0, 202), UDim2.new(0.5, -3, 0, 32), C.green)
local collideBtn = button(pId, "Tabrakan: ON", UDim2.new(0.5, 3, 0, 202), UDim2.new(0.5, -3, 0, 32), C.green)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 240),
	BackgroundTransparency = 1, TextWrapped = true,
	Text = "Lokasi Spawn: model otomatis diletakkan di atas SpawnLocation. Mode Ringan: semua part di-anchor dan partikel/lampu/bayangan dimatikan (jauh lebih ringan untuk model besar). Tabrakan OFF: model hanya pajangan, karakter tembus.",
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, pId)

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 302),
	BackgroundTransparency = 1, TextWrapped = true,
	Text = "Isi script ikut dipulihkan saat Hapus Script OFF dan import lewat FILE .rbxm (butuh setscriptable/sethiddenproperty di executor).",
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.accent,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, pId)

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
	local at = table.find(MODES, placeMode) or 1
	placeMode = MODES[(at % #MODES) + 1]
	modeBtn.Text = "Lokasi: " .. placeMode
	if placeMode == "Spawn" and not spawnTop() then
		say("SpawnLocation tidak ditemukan di map ini, model akan dipasang di depan karakter.")
	end
end)
scriptBtn.MouseButton1Click:Connect(function()
	stripScripts = not stripScripts
	scriptBtn.Text = "Hapus Script: " .. (stripScripts and "ON" or "OFF")
end)

lightBtn.MouseButton1Click:Connect(function()
	lightMode = not lightMode
	lightBtn.Text = "Mode Ringan: " .. (lightMode and "ON" or "OFF")
	lightBtn.BackgroundColor3 = lightMode and C.green or C.gray
end)
collideBtn.MouseButton1Click:Connect(function()
	collide = not collide
	collideBtn.Text = "Tabrakan: " .. (collide and "ON" or "OFF")
	collideBtn.BackgroundColor3 = collide and C.green or C.gray
end)

-- ========= PAGE: HASIL =========
newPage("Hasil")
local pHasil = pages.Hasil
local hasilList = scrollList(pHasil, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, -38))
local clearBtn = button(pHasil, "Hapus Semua", UDim2.new(0, 0, 1, -32), UDim2.new(1, 0, 0, 32), C.red)

refreshImported = function()
	clearList(hasilList)
	for idx, entry in ipairs(imported) do
		local model = entry.model
		addRow(hasilList, idx, {
			thumb = entry.kind == "id" and entry.id or nil,
			name = entry.name,
			sub = model.Parent and "Ada di workspace" or "Sudah dihapus",
			buttons = {
				{text = "Ke sini", color = C.accent, callback = function()
					if model.Parent then pcall(function() model:PivotTo(targetCFrame()) end) end
				end},
				{text = "Hapus", color = C.red, callback = function()
					pcall(function() model:Destroy() end)
					local at = table.find(imported, entry)
					if at then table.remove(imported, at) end
					refreshImported()
				end},
			},
		})
	end
end

clearBtn.MouseButton1Click:Connect(function()
	clearImported()
	say("Semua hasil import dihapus. (File save tidak ikut terhapus.)")
end)

-- ========= PAGE: SAVE =========
newPage("Save")
local pSave = pages.Save

local infoCard = make("Frame", {
	Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.row, BorderSizePixel = 0,
}, pSave)
corner(infoCard, 10)
outline(infoCard, C.stroke, 1)
local infoTitle = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 12, 0, 8),
	BackgroundTransparency = 1, Text = "Save terakhir",
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, infoCard)
local infoText = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 12, 0, 28),
	BackgroundTransparency = 1, Text = "-", TextWrapped = true,
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, infoCard)

local saveBtn = button(pSave, "Simpan Sekarang", UDim2.new(0, 0, 0, 84), UDim2.new(1, 0, 0, 34), C.gray)
local loadBtn = button(pSave, "Load Save Terakhir", UDim2.new(0, 0, 0, 124), UDim2.new(1, 0, 0, 40), C.accent)
loadBtn.TextSize = 14
local autoBtn = button(pSave, "Auto Save: ON", UDim2.new(0, 0, 0, 174), UDim2.new(0.5, -3, 0, 32), C.green)
local replaceBtn = button(pSave, "Ganti yang ada: ON", UDim2.new(0.5, 3, 0, 174), UDim2.new(0.5, -3, 0, 32), C.green)

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 80), Position = UDim2.new(0, 0, 0, 214),
	BackgroundTransparency = 1, TextWrapped = true,
	Text = "Auto Save menyimpan tiap 15 detik kalau ada perubahan. Save kosong tidak pernah menimpa save lama. Load memuat semua model sekaligus (paralel). Save tersimpan di folder workspace executor per game.",
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, pSave)

updateSaveInfo = function()
	if not canFS then
		infoText.Text = "Executor ini tidak mendukung writefile/readfile, jadi save tidak tersedia."
		return
	end
	local data = readSave()
	if not data then
		infoText.Text = "Belum ada save untuk game ini."
		return
	end
	local when = "?"
	pcall(function() when = os.date("%d/%m %H:%M", data.t) end)
	infoText.Text = #data.items .. " model  |  disimpan " .. when .. "\nFile: " .. SAVE_FILE
end

saveBtn.MouseButton1Click:Connect(function() saveNow(false) end)
loadBtn.MouseButton1Click:Connect(loadSave)
autoBtn.MouseButton1Click:Connect(function()
	autoSave = not autoSave
	autoBtn.Text = "Auto Save: " .. (autoSave and "ON" or "OFF")
	autoBtn.BackgroundColor3 = autoSave and C.green or C.gray
end)
replaceBtn.MouseButton1Click:Connect(function()
	replaceExisting = not replaceExisting
	replaceBtn.Text = "Ganti yang ada: " .. (replaceExisting and "ON" or "OFF")
	replaceBtn.BackgroundColor3 = replaceExisting and C.green or C.gray
end)

-- loop auto save
task.spawn(function()
	while gui.Parent do
		task.wait(15)
		if autoSave and not pauseAuto then
			pcall(saveNow, true)
		end
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	if autoSave and not pauseAuto then pcall(saveNow, true) end
	gui:Destroy()
end)

-- animasi border berputar (ringan: hanya mengubah Rotation)
do
	local RunService = game:GetService("RunService")
	local rot = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		rot = (rot + 120 * dt) % 360
		spin.Rotation = rot
	end)
	gui.Destroying:Connect(function() conn:Disconnect() end)
end

-- ========= INIT =========
addTab("Cari", 1)
addTab("File", 2)
addTab("ID", 3)
addTab("Hasil", 4)
addTab("Save", 5)
showPage("Cari")
pcall(refreshFiles)
pcall(updateSaveInfo)
if readSave() then
	say("Ada save tersimpan. Buka tab Save lalu tekan Load Save Terakhir.")
else
	say("Siap. Ketik kata kunci lalu tekan Cari.")
end
