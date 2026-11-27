--==============================================================
-- PERMA TOOLS: REDUPE + ARCHIMEDES  (Delta Executor / Studio Lite)
-- * Header punya tombol ON/OFF dan pilihan mode (REDUPE / ARCHIMEDES)
-- * Ganti mode / OFF  => mode lain otomatis berhenti & dibersihkan
--==============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player     = Players.LocalPlayer

--==============================================================
-- PARENT GUI
--==============================================================
local ENV = _G
pcall(function() if type(getgenv) == "function" then ENV = getgenv() end end)
local gethui
pcall(function() gethui = ENV.gethui end)

local parent
if type(gethui) == "function" then pcall(function() parent = gethui() end) end
if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
if not parent and player then parent = player:WaitForChild("PlayerGui", 10) end
if not parent then return end
pcall(function()
    for _, n in ipairs({ "PERMA_REDUPE_FILL", "PERMA_TOOLS" }) do
        local old = parent:FindFirstChild(n)
        if old then old:Destroy() end
    end
end)

--==============================================================
-- SHARED HELPERS
--==============================================================
local function valid(inst)
    if typeof(inst) ~= "Instance" or not inst.Parent then return false end
    if inst:IsA("Terrain") then return false end
    return inst:IsA("Model") or inst:IsA("BasePart")
end
local function getPivot(inst)
    if inst:IsA("Model") then return inst:GetPivot() end
    return inst.CFrame
end
local function setPivot(inst, cf)
    if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
end
local function sizeOf(inst)
    if inst:IsA("BasePart") then return inst.Size end
    local ok, _, s = pcall(function() return inst:GetBoundingBox() end)
    if ok and s then return s end
    return Vector3.new(4, 4, 4)
end

local WHITE  = Color3.fromRGB(245, 245, 250)
local MUTED  = Color3.fromRGB(165, 190, 220)
local BG     = Color3.fromRGB(8, 14, 25)
local CARD   = Color3.fromRGB(13, 24, 41)
local BTN    = Color3.fromRGB(28, 66, 105)
local ACTIVE = Color3.fromRGB(28, 91, 178)
local GOOD   = Color3.fromRGB(90, 220, 145)
local BAD    = Color3.fromRGB(255, 105, 115)
local INFO   = Color3.fromRGB(95, 205, 255)
local DANGER = Color3.fromRGB(105, 45, 55)

local function new(class, props, par)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
    o.Parent = par
    return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end

local activeTap = nil   -- fungsi(hit) yang dipanggil saat user tap world (hanya dari mode aktif)

--==============================================================
-- MAIN WINDOW
--==============================================================
local gui = new("ScreenGui", {
    Name = "PERMA_TOOLS", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000001
}, parent)

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
local W = math.floor(math.min(262, vp.X - 24))
local H = math.floor(math.min(350, vp.Y - 24))
local posY = math.clamp(70, 4, math.max(4, vp.Y - H - 8))

local main = new("Frame", {
    Name = "Main", Size = UDim2.fromOffset(W, H), Position = UDim2.fromOffset(56, posY),
    BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, ZIndex = 10
}, gui)
corner(main, 14)
new("UIStroke", { Thickness = 1.6, Color = Color3.fromRGB(45, 120, 200), Transparency = 0.3 }, main)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Active = true, ZIndex = 11 }, main)
new("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
    Text = "PERMA TOOLS", TextColor3 = WHITE, TextSize = 11, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12
}, header)

local powerBtn = new("TextButton", {
    Size = UDim2.fromOffset(46, 22), Position = UDim2.new(1, -86, 0, 5), BackgroundColor3 = Color3.fromRGB(22, 120, 70),
    BorderSizePixel = 0, Text = "ON", TextColor3 = WHITE, TextSize = 9, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, ZIndex = 13
}, main)
corner(powerBtn, 7)
local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -34, 0, 5), BackgroundColor3 = BTN,
    BorderSizePixel = 0, Text = "×", TextColor3 = WHITE, TextSize = 14, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, ZIndex = 13
}, main)
corner(closeBtn, 7)

