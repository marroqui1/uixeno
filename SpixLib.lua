--[[
    SpixLib — Roblox UI Library
    Drawing API → Roblox Instances + UIStroke (0.8) rebuild
    Pure library file.  No example code.

    API:
        local lib     = SpixLib.new({ name, size?, accent? })
        local page    = lib:Page({ name })
        local section = page:Section({ name, side? })   -- side = "left"|"right"
        local section = page:Section2({ sections, side?, size? })  -- tabbed twin section
                        → returns up to 3 sub-section handles (unpack)

        section:Label     ({ name, middle? })
        section:Divider   ()
        section:Toggle    ({ name, def?, pointer?, callback? })   → { Get, Set }
        section:Button    ({ name, callback? })
        section:ButtonHolder({ buttons })               -- two side-by-side buttons
        section:Slider    ({ name, min?, max?, def?, suffix?, decimals?, pointer?, callback? }) → { Get, Set }
        section:Dropdown  ({ name, options, def?, pointer?, callback? })                       → { Get, Set }
        section:Multibox  ({ name, options, def?, min?, pointer?, callback? })                 → { Get, Set }
        section:Keybind   ({ name, def?, mode?, pointer?, callback? })                         → { Get, Set }
        section:Colorpicker({ name, def?, transparency?, pointer?, callback? })                → { Get, Set }
        section:ConfigBox ()                                                                    → { Get, Set }

        lib.window:Watermark ({ name? })
        lib.window:KeybindsList ()
        lib.window:Cursor    ()
        lib.window:GetConfig ()  → JSON string
        lib.window:LoadConfig(json)
        lib.window:Unload    ()

    Key Z  = toggle UI visibility (customisable via window.uibind)
--]]

local SpixLib = {}
SpixLib.__index = SpixLib

-- ──────────────────────────────────────────────────────────────────────────────
-- SERVICES
-- ──────────────────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────────────────────────
-- CONSTANTS
-- ──────────────────────────────────────────────────────────────────────────────
local BORDER_THICKNESS = 0.8   -- UIStroke thickness applied everywhere

-- ──────────────────────────────────────────────────────────────────────────────
-- DEFAULT THEME
-- ──────────────────────────────────────────────────────────────────────────────
local DEFAULT_THEME = {
    accent          = Color3.fromRGB(50,  100, 255),
    light_contrast  = Color3.fromRGB(30,   30,  30),
    dark_contrast   = Color3.fromRGB(20,   20,  20),
    outline         = Color3.fromRGB(0,     0,   0),
    inline          = Color3.fromRGB(50,   50,  50),
    textcolor       = Color3.fromRGB(255, 255, 255),
    textborder      = Color3.fromRGB(0,     0,   0),
    font            = Enum.Font.GothamSemibold,
    textsize        = 13,
    -- UIStroke border colour (can be overridden by accent)
    border_color    = Color3.fromRGB(60,   60,  60),
}

-- ──────────────────────────────────────────────────────────────────────────────
-- INTERNAL HELPERS
-- ──────────────────────────────────────────────────────────────────────────────

-- Creates a UIStroke on `instance` with thickness = BORDER_THICKNESS.
local function mkStroke(instance, color)
    local s = Instance.new("UIStroke")
    s.Color           = color or DEFAULT_THEME.border_color
    s.Thickness       = BORDER_THICKNESS
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = instance
    return s
end

local function mkCorner(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 4)
    c.Parent       = instance
    return c
end

local function mkPadding(instance, top, bottom, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top    or 4)
    p.PaddingBottom = UDim.new(0, bottom or 4)
    p.PaddingLeft   = UDim.new(0, left   or 6)
    p.PaddingRight  = UDim.new(0, right  or 6)
    p.Parent        = instance
end

local function mkListLayout(instance, dir, padding, sortOrder)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir       or Enum.FillDirection.Vertical
    l.Padding       = UDim.new(0, padding or 4)
    l.SortOrder     = sortOrder or Enum.SortOrder.LayoutOrder
    l.Parent        = instance
    return l
end

-- Create a basic Frame.
local function mkFrame(parent, color, size, pos, radius)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = color or Color3.fromRGB(20, 20, 20)
    f.BorderSizePixel  = 0
    f.Size             = size or UDim2.new(1,0,0,30)
    f.Position         = pos  or UDim2.new(0,0,0,0)
    f.Parent           = parent
    if radius then mkCorner(f, radius) end
    return f
end

-- Create a TextLabel.
local function mkLabel(parent, text, textsize, color, font, size, pos, xalign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.Font                   = font   or Enum.Font.GothamSemibold
    l.Text                   = text   or ""
    l.TextSize               = textsize or 13
    l.TextColor3             = color  or Color3.fromRGB(255,255,255)
    l.TextXAlignment         = xalign or Enum.TextXAlignment.Left
    l.TextYAlignment         = Enum.TextYAlignment.Center
    l.Size                   = size   or UDim2.new(1,0,1,0)
    l.Position               = pos    or UDim2.new(0,0,0,0)
    l.Parent                 = parent
    return l
end

-- Create a TextButton (transparent background, used as a click target).
local function mkButton(parent, text, textsize, color, font, size, pos)
    local b = Instance.new("TextButton")
    b.BackgroundTransparency = 1
    b.BorderSizePixel        = 0
    b.AutoButtonColor        = false
    b.Font                   = font    or Enum.Font.GothamSemibold
    b.Text                   = text    or ""
    b.TextSize               = textsize or 13
    b.TextColor3             = color   or Color3.fromRGB(255,255,255)
    b.TextXAlignment         = Enum.TextXAlignment.Center
    b.Size                   = size    or UDim2.new(1,0,1,0)
    b.Position               = pos     or UDim2.new(0,0,0,0)
    b.Parent                 = parent
    return b
end

-- Resize a ScrollingFrame so it auto-fits its children.
local function autoCanvas(sf, listLayout)
    local function update()
        sf.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 12)
    end
    listLayout.Changed:Connect(update)
    update()
end

-- Tween helper.
local function tween(instance, props, duration, style, direction)
    local ti = TweenInfo.new(
        duration  or 0.15,
        style     or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    TweenService:Create(instance, ti, props):Play()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- POINTER REGISTRY  (shared, for config save/load)
-- ──────────────────────────────────────────────────────────────────────────────
local _pointers = {}

local function registerPointer(flag, obj)
    if flag and flag ~= "" and not _pointers[flag] then
        _pointers[flag] = obj
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION BUILDER
-- ──────────────────────────────────────────────────────────────────────────────

local Section = {}
Section.__index = Section

-- All elements are added into `section._content` (a ScrollingFrame or Frame).
-- Each builder returns a control object where appropriate.

-- ── Label ────────────────────────────────────────────────────────────────────
function Section:Label(info)
    info = info or {}
    local name   = info.name   or info.title or "Label"
    local middle = info.middle or false

    local row = mkFrame(self._content, Color3.fromRGB(0,0,0), UDim2.new(1,0,0,0), nil, 0)
    row.BackgroundTransparency = 1
    row.AutomaticSize          = Enum.AutomaticSize.Y

    local lbl = mkLabel(row, name,
        self._theme.textsize,
        self._theme.textcolor,
        self._theme.font,
        UDim2.new(1,-12,0,0),
        UDim2.fromOffset(6,4),
        middle and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left)
    lbl.TextWrapped = true
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.TextSize      = self._theme.textsize - 1
    lbl.TextColor3    = Color3.fromRGB(185, 185, 185)
end

-- ── Divider ──────────────────────────────────────────────────────────────────
function Section:Divider()
    local row = mkFrame(self._content, self._theme.inline, UDim2.new(1,-12,0,1), nil, 0)
    row.Position = UDim2.fromOffset(6,0)
end

-- ── Toggle ───────────────────────────────────────────────────────────────────
function Section:Toggle(info)
    info     = info     or {}
    local name     = info.name     or info.title    or "Toggle"
    local def      = info.def      == true
    local pointer  = info.pointer  or info.flag
    local callback = info.callback or function() end

    local val = def

    -- Row container
    local row = mkFrame(self._content,
        self._theme.light_contrast,
        UDim2.new(1,0,0,32), nil, 4)
    mkStroke(row, self._theme.border_color)

    -- Title
    mkLabel(row, name,
        self._theme.textsize,
        self._theme.textcolor,
        self._theme.font,
        UDim2.new(1,-54,1,0),
        UDim2.fromOffset(8,0))

    -- Toggle track
    local track = mkFrame(row,
        val and self._theme.accent or Color3.fromRGB(50,50,50),
        UDim2.fromOffset(36,18),
        UDim2.new(1,-44,0.5,-9), 50)
    mkStroke(track, val and self._theme.accent or self._theme.border_color)

    -- Knob
    local knob = mkFrame(track,
        Color3.fromRGB(240,240,240),
        UDim2.fromOffset(12,12),
        val and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3), 50)

    local obj = {}

    local function Set(v)
        val = v
        tween(track, {BackgroundColor3 = v and self._theme.accent or Color3.fromRGB(50,50,50)})
        local stroke = track:FindFirstChildOfClass("UIStroke")
        if stroke then tween(stroke, {Color = v and self._theme.accent or self._theme.border_color}) end
        tween(knob,  {Position = v and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)}, 0.18)
        callback(v)
    end

    obj.Get = function() return val end
    obj.Set = Set

    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            Set(not val)
        end
    end)

    -- Hover effect
    row.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.dark_contrast}, 0.1)
    end)
    row.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.light_contrast}, 0.1)
    end)

    registerPointer(pointer, obj)
    return obj
end

-- ── Button ───────────────────────────────────────────────────────────────────
function Section:Button(info)
    info     = info     or {}
    local name     = info.name     or info.title or "Button"
    local callback = info.callback or function() end

    local row = mkFrame(self._content,
        self._theme.light_contrast,
        UDim2.new(1,0,0,32), nil, 4)
    mkStroke(row, self._theme.border_color)

    local btn = mkButton(row, name,
        self._theme.textsize,
        self._theme.textcolor,
        self._theme.font,
        UDim2.new(1,0,1,0))

    btn.MouseButton1Click:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.accent}, 0.08)
        task.delay(0.15, function()
            tween(row, {BackgroundColor3 = self._theme.light_contrast}, 0.15)
        end)
        callback()
    end)

    row.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.dark_contrast}, 0.1)
    end)
    row.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.light_contrast}, 0.1)
    end)
end

-- ── ButtonHolder (two side-by-side buttons) ───────────────────────────────────
function Section:ButtonHolder(info)
    info    = info    or {}
    local buttons = info.buttons or {}

    local row = mkFrame(self._content,
        Color3.fromRGB(0,0,0),
        UDim2.new(1,0,0,32), nil, 0)
    row.BackgroundTransparency = 1

    local layout = mkListLayout(row, Enum.FillDirection.Horizontal, 4)

    for i = 1, 2 do
        local bdata = buttons[i]
        if not bdata then break end

        local cell = mkFrame(row,
            self._theme.light_contrast,
            UDim2.new(0.5,-3,1,0), nil, 4)
        mkStroke(cell, self._theme.border_color)

        local btn = mkButton(cell, bdata[1],
            self._theme.textsize,
            self._theme.textcolor,
            self._theme.font,
            UDim2.new(1,0,1,0))

        local cb = bdata[2] or function() end

        btn.MouseButton1Click:Connect(function()
            tween(cell, {BackgroundColor3 = self._theme.accent}, 0.08)
            task.delay(0.15, function()
                tween(cell, {BackgroundColor3 = self._theme.light_contrast}, 0.15)
            end)
            cb()
        end)

        cell.MouseEnter:Connect(function()
            tween(cell, {BackgroundColor3 = self._theme.dark_contrast}, 0.1)
        end)
        cell.MouseLeave:Connect(function()
            tween(cell, {BackgroundColor3 = self._theme.light_contrast}, 0.1)
        end)
    end
end

-- ── Slider ───────────────────────────────────────────────────────────────────
function Section:Slider(info)
    info     = info     or {}
    local name     = info.name     or info.title    or "Slider"
    local minV     = info.min      or 0
    local maxV     = info.max      or 100
    local def      = math.clamp(info.def or minV, minV, maxV)
    local suffix   = info.suffix   or ""
    local decimals = info.decimals or 1
    local pointer  = info.pointer  or info.flag
    local callback = info.callback or function() end
    local val      = def

    local row = mkFrame(self._content,
        self._theme.light_contrast,
        UDim2.new(1,0,0,48), nil, 4)
    mkStroke(row, self._theme.border_color)

    -- Title
    mkLabel(row, name,
        self._theme.textsize,
        self._theme.textcolor,
        self._theme.font,
        UDim2.new(0.6,0,0,18),
        UDim2.fromOffset(8,4))

    -- Value label
    local valLbl = mkLabel(row,
        tostring(def)..suffix,
        self._theme.textsize - 1,
        self._theme.accent,
        self._theme.font,
        UDim2.new(0.38,-8,0,18),
        UDim2.new(0.6,4,0,4),
        Enum.TextXAlignment.Right)

    -- Track bg
    local trackBg = mkFrame(row,
        Color3.fromRGB(35,35,35),
        UDim2.new(1,-16,0,6),
        UDim2.new(0,8,1,-14), 50)
    mkStroke(trackBg, self._theme.border_color)

    -- Filled portion
    local fill = mkFrame(trackBg,
        self._theme.accent,
        UDim2.new((def - minV) / (maxV - minV), 0, 1, 0), nil, 50)

    -- Knob
    local knob = mkFrame(trackBg,
        Color3.fromRGB(240,240,240),
        UDim2.fromOffset(14,14),
        UDim2.new((def - minV) / (maxV - minV), -7, 0.5, -7), 50)
    mkStroke(knob, self._theme.accent)

    local dragging = false

    local function UpdateFromRatio(ratio)
        ratio = math.clamp(ratio, 0, 1)
        local rounded = math.round((minV + (maxV - minV) * ratio) * (1/decimals)) * decimals
        val = math.clamp(rounded, minV, maxV)
        valLbl.Text = tostring(val)..suffix
        tween(fill,  {Size     = UDim2.new(ratio,0,1,0)},       0.05)
        tween(knob,  {Position = UDim2.new(ratio,-7,0.5,-7)},   0.05)
        callback(val)
    end

    trackBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            tween(knob, {Size = UDim2.fromOffset(18,18), Position = UDim2.new(knob.Position.X.Scale,-9,0.5,-9)}, 0.1)
            local ax = trackBg.AbsolutePosition.X
            local aw = trackBg.AbsoluteSize.X
            UpdateFromRatio((i.Position.X - ax) / aw)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tween(knob, {Size = UDim2.fromOffset(14,14)}, 0.1)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local ax = trackBg.AbsolutePosition.X
            local aw = trackBg.AbsoluteSize.X
            UpdateFromRatio((i.Position.X - ax) / aw)
        end
    end)

    row.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.dark_contrast}, 0.1)
    end)
    row.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = self._theme.light_contrast}, 0.1)
    end)

    local obj = {
        Get = function() return val end,
        Set = function(_, v)
            v = math.clamp(v, minV, maxV)
            UpdateFromRatio((v - minV) / (maxV - minV))
        end,
    }
    registerPointer(pointer, obj)
    return obj