local tabRedupe = new("TextButton", {
    Size = UDim2.new(0.5, -9, 0, 24), Position = UDim2.fromOffset(6, 34), BackgroundColor3 = ACTIVE,
    BorderSizePixel = 0, Text = "REDUPE", TextColor3 = WHITE, TextSize = 9, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, ZIndex = 13
}, main)
corner(tabRedupe, 8)
local tabArch = new("TextButton", {
    Size = UDim2.new(0.5, -9, 0, 24), Position = UDim2.new(0.5, 3, 0, 34), BackgroundColor3 = BTN,
    BorderSizePixel = 0, Text = "ARCHIMEDES", TextColor3 = WHITE, TextSize = 9, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, ZIndex = 13
}, main)
corner(tabArch, 8)

local statusLabel = new("TextLabel", {
    Size = UDim2.new(1, -14, 0, 30), Position = UDim2.new(0, 7, 1, -33), BackgroundTransparency = 1,
    Text = "Pilih mode di atas.", TextColor3 = MUTED, TextSize = 8,
    Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 12
}, main)
local function setStatus(t, c)
    statusLabel.Text = tostring(t)
    statusLabel.TextColor3 = c or MUTED
end

-- Halaman scroll per mode
local function newPage()
    local sc = new("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -98), Position = UDim2.fromOffset(6, 62), BackgroundColor3 = CARD,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(62, 210, 255),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Active = true, Visible = false, ZIndex = 11
    }, main)
    corner(sc, 10)
    new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, sc)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sc)
    local order = 0
    local function row(h)
        order = order + 1
        return new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 12 }, sc)
    end
    return sc, row
end
local function button(par, text, x, w, color, cb)
    local b = new("TextButton", {
        Size = UDim2.new(w, -4, 1, 0), Position = UDim2.new(x, 2, 0, 0), BackgroundColor3 = color or BTN,
        BorderSizePixel = 0, Text = text, TextColor3 = WHITE, TextSize = 8, Font = Enum.Font.GothamBold,
        AutoButtonColor = false, ZIndex = 13
    }, par)
    corner(b, 8)
    if cb then b.Activated:Connect(function() cb(b) end) end
    return b
end
local function inputBox(par, x, w, default, placeholder)
    local t = new("TextBox", {
        Size = UDim2.new(w, -4, 1, 0), Position = UDim2.new(x, 2, 0, 0), BackgroundColor3 = Color3.fromRGB(12, 22, 39),
        BorderSizePixel = 0, Text = default or "", PlaceholderText = placeholder or "", TextColor3 = WHITE,
        PlaceholderColor3 = Color3.fromRGB(130, 157, 192), TextSize = 10, Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = false, ZIndex = 13
    }, par)
    corner(t, 8)
    return t
end
local function textRow(rowFrame, text, size, color)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color or MUTED,
        TextSize = size or 8, Font = Enum.Font.GothamMedium, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13
    }, rowFrame)
end

local Redupe, Arch = {}, {}