end

-- ── Dropdown ─────────────────────────────────────────────────────────────────
function Section:Dropdown(info)
    info     = info     or {}
    local name     = info.name     or info.title    or "Dropdown"
    local options  = info.options  or {}
    local def      = info.def      or options[1]    or ""
    local pointer  = info.pointer  or info.flag
    local callback = info.callback or function() end
    local sel      = tostring(def)
    local isOpen   = false

    local theme = self._theme

    -- Row
    local row = mkFrame(self._content,
        theme.light_contrast, UDim2.new(1,0,0,54), nil, 4)
    mkStroke(row, theme.border_color)

    mkLabel(row, name,
        theme.textsize, theme.textcolor, theme.font,
        UDim2.new(1,-16,0,18), UDim2.fromOffset(8,4))

    -- Display box
    local displayBox = mkFrame(row,
        theme.dark_contrast,
        UDim2.new(1,-16,0,22),
        UDim2.new(0,8,1,-28), 4)
    mkStroke(displayBox, theme.border_color)

    local dispLbl = mkLabel(displayBox, sel,
        theme.textsize - 1, theme.textcolor, theme.font,
        UDim2.new(1,-22,1,0), UDim2.fromOffset(6,0))

    local arrowLbl = mkLabel(displayBox, "▾",
        theme.textsize, theme.textcolor, theme.font,
        UDim2.fromOffset(16,22),
        UDim2.new(1,-18,0,0),
        Enum.TextXAlignment.Center)

    -- Dropdown panel (laid over everything)
    local panel  = mkFrame(self._content:FindFirstAncestorOfClass("ScreenGui") or row,
        theme.dark_contrast, UDim2.fromOffset(10,0), nil, 4)
    panel.Visible = false
    panel.ZIndex  = 100
    mkStroke(panel, theme.accent)

    local pList = mkListLayout(panel, Enum.FillDirection.Vertical, 2)
    mkPadding(panel, 3, 3, 4, 4)

    local optionBtns = {}

    local function RebuildPanel()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        optionBtns = {}
        for _, opt in ipairs(options) do
            local oRow = mkFrame(panel,
                opt == sel and theme.light_contrast or theme.dark_contrast,
                UDim2.new(1,0,0,22), nil, 4)
            oRow.ZIndex = 101
            mkStroke(oRow, opt == sel and theme.accent or theme.border_color)

            local oLbl = mkLabel(oRow, tostring(opt),
                theme.textsize - 1,
                opt == sel and theme.accent or theme.textcolor,
                theme.font,
                UDim2.new(1,-8,1,0),
                UDim2.fromOffset(6,0))
            oLbl.ZIndex = 102

            oRow.MouseEnter:Connect(function()
                if opt ~= sel then
                    tween(oRow, {BackgroundColor3 = theme.light_contrast}, 0.08)
                end
            end)
            oRow.MouseLeave:Connect(function()
                if opt ~= sel then
                    tween(oRow, {BackgroundColor3 = theme.dark_contrast}, 0.08)
                end
            end)
            oRow.InputBegan:Connect(function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                sel = tostring(opt)
                dispLbl.Text = sel
                isOpen = false
                tween(panel, {Size = UDim2.fromOffset(panel.AbsoluteSize.X, 0)}, 0.15)
                tween(arrowLbl, {Rotation = 0}, 0.15)
                task.delay(0.15, function() panel.Visible = false end)
                callback(sel)
                RebuildPanel()
            end)
            table.insert(optionBtns, oRow)
        end
    end
    RebuildPanel()

    local function OpenPanel()
        local absPos = displayBox.AbsolutePosition
        local absW   = displayBox.AbsoluteSize.X
        local h      = math.min(#options * 26 + 10, 220)
        panel.Position = UDim2.fromOffset(absPos.X, absPos.Y + displayBox.AbsoluteSize.Y + 3)
        panel.Size     = UDim2.fromOffset(absW, 0)
        panel.Visible  = true
        tween(panel, {Size = UDim2.fromOffset(absW, h)}, 0.18)
        tween(arrowLbl, {Rotation = 180}, 0.18)
    end

    displayBox.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        isOpen = not isOpen
        if isOpen then OpenPanel()
        else
            tween(panel, {Size = UDim2.fromOffset(panel.AbsoluteSize.X, 0)}, 0.15)
            tween(arrowLbl, {Rotation = 0}, 0.15)
            task.delay(0.15, function() panel.Visible = false end)
        end
    end)

    UserInputService.InputBegan:Connect(function(i)
        if not isOpen or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local m = UserInputService:GetMouseLocation()
        local a = panel.AbsolutePosition; local s = panel.AbsoluteSize
        if not (m.X >= a.X and m.X <= a.X+s.X and m.Y >= a.Y and m.Y <= a.Y+s.Y) then
            isOpen = false
            tween(panel, {Size = UDim2.fromOffset(s.X, 0)}, 0.15)
            tween(arrowLbl, {Rotation = 0}, 0.15)
            task.delay(0.15, function() panel.Visible = false end)
        end
    end)

    row.MouseEnter:Connect(function()
        tween(row, {BackgroundColor3 = theme.dark_contrast}, 0.1)
    end)
    row.MouseLeave:Connect(function()
        tween(row, {BackgroundColor3 = theme.light_contrast}, 0.1)
    end)

    local obj = {
        Get     = function() return sel end,
        Set     = function(_, v)
            if table.find(options, v) then
                sel = v; dispLbl.Text = sel; RebuildPanel()
            end
        end,
        Refresh = function(_, newOpts) options = newOpts; RebuildPanel() end,
    }
    registerPointer(pointer, obj)
    return obj
end

-- ── Multibox ──────────────────────────────────────────────────────────────────
function Section:Multibox(info)
    info     = info     or {}
    local name     = info.name     or info.title    or "Multibox"
    local options  = info.options  or {}
    local def      = info.def      or {options[1]}
    local minSel   = info.min      or 0
    local pointer  = info.pointer  or info.flag
    local callback = info.callback or function() end
    local current  = {table.unpack(def)}
    local isOpen   = false

    local theme = self._theme

    local row = mkFrame(self._content,
        theme.light_contrast, UDim2.new(1,0,0,54), nil, 4)
    mkStroke(row, theme.border_color)

    mkLabel(row, name,
        theme.textsize, theme.textcolor, theme.font,
        UDim2.new(1,-16,0,18), UDim2.fromOffset(8,4))

    local displayBox = mkFrame(row, theme.dark_contrast, UDim2.new(1,-16,0,22), UDim2.new(0,8,1,-28), 4)
    mkStroke(displayBox, theme.border_color)

    local function Serialize(tbl)
        local parts = {}
        for _, v in ipairs(options) do
            if table.find(current, v) then parts[#parts+1] = v end
        end
        return table.concat(parts, ", ")
    end

    local dispLbl = mkLabel(displayBox, Serialize(current),
        theme.textsize - 1, theme.textcolor, theme.font,
        UDim2.new(1,-22,1,0), UDim2.fromOffset(6,0))

    local arrowLbl = mkLabel(displayBox, "▾",
        theme.textsize, theme.textcolor, theme.font,
        UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)

    -- Panel
    local panel = mkFrame(self._content:FindFirstAncestorOfClass("ScreenGui") or row,
        theme.dark_contrast, UDim2.fromOffset(10,0), nil, 4)
    panel.Visible = false
    panel.ZIndex  = 100
    mkStroke(panel, theme.accent)
    mkListLayout(panel, Enum.FillDirection.Vertical, 2)
    mkPadding(panel, 3, 3, 4, 4)

    local function RebuildPanel()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _, opt in ipairs(options) do
            local selected = table.find(current, opt) ~= nil
            local oRow = mkFrame(panel,
                selected and theme.light_contrast or theme.dark_contrast,
                UDim2.new(1,0,0,22), nil, 4)
            oRow.ZIndex = 101
            mkStroke(oRow, selected and theme.accent or theme.border_color)

            local oLbl = mkLabel(oRow, tostring(opt),
                theme.textsize - 1,
                selected and theme.accent or theme.textcolor,
                theme.font, UDim2.new(1,-8,1,0), UDim2.fromOffset(6,0))
            oLbl.ZIndex = 102

            -- Checkmark indicator
            local chk = mkLabel(oRow, selected and "✓" or "",
                theme.textsize - 1, theme.accent, theme.font,
                UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)
            chk.ZIndex = 102

            oRow.InputBegan:Connect(function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local idx = table.find(current, opt)
                if idx then
                    if #current > minSel then
                        table.remove(current, idx)
                    end
                else
                    current[#current+1] = opt
                end
                dispLbl.Text = Serialize(current)
                callback(current)
                RebuildPanel()
            end)
        end
    end
    RebuildPanel()

    local function OpenPanel()
        local absPos = displayBox.AbsolutePosition
        local absW   = displayBox.AbsoluteSize.X
        local h      = math.min(#options * 26 + 10, 220)
        panel.Position = UDim2.fromOffset(absPos.X, absPos.Y + displayBox.AbsoluteSize.Y + 3)
        panel.Size     = UDim2.fromOffset(absW, 0)
        panel.Visible  = true
        tween(panel, {Size = UDim2.fromOffset(absW, h)}, 0.18)
        tween(arrowLbl, {Rotation = 180}, 0.18)
    end

    displayBox.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        isOpen = not isOpen
        if isOpen then OpenPanel()
        else
            tween(panel, {Size = UDim2.fromOffset(panel.AbsoluteSize.X, 0)}, 0.15)
            tween(arrowLbl, {Rotation = 0}, 0.15)
            task.delay(0.15, function() panel.Visible = false end)
        end
    end)

    UserInputService.InputBegan:Connect(function(i)
        if not isOpen or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local m = UserInputService:GetMouseLocation()
        local a = panel.AbsolutePosition; local s = panel.AbsoluteSize
        if not (m.X >= a.X and m.X <= a.X+s.X and m.Y >= a.Y and m.Y <= a.Y+s.Y) then
            isOpen = false
            tween(panel, {Size = UDim2.fromOffset(s.X, 0)}, 0.15)
            tween(arrowLbl, {Rotation = 0}, 0.15)
            task.delay(0.15, function() panel.Visible = false end)
        end
    end)

    row.MouseEnter:Connect(function() tween(row, {BackgroundColor3 = theme.dark_contrast}, 0.1) end)
    row.MouseLeave:Connect(function() tween(row, {BackgroundColor3 = theme.light_contrast}, 0.1) end)

    local obj = {
        Get = function() return current end,
        Set = function(_, tbl)
            if type(tbl) == "table" then
                current = tbl; dispLbl.Text = Serialize(current); RebuildPanel()
            end
        end,
    }
    registerPointer(pointer, obj)
    return obj
end

-- ── Keybind ───────────────────────────────────────────────────────────────────
function Section:Keybind(info)
    info     = info     or {}
    local name      = info.name      or info.title    or "Keybind"
    local def       = info.def
    local mode      = info.mode      or "Always"
    local kbName    = info.keybindname or name
    local pointer   = info.pointer   or info.flag
    local callback  = info.callback  or function() end

    local current   = {}
    local selecting = false
    local active    = (mode == "Always")

    local ALLOWED_KEYS   = {"Q","W","E","R","T","Y","U","I","O","P","A","S","D","F","G","H","J","K","L","Z","X","C","V","B","N","M","One","Two","Three","Four","Five","Six","Seven","Eight","Nine","Insert","Tab","Home","End","LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"}
    local ALLOWED_MOUSE  = {"MouseButton1","MouseButton2","MouseButton3"}
    local SHORT = {MouseButton1="MB1",MouseButton2="MB2",MouseButton3="MB3",Insert="Ins",LeftAlt="LAlt",LeftControl="LC",LeftShift="LS",RightAlt="RAlt",RightControl="RC",RightShift="RS",CapsLock="Caps"}

    local theme = self._theme

    local row = mkFrame(self._content,
        theme.light_contrast, UDim2.new(1,0,0,32), nil, 4)
    mkStroke(row, theme.border_color)

    mkLabel(row, name,
        theme.textsize, theme.textcolor, theme.font,
        UDim2.new(1,-90,1,0), UDim2.fromOffset(8,0))

    local kbox = mkFrame(row,
        theme.dark_contrast,
        UDim2.fromOffset(78,22),
        UDim2.new(1,-86,0.5,-11), 4)
    local kboxStroke = mkStroke(kbox, theme.border_color)

    local klbl = mkLabel(kbox, "...",
        theme.textsize - 2, theme.accent, theme.font,
        UDim2.new(1,0,1,0), nil, Enum.TextXAlignment.Center)

    local function Shorten(str)
        return SHORT[str] or str
    end

    local function Change(input)
        if not input or not input.EnumType then return false end
        if input.EnumType == Enum.KeyCode then
            if not table.find(ALLOWED_KEYS, input.Name) then return false end
            current = {"KeyCode", input.Name}
        elseif input.EnumType == Enum.UserInputType then
            if not table.find(ALLOWED_MOUSE, input.Name) then return false end
            current = {"UserInputType", input.Name}
        end
        klbl.Text = "["..Shorten(current[2]).."]"
        return true
    end

    if def then Change(def) end

    kbox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            selecting = true
            klbl.Text = "[ ... ]"
            klbl.TextColor3 = Color3.fromRGB(255,190,40)
            tween(kbox, {BackgroundColor3 = Color3.fromRGB(40,40,40)}, 0.1)
        elseif i.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Right-click: cycle mode (Always → Toggle → Hold)
            local modes = {"Always","Toggle","Hold"}
            for idx, m in ipairs(modes) do
                if m == mode then
                    mode = modes[idx == #modes and 1 or idx+1]
                    break
                end
            end
            active = (mode == "Always")
            klbl.TextColor3 = theme.accent
        end
    end)

    UserInputService.InputBegan:Connect(function(i)
        -- Fire on held key
        if current[1] and current[2] and not selecting then
            local match = (current[1] == "KeyCode" and i.KeyCode == Enum.KeyCode[current[2]])
                       or (current[1] == "UserInputType" and i.UserInputType == Enum.UserInputType[current[2]])
            if match then
                if mode == "Toggle" then
                    active = not active; callback(Enum[current[1]][current[2]], active)
                elseif mode == "Hold" then
                    active = true; callback(Enum[current[1]][current[2]], active)
                end
            end
        end
        -- Capture new key when selecting
        if selecting then
            local done = Change(i.KeyCode.Name ~= "Unknown" and i.KeyCode or i.UserInputType)
            if done then
                selecting = false
                active    = (mode == "Always")
                klbl.TextColor3 = theme.accent
                tween(kbox, {BackgroundColor3 = theme.dark_contrast}, 0.1)
                if current[1] and current[2] then
                    callback(Enum[current[1]][current[2]], active)
                end
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if mode == "Hold" and current[1] and current[2] then
            local match = (current[1] == "KeyCode" and i.KeyCode == Enum.KeyCode[current[2]])
                       or (current[1] == "UserInputType" and i.UserInputType == Enum.UserInputType[current[2]])
            if match then
                active = false; callback(Enum[current[1]][current[2]], active)
            end
        end
    end)

    row.MouseEnter:Connect(function() tween(row, {BackgroundColor3 = theme.dark_contrast}, 0.1) end)
    row.MouseLeave:Connect(function() tween(row, {BackgroundColor3 = theme.light_contrast}, 0.1) end)

    local obj = {
        Get    = function() return current end,
        Active = function() return active  end,
        Set    = function(_, tbl) if tbl then current = tbl; klbl.Text = "["..Shorten(tbl[2]).."]" end end,
    }
    registerPointer(pointer, obj)
    return obj
end

-- ── Colorpicker ───────────────────────────────────────────────────────────────
function Section:Colorpicker(info)
    info      = info     or {}
    local name      = info.name       or info.title or "Color"
    local def       = info.def        or Color3.fromRGB(255,0,0)
    local useAlpha  = info.transparency ~= nil
    local initAlpha = info.transparency or 0
    local pointer   = info.pointer    or info.flag
    local callback  = info.callback   or function() end

    local theme = self._theme
    local H, S, V = def:ToHSV()
    local A = initAlpha

    local row = mkFrame(self._content,
        theme.light_contrast, UDim2.new(1,0,0,32), nil, 4)
    mkStroke(row, theme.border_color)

    mkLabel(row, name,
        theme.textsize, theme.textcolor, theme.font,
        UDim2.new(1,-52,1,0), UDim2.fromOffset(8,0))

    -- Colour swatch
    local swatch = mkFrame(row, def, UDim2.fromOffset(36,20), UDim2.new(1,-44,0.5,-10), 4)
    mkStroke(swatch, theme.border_color)

    -- Picker popup (inside ScreenGui root)
    local root = row:FindFirstAncestorOfClass("ScreenGui") or row
    local popupW, popupH = 200, useAlpha and 230 or 200

    local popup = mkFrame(root, theme.dark_contrast,
        UDim2.fromOffset(popupW, 0), nil, 6)
    popup.Visible = false
    popup.ZIndex  = 120
    mkStroke(popup, theme.accent)

    local popupTitle = mkLabel(popup, name,
        theme.textsize, theme.textcolor, theme.font,
        UDim2.new(1,0,0,20), UDim2.fromOffset(8,4))
    popupTitle.ZIndex = 121

    -- SV picker area
    local svBg = mkFrame(popup,
        Color3.fromHSV(H,1,1),
        UDim2.new(1,-36,0,140),
        UDim2.fromOffset(6,26), 4)
    svBg.ZIndex = 121
    mkStroke(svBg, theme.border_color)

    local svCursor = mkFrame(svBg, Color3.fromRGB(255,255,255),
        UDim2.fromOffset(10,10),
        UDim2.new(S,-5,1-V,-5), 50)
    svCursor.ZIndex = 123
    mkStroke(svCursor, Color3.fromRGB(0,0,0), 1)

    -- Hue bar
    local hueBar = mkFrame(popup, Color3.fromRGB(255,255,255),
        UDim2.fromOffset(16,140),
        UDim2.new(1,-22,0,26), 4)
    hueBar.ZIndex = 121
    mkStroke(hueBar, theme.border_color)
    -- Hue gradient via ImageLabel trick
    local hueImg = Instance.new("ImageLabel")
    hueImg.Size                   = UDim2.new(1,0,1,0)
    hueImg.BackgroundTransparency = 1
    hueImg.Image                  = "rbxassetid://698052001" -- hue strip
    hueImg.ZIndex                 = 122
    hueImg.Parent                 = hueBar
    mkCorner(hueImg, 4)

    local hueCursor = mkFrame(hueBar, Color3.fromHSV(H,1,1),
        UDim2.new(1,4,0,6),
        UDim2.new(0,-2,H,-3), 2)
    hueCursor.ZIndex = 123
    mkStroke(hueCursor, Color3.fromRGB(255,255,255), 1)

    -- Alpha bar (optional)
    local alphaBar, alphaCursor
    if useAlpha then
        alphaBar = mkFrame(popup, Color3.fromRGB(255,255,255),
            UDim2.new(1,-12,0,14),
            UDim2.fromOffset(6,174), 4)
        alphaBar.ZIndex = 121
        mkStroke(alphaBar, theme.border_color)

        alphaCursor = mkFrame(alphaBar, Color3.fromRGB(255,255,255),
            UDim2.fromOffset(6,20),
            UDim2.new(A,-3,0.5,-10), 2)
        alphaCursor.ZIndex = 123
        mkStroke(alphaCursor, Color3.fromRGB(0,0,0), 1)
    end

    local function UpdateVisuals()
        local col = Color3.fromHSV(H, S, V)
        swatch.BackgroundColor3 = col
        svBg.BackgroundColor3   = Color3.fromHSV(H, 1, 1)
        svCursor.Position       = UDim2.new(S, -5, 1-V, -5)
        hueCursor.Position      = UDim2.new(0, -2, H, -3)
        hueCursor.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        callback(col, A)
    end

    local holdSV, holdHue, holdAlpha = false, false, false

    svBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then holdSV = true end
    end)
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then holdHue = true end
    end)
    if alphaBar then
        alphaBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then holdAlpha = true end
        end)
    end

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            holdSV = false; holdHue = false; holdAlpha = false
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if holdSV then
            local ax,ay = svBg.AbsolutePosition.X, svBg.AbsolutePosition.Y
            local aw,ah = svBg.AbsoluteSize.X,     svBg.AbsoluteSize.Y
            S = math.clamp((i.Position.X - ax) / aw, 0, 1)
            V = 1 - math.clamp((i.Position.Y - ay) / ah, 0, 1)
            UpdateVisuals()
        elseif holdHue then
            local ay = hueBar.AbsolutePosition.Y
            local ah = hueBar.AbsoluteSize.Y
            H = math.clamp((i.Position.Y - ay) / ah, 0, 1)
            UpdateVisuals()
        elseif holdAlpha and alphaBar then
            local ax = alphaBar.AbsolutePosition.X
            local aw = alphaBar.AbsoluteSize.X
            A = math.clamp((i.Position.X - ax) / aw, 0, 1)
            if alphaCursor then
                alphaCursor.Position = UDim2.new(A, -3, 0.5, -10)
            end
            callback(Color3.fromHSV(H,S,V), A)
        end
    end)

    local pickerOpen = false

    swatch.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        pickerOpen = not pickerOpen
        if pickerOpen then
            local absP = swatch.AbsolutePosition
            popup.Position = UDim2.fromOffset(absP.X - popupW - 8, absP.Y - 30)
            popup.Size     = UDim2.fromOffset(popupW, 0)
            popup.Visible  = true
            tween(popup, {Size = UDim2.fromOffset(popupW, popupH)}, 0.18)
        else
            tween(popup, {Size = UDim2.fromOffset(popupW, 0)}, 0.15)
            task.delay(0.15, function() popup.Visible = false end)
        end
    end)

    UserInputService.InputBegan:Connect(function(i)
        if not pickerOpen or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local m = UserInputService:GetMouseLocation()
        local a = popup.AbsolutePosition; local s = popup.AbsoluteSize
        local sw = swatch.AbsolutePosition
        local inPopup  = m.X >= a.X and m.X <= a.X+s.X and m.Y >= a.Y and m.Y <= a.Y+s.Y
        local inSwatch = m.X >= sw.X and m.X <= sw.X+36 and m.Y >= sw.Y and m.Y <= sw.Y+20
        if not inPopup and not inSwatch then
            pickerOpen = false
            tween(popup, {Size = UDim2.fromOffset(popupW, 0)}, 0.15)
            task.delay(0.15, function() popup.Visible = false end)
        end
    end)

    row.MouseEnter:Connect(function() tween(row, {BackgroundColor3 = theme.dark_contrast}, 0.1) end)
    row.MouseLeave:Connect(function() tween(row, {BackgroundColor3 = theme.light_contrast}, 0.1) end)

    UpdateVisuals()

    local obj = {
        Get = function() return Color3.fromHSV(H,S,V), A end,
        Set = function(_, color, alpha)
            if typeof(color) == "Color3" then
                H,S,V = color:ToHSV()
                A = alpha or A
                UpdateVisuals()
            elseif type(color) == "table" then
                H,S,V = table.unpack(color)
                UpdateVisuals()
            end
        end,
    }
    registerPointer(pointer, obj)
    return obj