--==============================================================
-- MODE 1: REDUPE (A tetap, B = duplikat digeser, ruang di antara diisi)
--==============================================================
do
    local page, row = newPage()
    Redupe.page = page
    local A, B
    local modelMode, autoCount = true, true
    local history = {}
    local ours = setmetatable({}, { __mode = "k" })
    local MAX_CLONES = 500
    local addedConn
    local marks = {}
    local infoLabel, pickA, pickB, countBox

    local function refresh()
        for _, m in ipairs(marks) do pcall(function() m:Destroy() end) end
        marks = {}
        if A and not valid(A) then A = nil end
        if B and not valid(B) then B = nil end
        if A then table.insert(marks, new("SelectionBox", { Adornee = A, Color3 = Color3.fromRGB(80, 220, 255), LineThickness = 0.03, SurfaceTransparency = 1 }, gui)) end
        if B then table.insert(marks, new("SelectionBox", { Adornee = B, Color3 = Color3.fromRGB(90, 255, 140), LineThickness = 0.03, SurfaceTransparency = 1 }, gui)) end
        if infoLabel then
            infoLabel.Text = "A (awal): " .. (A and A.Name or "-") .. "\nB (digeser): " .. (B and B.Name or "-")
        end
    end

    local function watch()
        if addedConn then addedConn:Disconnect(); addedConn = nil end
        if not A then return end
        addedConn = workspace.DescendantAdded:Connect(function(inst)
            if ours[inst] or not A or not A.Parent then return end
            if inst == A or inst.Parent ~= A.Parent then return end
            if inst.ClassName ~= A.ClassName or inst.Name ~= A.Name then return end
            task.defer(function()
                if ours[inst] or not valid(inst) then return end
                B = inst
                refresh()
                setStatus("Duplikat terdeteksi (hijau). Geser/miringkan, lalu FILL.", GOOD)
            end)
        end)
    end

    local function disarm()
        activeTap = nil
        if pickA then pickA.BackgroundColor3 = BTN end
        if pickB then pickB.BackgroundColor3 = BTN end
    end

    local function arm(which, btn)
        disarm()
        btn.BackgroundColor3 = ACTIVE
        setStatus(which == "A" and "Tap part AWAL (A) di world." or "Tap part DUPLIKAT (B) di world.", INFO)
        activeTap = function(hit)
            local target = hit.Instance
            if modelMode then
                while target.Parent and target.Parent ~= workspace and target.Parent:IsA("Model") do target = target.Parent end
            end
            if not valid(target) then setStatus("Objek ini tidak bisa dipilih.", BAD) return end
            if which == "A" then
                A = target; B = nil
                watch()
                setStatus("A dipilih. Tekan Dupli di Studio Lite, lalu geser duplikatnya.", GOOD)
            else
                B = target
                setStatus("B dipilih. Atur posisi/miring B, lalu FILL.", GOOD)
            end
            disarm()
            refresh()
        end
    end

    local r0 = row(28)
    infoLabel = textRow(r0, "A (awal): -\nB (digeser): -", 9, WHITE)

    local r1 = row(28)
    pickA = button(r1, "PICK A", 0, 0.28, BTN, function(b) arm("A", b) end)
    pickB = button(r1, "PICK B", 0.28, 0.28, BTN, function(b) arm("B", b) end)
    button(r1, "MODEL", 0.56, 0.22, ACTIVE, function(b)
        modelMode = not modelMode
        b.Text = modelMode and "MODEL" or "PART"
        b.BackgroundColor3 = modelMode and ACTIVE or BTN
    end)
    button(r1, "SEL", 0.78, 0.22, BTN, function()
        local ok, list = pcall(function() return game:GetService("Selection"):Get() end)
        if not ok or type(list) ~= "table" or #list == 0 then
            setStatus("Seleksi bawaan tidak bisa dibaca. Pakai PICK A / PICK B.", BAD)
            return
        end
        local first, second
        for _, inst in ipairs(list) do
            if valid(inst) then
                if not first then first = inst elseif not second then second = inst end
            end
        end
        if not first then setStatus("Seleksi tidak valid.", BAD) return end
        A = first; B = second
        refresh(); watch()
        setStatus(B and "A dan B diambil dari seleksi." or "A diambil dari seleksi. Duplikat lalu geser.", GOOD)
    end)

    local r2 = row(28)
    countBox = inputBox(r2, 0, 0.35, "3", "jumlah")
    button(r2, "AUTO ISI: ON", 0.35, 0.65, ACTIVE, function(b)
        autoCount = not autoCount
        b.Text = autoCount and "AUTO ISI: ON" or "AUTO ISI: OFF"
        b.BackgroundColor3 = autoCount and ACTIVE or BTN
    end)

    local function autoN()
        local pa, pb = getPivot(A), getPivot(B)
        local d = (pa:Inverse() * pb).Position
        local dist = d.Magnitude
        if dist < 0.001 then return 0 end
        local u = d / dist
        local s = sizeOf(A)
        local m = math.max(
            math.abs(u.X) / math.max(s.X, 0.001),
            math.abs(u.Y) / math.max(s.Y, 0.001),
            math.abs(u.Z) / math.max(s.Z, 0.001))
        return math.max(0, math.floor(dist * m + 0.5) - 1)
    end

    local function makeClone(pivot, sizeT)
        local c = A:Clone()
        if not c then return nil end
        ours[c] = true
        if sizeT and c:IsA("BasePart") and B and B:IsA("BasePart") then
            local s = A.Size:Lerp(B.Size, sizeT)
            c.Size = Vector3.new(math.max(s.X, 0.05), math.max(s.Y, 0.05), math.max(s.Z, 0.05))
        end
        setPivot(c, pivot)
        c.Parent = A.Parent
        return c
    end

    local function ready()
        if not A or not valid(A) then setStatus("Pilih part awal (A) dulu.", BAD) return false end
        if not B or not valid(B) then setStatus("Belum ada duplikat (B). Tekan Dupli di Studio Lite lalu geser, atau PICK B.", BAD) return false end
        return true
    end

    local function fill()
        if not ready() then return end
        local n = autoCount and autoN() or math.floor(tonumber(countBox.Text) or 0)
        n = math.clamp(n, 0, MAX_CLONES)
        if autoCount then countBox.Text = tostring(n) end
        if n == 0 then setStatus("Tidak ada ruang untuk diisi (A dan B terlalu dekat).", BAD) return end
        local pa, pb = getPivot(A), getPivot(B)
        local made = {}
        for i = 1, n do
            local c = makeClone(pa:Lerp(pb, i / (n + 1)), i / (n + 1))
            if c then table.insert(made, c) end
        end
        if #made == 0 then setStatus("Part tidak bisa di-clone.", BAD) return end
        table.insert(history, made)
        setStatus(#made .. " part mengisi antara A dan B.", GOOD)
    end

    local function extend()
        if not ready() then return end
        local n = math.clamp(math.floor(tonumber(countBox.Text) or 1), 1, MAX_CLONES)
        local pa, pb = getPivot(A), getPivot(B)
        local d = pa:Inverse() * pb
        local cur = pb
        local made = {}
        for i = 1, n do
            cur = cur * d
            local c = makeClone(cur, i + 1)
            if c then table.insert(made, c) end
        end
        if #made == 0 then setStatus("Part tidak bisa di-clone.", BAD) return end
        table.insert(history, made)
        setStatus(#made .. " part ditambah melewati B.", GOOD)
    end

    local function undo()
        local last = table.remove(history)
        if not last then setStatus("Tidak ada yang bisa di-undo.", MUTED) return end
        for _, c in ipairs(last) do pcall(function() c:Destroy() end) end
        setStatus("Undo: " .. #last .. " part dihapus.", INFO)
    end

    local r3 = row(34)
    button(r3, "FILL ANTARA A–B", 0, 1, ACTIVE, function()
        local ok, err = pcall(fill)
        if not ok then setStatus("Error: " .. tostring(err):sub(1, 90), BAD) end
    end)
    local r4 = row(28)
    button(r4, "EXTEND →", 0, 0.5, BTN, function()
        local ok, err = pcall(extend)
        if not ok then setStatus("Error: " .. tostring(err):sub(1, 90), BAD) end
    end)
    button(r4, "UNDO", 0.5, 0.5, DANGER, undo)
    local r5 = row(64)
    textRow(r5, "Cara: PICK A → tekan Dupli di Studio Lite → geser & miringkan duplikat (hijau) → FILL. EXTEND melanjutkan pola melewati B memakai jumlah.", 8)

    function Redupe.start()
        refresh()
        if A then watch() end
        setStatus("REDUPE aktif. PICK A untuk mulai.", INFO)
    end
    function Redupe.stop()
        disarm()
        if addedConn then addedConn:Disconnect(); addedConn = nil end
        A, B = nil, nil
        history = {}
        refresh()
    end
end

--==============================================================
-- MODE 2: ARCHIMEDES (kurva dari titik kontrol -> part berderet)
--==============================================================
do
    local page, row = newPage()
    Arch.page = page
    local ctype = "ARC"
    local need = { LINE = 2, ARC = 3, BEZIER = 4, CIRCLE = 2, SPIRAL = 2 }
    local minSeg = { LINE = 1, ARC = 2, BEZIER = 2, CIRCLE = 3, SPIRAL = 4 }
    local points = {}
    local adorns = {}
    local template = nil
    local results = {}
    local typeButtons = {}
    local infoLabel, addBtn, tmplBtn, segBox, thickBox, turnsBox, riseBox

    local function toAdorneeCF(pos)
        local terrain = workspace.Terrain
        return terrain.CFrame:Inverse() * CFrame.new(pos)
    end
    local function dot(pos, radius, color)
        return new("SphereHandleAdornment", {
            Adornee = workspace.Terrain, CFrame = toAdorneeCF(pos), Radius = radius, Color3 = color,
            AlwaysOnTop = true, ZIndex = 1, Transparency = 0.15
        }, gui)
    end

    local function sample(seg)
        local P, out = points, {}
        local ct = ctype
        local turns = math.max(0.1, tonumber(turnsBox.Text) or 3)
        local rise = tonumber(riseBox.Text) or 0
        for i = 0, seg do
            local t = i / seg
            local p
            if ct == "LINE" then
                p = P[1]:Lerp(P[2], t)
            elseif ct == "ARC" then
                local u = 1 - t
                p = P[1] * (u * u) + P[2] * (2 * u * t) + P[3] * (t * t)
            elseif ct == "BEZIER" then
                local u = 1 - t
                p = P[1] * (u * u * u) + P[2] * (3 * u * u * t) + P[3] * (3 * u * t * t) + P[4] * (t * t * t)
            elseif ct == "CIRCLE" then
                local c = P[1]
                local d = P[2] - c
                local r = Vector3.new(d.X, 0, d.Z).Magnitude
                local a = math.atan2(d.Z, d.X) + 2 * math.pi * t
                p = Vector3.new(c.X + r * math.cos(a), c.Y, c.Z + r * math.sin(a))
            else -- SPIRAL (Archimedes: r tumbuh linear terhadap sudut)
                local c = P[1]
                local d = P[2] - c
                local r = Vector3.new(d.X, 0, d.Z).Magnitude
                local a = math.atan2(d.Z, d.X) + 2 * math.pi * turns * t
                p = Vector3.new(c.X + r * t * math.cos(a), c.Y + rise * t, c.Z + r * t * math.sin(a))
            end
            out[i + 1] = p
        end
        return out
    end

    local function getSeg()
        local seg = math.floor(tonumber(segBox.Text) or 16)
        return math.clamp(seg, minSeg[ctype], 300)
    end

    local function refreshPreview()
        for _, a in ipairs(adorns) do pcall(function() a:Destroy() end) end
        adorns = {}
        for _, p in ipairs(points) do
            table.insert(adorns, dot(p, 0.7, Color3.fromRGB(255, 90, 220)))
        end
        if #points >= need[ctype] then
            local ok, pts = pcall(sample, getSeg())
            if ok then
                for _, p in ipairs(pts) do table.insert(adorns, dot(p, 0.3, Color3.fromRGB(80, 220, 255))) end
            end
        end
        infoLabel.Text = "TIPE: " .. ctype .. "   TITIK: " .. #points .. "/" .. need[ctype]
            .. "\nTEMPLATE: " .. (template and template.Name or "part biasa")
    end

    local function disarm()
        activeTap = nil
        if addBtn then addBtn.BackgroundColor3 = BTN end
        if tmplBtn then tmplBtn.BackgroundColor3 = BTN end
    end

    local function setType(id)
        ctype = id
        points = {}
        disarm()
        for name, b in pairs(typeButtons) do b.BackgroundColor3 = name == id and ACTIVE or BTN end
        refreshPreview()
        setStatus(id .. ": tap " .. need[id] .. " titik di world.", INFO)
    end

    local r0 = row(28)
    infoLabel = textRow(r0, "", 9, WHITE)

    local rt1 = row(26)
    local rt2 = row(26)
    local function typeBtn(rowFrame, id, x, w)
        typeButtons[id] = button(rowFrame, id, x, w, BTN, function() setType(id) end)
    end
    typeBtn(rt1, "LINE", 0, 1 / 3)
    typeBtn(rt1, "ARC", 1 / 3, 1 / 3)
    typeBtn(rt1, "BEZIER", 2 / 3, 1 / 3)
    typeBtn(rt2, "CIRCLE", 0, 0.5)
    typeBtn(rt2, "SPIRAL", 0.5, 0.5)

    local rb1 = row(26)
    segBox = inputBox(rb1, 0, 0.5, "16", "segmen")
    thickBox = inputBox(rb1, 0.5, 0.5, "1", "tebal")
    local rb2 = row(26)
    turnsBox = inputBox(rb2, 0, 0.5, "3", "putaran")
    riseBox = inputBox(rb2, 0.5, 0.5, "0", "naik")
    for _, b in ipairs({ segBox, thickBox, turnsBox, riseBox }) do
        b.FocusLost:Connect(function() refreshPreview() end)
    end
    local rl = row(12)
    textRow(rl, "segmen • tebal • putaran spiral • naik spiral (studs)", 7)

    local function addPoint(pos)
        table.insert(points, pos)
        if #points >= need[ctype] then
            disarm()
            setStatus("Titik lengkap. Tekan BUILD, atau ADD untuk ulang.", GOOD)
        else
            setStatus("Titik " .. #points .. "/" .. need[ctype] .. ". Tap titik berikutnya.", INFO)
        end
        refreshPreview()
    end

    local r3 = row(28)
    addBtn = button(r3, "ADD TITIK", 0, 0.4, BTN, function(b)
        if activeTap then disarm() return end
        if #points >= need[ctype] then points = {}; refreshPreview() end
        b.BackgroundColor3 = ACTIVE
        setStatus("Tap permukaan di world untuk menaruh titik.", INFO)
        activeTap = function(hit) addPoint(hit.Position) end
    end)
    button(r3, "UNDO TITIK", 0.4, 0.35, BTN, function()
        table.remove(points)
        refreshPreview()
    end)
    button(r3, "CLEAR", 0.75, 0.25, DANGER, function()
        points = {}
        disarm()
        refreshPreview()
    end)

    local r4 = row(26)
    tmplBtn = button(r4, "TEMPLATE: TAP PART", 0, 1, BTN, function(b)
        if template then
            template = nil
            refreshPreview()
            setStatus("Template dilepas, memakai part biasa.", MUTED)
            return
        end
        disarm()
        b.BackgroundColor3 = ACTIVE
        setStatus("Tap part yang jadi template segmen.", INFO)
        activeTap = function(hit)
            local t = hit.Instance
            if t:IsA("BasePart") and not t:IsA("Terrain") then
                template = t
                setStatus("Template: " .. t.Name, GOOD)
            else
                setStatus("Template harus Part.", BAD)
            end
            disarm()
            refreshPreview()
        end
    end)

    local function build()
        if #points < need[ctype] then setStatus("Titik belum lengkap (" .. #points .. "/" .. need[ctype] .. ").", BAD) return end
        local seg = getSeg()
        local thick = math.max(0.05, tonumber(thickBox.Text) or 1)
        local pts = sample(seg)
        local model = Instance.new("Model")
        model.Name = "Archimedes_" .. (#results + 1)
        local made = 0
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            local d = b - a
            local len = d.Magnitude
            if len > 0.001 then
                local up = Vector3.new(0, 1, 0)
                if math.abs(d.Unit:Dot(up)) > 0.99 then up = Vector3.new(1, 0, 0) end
                local cf = CFrame.lookAt((a + b) / 2, b, up)
                local p
                if template and template.Parent then
                    p = template:Clone()
                end
                if p then
                    p.Size = Vector3.new(template.Size.X, template.Size.Y, len * 1.02)
                else
                    p = Instance.new("Part")
                    p.Size = Vector3.new(thick, thick, len * 1.02)
                    p.Color = Color3.fromRGB(163, 162, 165)
                end
                p.Anchored = true
                p.CFrame = cf
                p.Name = "Seg" .. i
                pcall(function()
                    p:SetAttribute("SL_Anchored", true)
                    p:SetAttribute("SL_CanCollide", p.CanCollide)
                end)
                p.Parent = model
                made = made + 1
            end
        end
        if made == 0 then model:Destroy() setStatus("Kurva terlalu pendek.", BAD) return end
        model.Parent = workspace
        table.insert(results, model)
        setStatus(made .. " segmen dibuat (" .. model.Name .. ").", GOOD)
    end

    local r5 = row(34)
    button(r5, "BUILD KURVA", 0, 0.65, ACTIVE, function()
        local ok, err = pcall(build)
        if not ok then setStatus("Error: " .. tostring(err):sub(1, 90), BAD) end
    end)
    button(r5, "UNDO", 0.65, 0.35, DANGER, function()
        local last = table.remove(results)
        if not last then setStatus("Tidak ada yang bisa di-undo.", MUTED) return end
        pcall(function() last:Destroy() end)
        setStatus("Undo: " .. last.Name .. " dihapus.", INFO)
    end)
    local r6 = row(80)
    textRow(r6, "LINE 2 titik • ARC 3 titik (titik tengah = kontrol) • BEZIER 4 titik • CIRCLE: pusat + titik tepi (datar) • SPIRAL: pusat + titik tepi, atur putaran & naik. Tebal dipakai kalau tanpa template.", 8)

    function Arch.start()
        for name, b in pairs(typeButtons) do b.BackgroundColor3 = name == ctype and ACTIVE or BTN end
        refreshPreview()
        setStatus("ARCHIMEDES aktif. ADD TITIK untuk mulai.", INFO)
    end
    function Arch.stop()
        disarm()
        points = {}
        template = nil
        results = {}
        refreshPreview()
    end
end

--==============================================================
-- MODE MANAGER + ON/OFF
--==============================================================
local modes = { REDUPE = Redupe, ARCHIMEDES = Arch }
local activeName = "REDUPE"
local enabled = true

local function applyMode()
    activeTap = nil
    for name, m in pairs(modes) do
        if not (enabled and name == activeName) then pcall(m.stop) end
    end
    for name, m in pairs(modes) do
        m.page.Visible = enabled and name == activeName
    end
    tabRedupe.BackgroundColor3 = (activeName == "REDUPE") and ACTIVE or BTN
    tabArch.BackgroundColor3 = (activeName == "ARCHIMEDES") and ACTIVE or BTN
    powerBtn.Text = enabled and "ON" or "OFF"
    powerBtn.BackgroundColor3 = enabled and Color3.fromRGB(22, 120, 70) or DANGER
    if enabled then
        pcall(modes[activeName].start)
    else
        setStatus("PERMA TOOLS dimatikan. Semua mode berhenti.", MUTED)
    end
end

tabRedupe.Activated:Connect(function()
    if activeName == "REDUPE" and enabled then return end
    activeName = "REDUPE"; enabled = true; applyMode()
end)
tabArch.Activated:Connect(function()
    if activeName == "ARCHIMEDES" and enabled then return end
    activeName = "ARCHIMEDES"; enabled = true; applyMode()
end)
powerBtn.Activated:Connect(function()
    enabled = not enabled
    applyMode()
end)

--==============================================================
-- TAP-TO-WORLD (satu handler untuk semua mode)
--==============================================================
local function insideMain(pos)
    if not main.Visible then return false end
    local ap, as = main.AbsolutePosition, main.AbsoluteSize
    return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
end

UIS.InputBegan:Connect(function(input, processed)
    if not enabled or not activeTap or processed then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
    local pos
    if t == Enum.UserInputType.Touch then
        local inset = GuiService:GetGuiInset()
        pos = Vector2.new(input.Position.X, input.Position.Y + inset.Y)
    else
        pos = UIS:GetMouseLocation()
    end
    if insideMain(pos) then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local ray = camera:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    if player and player.Character then
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { player.Character }
    end
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if not hit or not hit.Instance then setStatus("Tap tidak mengenai objek.", BAD) return end
    local fn = activeTap
    local ok, err = pcall(fn, hit)
    if not ok then setStatus("Error: " .. tostring(err):sub(1, 90), BAD) end
end)

--==============================================================
-- DRAG + TOGGLE WINDOW
--==============================================================
local function makeDraggable(handle, object)
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = object.Position; dragInput = inp
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then dragInput = inp end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp == dragInput then
            local d = inp.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
makeDraggable(header, main)

local floatBtn = new("TextButton", {
    Size = UDim2.fromOffset(35, 35), Position = UDim2.new(0, 12, 0.5, 30), BackgroundColor3 = BG,
    BorderSizePixel = 0, Text = "🔁", TextSize = 18, Font = Enum.Font.GothamBold, AutoButtonColor = false,
    ZIndex = 100, Active = true
}, gui)
corner(floatBtn, 12)
new("UIStroke", { Thickness = 1.6, Color = Color3.fromRGB(45, 120, 200), Transparency = 0.3 }, floatBtn)
makeDraggable(floatBtn, floatBtn)
floatBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
closeBtn.Activated:Connect(function() main.Visible = false end)

applyMode()