end

-- ── ConfigBox ─────────────────────────────────────────────────────────────────
function Section:ConfigBox()
    local theme   = self._theme
    local current = 1
    local SLOTS   = 8

    local box = mkFrame(self._content,
        theme.light_contrast, UDim2.new(1,0,0,SLOTS*20+4), nil, 4)
    mkStroke(box, theme.border_color)

    local btns = {}

    for i = 1, SLOTS do
        local sRow = mkFrame(box, theme.dark_contrast,
            UDim2.new(1,-8,0,18),
            UDim2.new(0,4,0,2+(i-1)*20), 3)
        mkStroke(sRow, i==1 and theme.accent or theme.border_color)

        local lbl = mkLabel(sRow, "Config Slot "..i,
            theme.textsize-1,
            i==1 and theme.accent or theme.textcolor,
            theme.font, UDim2.new(1,0,1,0), nil, Enum.TextXAlignment.Center)

        sRow.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            -- Deselect old
            local oldRow  = btns[current]
            local oldStroke = oldRow and oldRow:FindFirstChildOfClass("UIStroke")
            local oldLbl  = oldRow and oldRow:FindFirstChildOfClass("TextLabel")
            if oldStroke then tween(oldStroke, {Color = theme.border_color}, 0.1) end
            if oldLbl    then tween(oldLbl,    {TextColor3 = theme.textcolor}, 0.1) end
            -- Select new
            current = i
            local newStroke = sRow:FindFirstChildOfClass("UIStroke")
            if newStroke then tween(newStroke, {Color = theme.accent}, 0.1) end
            tween(lbl, {TextColor3 = theme.accent}, 0.1)
        end)

        btns[i] = sRow
    end

    return {
        Get = function() return current end,
        Set = function(_, n)
            if n >= 1 and n <= SLOTS then
                -- Reset all
                for i, r in ipairs(btns) do
                    local s = r:FindFirstChildOfClass("UIStroke")
                    local l = r:FindFirstChildOfClass("TextLabel")
                    if s then s.Color = theme.border_color end
                    if l then l.TextColor3 = theme.textcolor end
                end
                current = n
                local s = btns[n]:FindFirstChildOfClass("UIStroke")
                local l = btns[n]:FindFirstChildOfClass("TextLabel")
                if s then s.Color = theme.accent end
                if l then l.TextColor3 = theme.accent end
            end
        end,
    }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- PAGE BUILDER
-- ──────────────────────────────────────────────────────────────────────────────

local Page = {}
Page.__index = Page

-- Creates a two-column section.  Returns a Section handle (or two for side="both").
function Page:Section(info)
    info      = info     or {}
    local name  = info.name or info.title or "Section"
    local side  = (info.side or "left"):lower()

    local theme = self._theme
    local col   = (side == "right") and self._rightCol or self._leftCol

    -- Section card
    local card = mkFrame(col, Color3.fromRGB(18,18,18), UDim2.new(1,0,0,30), nil, 6)
    card.AutomaticSize = Enum.AutomaticSize.Y
    mkStroke(card, theme.accent)

    -- Header
    local header = mkFrame(card, Color3.fromRGB(12,12,12), UDim2.new(1,0,0,24), nil, 0)
    mkCorner(header, 6)
    -- Accent top strip
    local strip = mkFrame(header, theme.accent, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)
    mkStroke(strip, theme.accent)

    mkLabel(header, name:upper(),
        theme.textsize - 2, theme.accent, theme.font,
        UDim2.new(1,-10,1,0), UDim2.fromOffset(8,0),
        Enum.TextXAlignment.Left)

    -- Content scroll
    local content = Instance.new("ScrollingFrame")
    content.BackgroundTransparency = 1
    content.BorderSizePixel        = 0
    content.ScrollBarThickness     = 2
    content.ScrollBarImageColor3   = theme.accent
    content.CanvasSize             = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    content.Size                   = UDim2.new(1,0,0,0)
    content.AutomaticSize          = Enum.AutomaticSize.Y
    content.Parent                 = card

    local ll = mkListLayout(content, Enum.FillDirection.Vertical, 4)
    mkPadding(content, 6, 6, 6, 6)

    local sec = setmetatable({
        _content = content,
        _theme   = theme,
    }, Section)

    return sec
end

-- Tabbed twin section (returns up to 3 sub-section handles).
function Page:Section2(info)
    info     = info     or {}
    local tabs  = info.sections or info.tabs or {"Tab1","Tab2"}
    local side  = (info.side   or "left"):lower()
    local h     = info.size    or 200

    local theme = self._theme
    local col   = (side == "right") and self._rightCol or self._leftCol

    local card = mkFrame(col, Color3.fromRGB(18,18,18), UDim2.new(1,0,0,h), nil, 6)
    mkStroke(card, theme.accent)

    -- Tab bar
    local tabBar = mkFrame(card, Color3.fromRGB(12,12,12),
        UDim2.new(1,0,0,26), nil, 0)
    mkCorner(tabBar, 6)
    mkStroke(tabBar, theme.border_color)
    mkListLayout(tabBar, Enum.FillDirection.Horizontal, 2)

    -- Content host (shows one sub-frame at a time)
    local host = mkFrame(card, Color3.fromRGB(0,0,0),
        UDim2.new(1,0,1,-28),
        UDim2.fromOffset(0,27), 0)
    host.BackgroundTransparency = 1
    host.ClipsDescendants       = true

    local sections = {}
    local tabBtns  = {}
    local active   = nil

    for i, tabName in ipairs(tabs) do
        -- Tab button
        local tb = mkFrame(tabBar, theme.dark_contrast,
            UDim2.new(1/#tabs,0,1,0), nil, 5)
        mkStroke(tb, theme.border_color)

        local tl = mkLabel(tb, tabName,
            theme.textsize - 2, theme.textcolor, theme.font,
            nil, nil, Enum.TextXAlignment.Center)

        -- Sub-frame
        local subFrame = Instance.new("ScrollingFrame")
        subFrame.BackgroundTransparency = 1
        subFrame.BorderSizePixel        = 0
        subFrame.ScrollBarThickness     = 2
        subFrame.ScrollBarImageColor3   = theme.accent
        subFrame.CanvasSize             = UDim2.new(0,0,0,0)
        subFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        subFrame.Size                   = UDim2.new(1,0,1,0)
        subFrame.Visible                = (i == 1)
        subFrame.Parent                 = host
        mkListLayout(subFrame, Enum.FillDirection.Vertical, 4)
        mkPadding(subFrame, 4, 4, 6, 6)

        local sec = setmetatable({
            _content = subFrame,
            _theme   = theme,
        }, Section)
        sections[i] = sec
        tabBtns[i]  = {btn = tb, lbl = tl}

        if i == 1 then
            active = 1
            tb.BackgroundColor3 = Color3.fromRGB(30,30,30)
            tl.TextColor3       = theme.accent
            local s = tb:FindFirstChildOfClass("UIStroke")
            if s then s.Color = theme.accent end
        end

        tb.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            -- deactivate old
            local oldBtn = tabBtns[active]
            tween(oldBtn.btn, {BackgroundColor3 = theme.dark_contrast}, 0.1)
            tween(oldBtn.lbl, {TextColor3       = theme.textcolor},     0.1)
            local os = oldBtn.btn:FindFirstChildOfClass("UIStroke")
            if os then tween(os, {Color = theme.border_color}, 0.1) end
            for _, sf in ipairs(host:GetChildren()) do
                if sf:IsA("ScrollingFrame") then sf.Visible = false end
            end
            -- activate new
            active = i
            tween(tb,  {BackgroundColor3 = Color3.fromRGB(30,30,30)}, 0.1)
            tween(tl,  {TextColor3       = theme.accent},              0.1)
            local ns = tb:FindFirstChildOfClass("UIStroke")
            if ns then tween(ns, {Color = theme.accent}, 0.1) end
            subFrame.Visible = true
        end)
    end

    return table.unpack(sections)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- LIBRARY (window)
-- ──────────────────────────────────────────────────────────────────────────────

function SpixLib.new(info)
    info = info or {}
    local name   = info.name   or info.Name   or "UI"
    local size   = info.size   or info.Size   or Vector2.new(600, 540)
    local accent = info.accent or info.Accent or DEFAULT_THEME.accent

    local theme = {}
    for k, v in pairs(DEFAULT_THEME) do theme[k] = v end
    theme.accent       = accent
    theme.border_color = Color3.new(
        accent.R * 0.4 + 0.15,
        accent.G * 0.4 + 0.15,
        accent.B * 0.4 + 0.15
    )

    -- ── GUI root ──────────────────────────────────────────────────────────────
    local gui = Instance.new("ScreenGui")
    gui.Name           = "SpixLib_"..name
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 999

    local ok = false
    pcall(function() gui.Parent = game:GetService("CoreGui"); ok = true end)
    if not ok then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- ── Main window frame ─────────────────────────────────────────────────────
    local W = mkFrame(gui, Color3.fromRGB(22,22,22),
        UDim2.fromOffset(size.X, size.Y),
        UDim2.fromOffset(
            math.floor((workspace.CurrentCamera.ViewportSize.X - size.X) / 2),
            math.floor((workspace.CurrentCamera.ViewportSize.Y - size.Y) / 2)
        ), 8)
    W.ClipsDescendants = true

    -- Main window border (0.8) — uses accent tint
    mkStroke(W, theme.border_color)

    -- ── Accent top strip ──────────────────────────────────────────────────────
    local topStrip = mkFrame(W, accent, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)
    topStrip.ZIndex = 6

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local TITLE_H = 36
    local titleBar = mkFrame(W, Color3.fromRGB(16,16,16),
        UDim2.new(1,0,0,TITLE_H), UDim2.new(0,0,0,0), 0)
    titleBar.ZIndex = 4
    mkStroke(titleBar, theme.border_color)

    local titleLbl = mkLabel(titleBar, name,
        theme.textsize, theme.textcolor, Enum.Font.GothamBold,
        UDim2.new(1,-80,1,0), UDim2.fromOffset(10,0))
    titleLbl.ZIndex = 5

    -- ── Tab strip ─────────────────────────────────────────────────────────────
    local TAB_H   = 30
    local tabStrip = mkFrame(W, Color3.fromRGB(14,14,14),
        UDim2.new(1,0,0,TAB_H),
        UDim2.fromOffset(0, TITLE_H), 0)
    tabStrip.ZIndex = 4
    mkStroke(tabStrip, theme.border_color)

    local tabLayout = mkListLayout(tabStrip, Enum.FillDirection.Horizontal, 2)
    mkPadding(tabStrip, 4, 4, 4, 4)

    -- ── Content area ──────────────────────────────────────────────────────────
    local HEADER_H = TITLE_H + TAB_H
    local contentArea = mkFrame(W, Color3.fromRGB(18,18,18),
        UDim2.new(1,0,1,-HEADER_H),
        UDim2.fromOffset(0, HEADER_H), 0)
    contentArea.ClipsDescendants = true

    -- ── Window object ─────────────────────────────────────────────────────────
    local window = {
        _gui        = gui,
        _win        = W,
        _titleBar   = titleBar,
        _tabStrip   = tabStrip,
        _content    = contentArea,
        _theme      = theme,
        _pages      = {},
        _activePage = nil,
        uibind      = Enum.KeyCode.RightControl,
        isVisible   = true,
    }

    -- ── Drag ──────────────────────────────────────────────────────────────────
    do
        local drag, ds, sp
        titleBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                drag = true; ds = i.Position; sp = W.Position
            end
        end)
        titleBar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                local d = i.Position - ds
                W.Position = UDim2.fromOffset(sp.X.Offset + d.X, sp.Y.Offset + d.Y)
            end
        end)
    end

    -- ── Hide / show keybind ───────────────────────────────────────────────────
    UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == window.uibind then
            window.isVisible = not window.isVisible
            tween(W, {BackgroundTransparency = window.isVisible and 0 or 1}, 0.2)
            for _, c in ipairs(W:GetDescendants()) do
                if c:IsA("GuiObject") then
                    tween(c, {BackgroundTransparency = window.isVisible and c.BackgroundTransparency or 1}, 0.2)
                end
            end
            W.Enabled = window.isVisible
        end
    end)

    -- ── Page method ───────────────────────────────────────────────────────────
    function window:Page(pageInfo)
        pageInfo = pageInfo or {}
        local pageName = pageInfo.name or pageInfo.title or "Page"

        -- Tab button
        local tabBtn = mkFrame(self._tabStrip,
            Color3.fromRGB(22,22,22),
            UDim2.fromOffset(0, TAB_H - 8), nil, 4)
        tabBtn.AutomaticSize = Enum.AutomaticSize.X
        mkStroke(tabBtn, theme.border_color)

        local tabLbl = mkLabel(tabBtn, pageName,
            theme.textsize - 1, Color3.fromRGB(160,160,160), Enum.Font.GothamSemibold,
            UDim2.new(0,0,1,0), nil, Enum.TextXAlignment.Center)
        tabLbl.AutomaticSize = Enum.AutomaticSize.X
        mkPadding(tabLbl, 0, 0, 10, 10)

        -- Page frame (two columns)
        local pageFrame = mkFrame(self._content,
            Color3.fromRGB(0,0,0),
            UDim2.new(1,0,1,0), nil, 0)
        pageFrame.BackgroundTransparency = 1
        pageFrame.Visible = false

        local colLayout = mkListLayout(pageFrame, Enum.FillDirection.Horizontal, 6)
        mkPadding(pageFrame, 6, 6, 6, 6)

        local leftCol = mkFrame(pageFrame, Color3.fromRGB(0,0,0),
            UDim2.new(0.5,-3,1,0), nil, 0)
        leftCol.BackgroundTransparency = 1
        leftCol.AutomaticSize = Enum.AutomaticSize.Y
        mkListLayout(leftCol, Enum.FillDirection.Vertical, 6)

        local rightCol = mkFrame(pageFrame, Color3.fromRGB(0,0,0),
            UDim2.new(0.5,-3,1,0), nil, 0)
        rightCol.BackgroundTransparency = 1
        rightCol.AutomaticSize = Enum.AutomaticSize.Y
        mkListLayout(rightCol, Enum.FillDirection.Vertical, 6)

        local pageObj = setmetatable({
            _theme    = theme,
            _leftCol  = leftCol,
            _rightCol = rightCol,
            _frame    = pageFrame,
            _tabBtn   = tabBtn,
            _tabLbl   = tabLbl,
        }, Page)

        table.insert(self._pages, pageObj)

        -- Show this page
        local function ShowPage()
            if self._activePage then
                self._activePage._frame.Visible = false
                local ob = self._activePage._tabBtn
                tween(ob, {BackgroundColor3 = Color3.fromRGB(22,22,22)}, 0.12)
                local ol = self._activePage._tabLbl
                tween(ol, {TextColor3 = Color3.fromRGB(160,160,160)}, 0.12)
                local os = ob:FindFirstChildOfClass("UIStroke")
                if os then tween(os, {Color = theme.border_color}, 0.12) end
            end
            self._activePage = pageObj
            pageFrame.Visible = true
            tween(tabBtn, {BackgroundColor3 = Color3.fromRGB(35,35,35)}, 0.12)
            tween(tabLbl, {TextColor3       = theme.accent},              0.12)
            local ns = tabBtn:FindFirstChildOfClass("UIStroke")
            if ns then tween(ns, {Color = theme.accent}, 0.12) end
        end

        tabBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then ShowPage() end
        end)

        if #self._pages == 1 then
            task.defer(ShowPage)
        end

        return pageObj
    end

    -- ── GetConfig ─────────────────────────────────────────────────────────────
    function window:GetConfig()
        local cfg = {}
        for k, v in pairs(_pointers) do
            local val = v:Get()
            if typeof(val) == "Color3" then
                local h, s, vv = val:ToHSV()
                cfg[k] = {type="Color3", H=h, S=s, V=vv}
            elseif type(val) == "table" then
                cfg[k] = {type="table", value=val}
            else
                cfg[k] = {type="value", value=val}
            end
        end
        return HttpService:JSONEncode(cfg)
    end

    -- ── LoadConfig ────────────────────────────────────────────────────────────
    function window:LoadConfig(json)
        local ok2, cfg = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok2 then return end
        for k, data in pairs(cfg) do
            if _pointers[k] then
                if data.type == "Color3" then
                    _pointers[k]:Set(Color3.fromHSV(data.H, data.S, data.V))
                elseif data.type == "table" then
                    _pointers[k]:Set(data.value)
                else
                    _pointers[k]:Set(data.value)
                end
            end
        end
    end

    -- ── Unload ────────────────────────────────────────────────────────────────
    function window:Unload()
        gui:Destroy()
    end

    -- ── Open animation ────────────────────────────────────────────────────────
    W.Size = UDim2.fromOffset(size.X, 0)
    tween(W, {Size = UDim2.fromOffset(size.X, size.Y)}, 0.35, Enum.EasingStyle.Quint)

    return window
end

return SpixLib
