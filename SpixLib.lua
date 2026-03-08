--[[
    SpixLib — Full Roblox UI Library
    Instance-based rebuild of the Splix Drawing-API library.
    UIStroke 0.8 on EVERY element.  No example code.

    FULL API
    --------
    win  = SpixLib.new({ name, size?, accent? })

    win:Page            ({ name })                   → page
    win:Watermark       ({ name? })                  → watermark
    win:KeybindsList    ()                           → keybindsList
    win:Cursor          ()                           → cursor handles
    win:GetConfig       ()                           → JSON string
    win:LoadConfig      (json)
    win:SaveToFile      (path)
    win:LoadFromFile    (path)
    win:Unload          ()

    page:Section        ({ name, side? })            → section
    page:MultiSection   ({ sections, side?, size? }) → section... (unpack up to 3)

    section:Label       ({ name, middle? })
    section:Divider     ()
    section:Toggle      ({ name, def?, pointer?, callback? })             → toggle
        toggle:Colorpicker({ info?, def?, transparency?, pointer?, callback? }) → cp
        toggle:Keybind   ({ def?, mode?, keybindname?, pointer?, callback? })   → kb
    section:Slider      ({ name, min?, max?, def?, suffix?, decimals?, pointer?, callback? }) → slider
    section:Button      ({ name, pointer?, callback? })
    section:ButtonHolder({ buttons={{label,cb},{label,cb}} })
    section:Dropdown    ({ name, options, def?, pointer?, callback? })    → dropdown
        dropdown:Refresh (newOptions)
    section:Multibox    ({ name, options, def?, min?, pointer?, callback? }) → multibox
    section:Keybind     ({ name, def?, mode?, keybindname?, pointer?, callback? }) → keybind
    section:Colorpicker ({ name, info?, def?, transparency?, pointer?, callback? }) → colorpicker
        colorpicker:Colorpicker({ info?, def?, transparency?, pointer?, callback? }) → cp2
    section:ConfigBox   ()                                                → configbox

    All pointered controls: { Get(), Set(v) }
    Keybinds also:          { Active() }
    Dropdown also:          { Refresh(newOpts) }
    Watermark also:         { Update("Visible"|"Name"|"Offset", value) }
    KeybindsList also:      { Update("Visible", bool), Add(name,val), Remove(name) }
--]]

local SpixLib = {}
SpixLib.__index = SpixLib

-- ════════════════════════════════════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════════════════════════════════════
local Players   = game:GetService("Players")
local RS        = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local TS        = game:GetService("TweenService")
local HS        = game:GetService("HttpService")
local Stats     = game:GetService("Stats")
local TextSvc   = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer

-- ════════════════════════════════════════════════════════════════════
-- GLOBAL POINTER REGISTRY
-- ════════════════════════════════════════════════════════════════════
local Pointers = {}
local function RegPtr(flag, obj)
    if flag and tostring(flag) ~= "" and tostring(flag) ~= " " then
        if not Pointers[tostring(flag)] then
            Pointers[tostring(flag)] = obj
        end
    end
end

-- ════════════════════════════════════════════════════════════════════
-- THEME  (module-level, patched per window)
-- ════════════════════════════════════════════════════════════════════
local T = {
    accent         = Color3.fromRGB(50,  100, 255),
    light_contrast = Color3.fromRGB(28,   28,  28),
    dark_contrast  = Color3.fromRGB(17,   17,  17),
    panel          = Color3.fromRGB(22,   22,  22),
    inline         = Color3.fromRGB(45,   45,  45),
    textcolor      = Color3.fromRGB(255, 255, 255),
    textdim        = Color3.fromRGB(155, 155, 155),
    border         = Color3.fromRGB(55,   55,  55),
    font           = Enum.Font.GothamSemibold,
    fontBold       = Enum.Font.GothamBold,
    textsize       = 13,
}
local BW = 0.8   -- UIStroke thickness everywhere

-- ════════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════════
local function Tw(inst, props, dur, style, dir)
    TS:Create(inst,
        TweenInfo.new(dur or .14, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props):Play()
end

local function Corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 4); c.Parent = p; return c
end

local function Stroke(p, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color           = color     or T.border
    s.Thickness       = thickness or BW
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = p
    return s
end

local function Pad(p, top, bot, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, top or 4)
    u.PaddingBottom = UDim.new(0, bot or 4)
    u.PaddingLeft   = UDim.new(0, l   or 6)
    u.PaddingRight  = UDim.new(0, r   or 6)
    u.Parent        = p; return u
end

local function List(p, dir, gap, sort)
    local l = Instance.new("UIListLayout")
    l.FillDirection       = dir  or Enum.FillDirection.Vertical
    l.Padding             = UDim.new(0, gap  or 4)
    l.SortOrder           = sort or Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left
    l.Parent              = p; return l
end

local function Frame(p, bg, sz, pos, r)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg  or Color3.fromRGB(20,20,20)
    f.BorderSizePixel  = 0
    f.Size             = sz  or UDim2.new(1,0,0,30)
    f.Position         = pos or UDim2.new(0,0,0,0)
    f.Parent           = p
    if r then Corner(f, r) end
    return f
end

local function Label(p, txt, tsz, col, fnt, sz, pos, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.Font         = fnt or T.font
    l.Text         = txt or ""
    l.TextSize     = tsz or T.textsize
    l.TextColor3   = col or T.textcolor
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Size         = sz  or UDim2.new(1,0,1,0)
    l.Position     = pos or UDim2.new(0,0,0,0)
    l.Parent       = p; return l
end

local function Btn(p, txt, tsz, col, fnt, sz, pos)
    local b = Instance.new("TextButton")
    b.BackgroundTransparency = 1
    b.BorderSizePixel        = 0
    b.AutoButtonColor        = false
    b.Font         = fnt or T.font
    b.Text         = txt or ""
    b.TextSize     = tsz or T.textsize
    b.TextColor3   = col or T.textcolor
    b.TextXAlignment = Enum.TextXAlignment.Center
    b.TextYAlignment = Enum.TextYAlignment.Center
    b.Size         = sz  or UDim2.new(1,0,1,0)
    b.Position     = pos or UDim2.new(0,0,0,0)
    b.Parent       = p; return b
end

local function ScrollFrame(p, h)
    local sf = Instance.new("ScrollingFrame")
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel        = 0
    sf.ScrollBarThickness     = 2
    sf.ScrollBarImageColor3   = T.accent
    sf.CanvasSize             = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    sf.Size                   = h and UDim2.new(1,0,0,h) or UDim2.new(1,0,0,0)
    sf.AutomaticSize          = Enum.AutomaticSize.Y
    sf.Parent                 = p; return sf
end

-- Rainbow gradient for hue bar
local function HueGrad(p)
    local kp = {}
    for i = 0, 6 do kp[#kp+1] = ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6, 1, 1)) end
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(kp)
    g.Rotation = 90
    g.Parent   = p; return g
end

-- Checker background for alpha strip
local function Checker(p)
    local f = Frame(p, Color3.fromRGB(180,180,180), UDim2.new(1,0,1,0), nil, 0)
    f.BackgroundColor3 = Color3.fromRGB(180,180,180)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180,180,180)),
        ColorSequenceKeypoint.new(0.499, Color3.fromRGB(180,180,180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240,240,240)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(240,240,240)),
    })
    g.Rotation = 0
    g.Parent = f
    return f
end

-- ════════════════════════════════════════════════════════════════════
-- COLORPICKER BUILDER  (shared by Section:Colorpicker, toggle:Colorpicker, etc.)
-- anchor    = small swatch Frame placed inline
-- popupRoot = ScreenGui
-- ════════════════════════════════════════════════════════════════════
local function MakeColorpicker(anchor, popupRoot, lbl, initColor, initAlpha, cb)
    local H, S, V = initColor:ToHSV()
    local A       = initAlpha or 0
    local hasA    = (initAlpha ~= nil)
    local open    = false

    local PW   = 210
    local SVAH = 128
    local PH   = 32 + SVAH + 22 + (hasA and 26 or 0) + 10

    -- Swatch styling
    anchor.BackgroundColor3 = initColor
    Corner(anchor, 3)
    Stroke(anchor, T.border)

    -- ── Popup ─────────────────────────────────────────────────────────
    local pop = Frame(popupRoot, T.dark_contrast, UDim2.fromOffset(PW,0), nil, 6)
    pop.Visible            = false
    pop.ZIndex             = 200
    pop.ClipsDescendants   = true
    local popStroke = Stroke(pop, T.accent)

    -- Top accent strip
    local ptop = Frame(pop, T.accent, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)
    ptop.ZIndex = 201

    Label(pop, lbl, T.textsize-1, T.textcolor, T.font,
        UDim2.new(1,-8,0,20), UDim2.fromOffset(6,3)).ZIndex = 201

    -- ── SV area ────────────────────────────────────────────────────────
    local svOuter = Frame(pop, T.border, UDim2.new(1,-18,0,SVAH+2), UDim2.fromOffset(6,26), 4)
    svOuter.ZIndex = 201
    Stroke(svOuter, T.border)

    local svBg = Frame(svOuter, Color3.fromHSV(H,1,1), UDim2.new(1,-2,1,-2), UDim2.fromOffset(1,1), 3)
    svBg.ZIndex = 202
    -- Saturation overlay (white → transparent, left→right)
    local svSatGrad = Instance.new("UIGradient")
    svSatGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
    })
    svSatGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    svSatGrad.Rotation = 0
    svSatGrad.Parent   = svBg
    -- Value overlay (transparent → black, top→bottom)
    local svValFrame = Frame(svBg, Color3.fromRGB(0,0,0), UDim2.new(1,0,1,0), nil, 3)
    svValFrame.ZIndex = 203
    local svValGrad = Instance.new("UIGradient")
    svValGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    svValGrad.Rotation = 90
    svValGrad.Parent   = svValFrame
    -- SV cursor
    local svCur = Frame(svBg, Color3.fromRGB(255,255,255),
        UDim2.fromOffset(10,10), UDim2.new(S,-5,1-V,-5), 50)
    svCur.ZIndex = 205
    Stroke(svCur, Color3.fromRGB(0,0,0), 1.5)

    -- ── Hue bar ────────────────────────────────────────────────────────
    local hueOuter = Frame(pop, T.border,
        UDim2.fromOffset(14,SVAH+2), UDim2.new(1,-18,0,26), 4)
    hueOuter.ZIndex = 201
    Stroke(hueOuter, T.border)
    local hueBg = Frame(hueOuter, Color3.fromRGB(255,255,255),
        UDim2.new(1,-2,1,-2), UDim2.fromOffset(1,1), 3)
    hueBg.ZIndex = 202
    HueGrad(hueBg)
    local hueCur = Frame(hueBg, Color3.fromHSV(H,1,1),
        UDim2.new(1,4,0,6), UDim2.new(0,-2,H,-3), 2)
    hueCur.ZIndex = 205
    Stroke(hueCur, Color3.fromRGB(255,255,255), 1.5)

    -- ── Alpha bar ──────────────────────────────────────────────────────
    local alphaOuter, alphaBg, alphaCur, alphaColorLayer
    if hasA then
        alphaOuter = Frame(pop, T.border,
            UDim2.new(1,-18,0,12), UDim2.new(0,6,0,30+SVAH+6), 4)
        alphaOuter.ZIndex = 201
        Stroke(alphaOuter, T.border)
        alphaBg = Frame(alphaOuter, Color3.fromRGB(200,200,200),
            UDim2.new(1,-2,1,-2), UDim2.fromOffset(1,1), 3)
        alphaBg.ZIndex = 202
        Checker(alphaBg)
        alphaColorLayer = Frame(alphaBg, Color3.fromHSV(H,S,V),
            UDim2.new(1,0,1,0), nil, 3)
        alphaColorLayer.ZIndex = 203
        local ag = Instance.new("UIGradient")
        ag.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        ag.Rotation = 0
        ag.Parent   = alphaColorLayer
        alphaCur = Frame(alphaBg, Color3.fromRGB(255,255,255),
            UDim2.fromOffset(6,18), UDim2.new(A,-3,0.5,-9), 2)
        alphaCur.ZIndex = 205
        Stroke(alphaCur, Color3.fromRGB(0,0,0), 1.5)
    end

    -- ── Hex input ──────────────────────────────────────────────────────
    local hexYOffset = 30 + SVAH + (hasA and 26 or 0) + 8
    local hexRow = Frame(pop, T.light_contrast,
        UDim2.new(1,-12,0,20), UDim2.new(0,6,0,hexYOffset), 3)
    hexRow.ZIndex = 201
    Stroke(hexRow, T.border)
    local hexBox = Instance.new("TextBox")
    hexBox.BackgroundTransparency = 1
    hexBox.Font          = T.font
    hexBox.TextSize      = T.textsize-2
    hexBox.TextColor3    = T.textcolor
    hexBox.Size          = UDim2.new(1,-8,1,0)
    hexBox.Position      = UDim2.fromOffset(4,0)
    hexBox.ZIndex        = 202
    hexBox.ClearTextOnFocus = false
    hexBox.Parent        = hexRow

    local function ColToHex(c)
        return string.format("#%02X%02X%02X",
            math.round(c.R*255), math.round(c.G*255), math.round(c.B*255))
    end

    local function Refresh()
        local col = Color3.fromHSV(H,S,V)
        anchor.BackgroundColor3   = col
        svBg.BackgroundColor3     = Color3.fromHSV(H,1,1)
        svCur.Position            = UDim2.new(S,-5,1-V,-5)
        hueCur.Position           = UDim2.new(0,-2,H,-3)
        hueCur.BackgroundColor3   = Color3.fromHSV(H,1,1)
        hexBox.Text               = ColToHex(col)
        if alphaColorLayer then alphaColorLayer.BackgroundColor3 = col end
        if alphaCur        then alphaCur.Position = UDim2.new(A,-3,0.5,-9) end
        cb(col, A)
    end

    hexBox.Text = ColToHex(initColor)
    hexBox.FocusLost:Connect(function()
        local t = hexBox.Text:gsub("#",""):upper()
        if #t == 6 then
            local r = tonumber(t:sub(1,2),16)
            local g = tonumber(t:sub(3,4),16)
            local bv = tonumber(t:sub(5,6),16)
            if r and g and bv then
                local col = Color3.fromRGB(r,g,bv)
                H,S,V = col:ToHSV(); Refresh()
            end
        end
    end)

    -- drag state
    local hSV, hHue, hAlpha = false, false, false

    svBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hSV = true
            local ax,ay = svBg.AbsolutePosition.X, svBg.AbsolutePosition.Y
            local aw,ah = svBg.AbsoluteSize.X,     svBg.AbsoluteSize.Y
            S = math.clamp((i.Position.X-ax)/aw,0,1)
            V = 1-math.clamp((i.Position.Y-ay)/ah,0,1)
            Refresh()
        end
    end)
    hueBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hHue = true
            local ay = hueBg.AbsolutePosition.Y
            local ah = hueBg.AbsoluteSize.Y
            H = math.clamp((i.Position.Y-ay)/ah,0,1)
            Refresh()
        end
    end)
    if alphaBg then
        alphaBg.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                hAlpha = true
                local ax = alphaBg.AbsolutePosition.X
                local aw = alphaBg.AbsoluteSize.X
                A = math.clamp((i.Position.X-ax)/aw,0,1)
                Refresh()
            end
        end)
    end
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hSV=false; hHue=false; hAlpha=false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if hSV then
            local ax,ay = svBg.AbsolutePosition.X, svBg.AbsolutePosition.Y
            local aw,ah = svBg.AbsoluteSize.X,     svBg.AbsoluteSize.Y
            S = math.clamp((i.Position.X-ax)/aw,0,1)
            V = 1-math.clamp((i.Position.Y-ay)/ah,0,1)
            Refresh()
        elseif hHue then
            local ay = hueBg.AbsolutePosition.Y
            local ah = hueBg.AbsoluteSize.Y
            H = math.clamp((i.Position.Y-ay)/ah,0,1)
            Refresh()
        elseif hAlpha and alphaBg then
            local ax = alphaBg.AbsolutePosition.X
            local aw = alphaBg.AbsoluteSize.X
            A = math.clamp((i.Position.X-ax)/aw,0,1)
            Refresh()
        end
    end)

    -- open / close
    local function OpenPop()
        open = true
        local ap  = anchor.AbsolutePosition
        pop.Position = UDim2.fromOffset(ap.X - PW - 8, ap.Y - 28)
        pop.Size     = UDim2.fromOffset(PW, 0)
        pop.Visible  = true
        Tw(pop, {Size = UDim2.fromOffset(PW, PH)}, 0.22)
    end
    local function ClosePop()
        open = false
        Tw(pop, {Size = UDim2.fromOffset(PW, 0)}, 0.15)
        task.delay(0.16, function() pop.Visible = false end)
    end

    anchor.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            if open then ClosePop() else OpenPop() end
        end
    end)
    UIS.InputBegan:Connect(function(i)
        if not open or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local m  = UIS:GetMouseLocation()
        local pa = pop.AbsolutePosition;    local ps = pop.AbsoluteSize
        local aa = anchor.AbsolutePosition; local as2 = anchor.AbsoluteSize
        local inP = m.X>=pa.X and m.X<=pa.X+ps.X and m.Y>=pa.Y and m.Y<=pa.Y+ps.Y
        local inA = m.X>=aa.X and m.X<=aa.X+as2.X and m.Y>=aa.Y and m.Y<=aa.Y+as2.Y
        if not inP and not inA then ClosePop() end
    end)

    Refresh()

    -- control object
    local ctrl = {}
    ctrl.Get = function()
        return Color3.fromHSV(H,S,V), A
    end
    ctrl.Set = function(_, color, alpha)
        if typeof(color) == "Color3" then
            H,S,V = color:ToHSV()
            if alpha ~= nil then A = alpha end
        elseif type(color) == "table" then
            if color.Color then
                local cc = color.Color
                if type(cc)=="table" then H=cc[1];S=cc[2];V=cc[3]
                elseif typeof(cc)=="Color3" then H,S,V=cc:ToHSV() end
                if color.Transparency then A=color.Transparency end
            elseif color[1] then
                H=color[1]; S=color[2]; V=color[3]
                if alpha then A=alpha end
            end
        end
        Refresh()
    end
    return ctrl
end

-- ════════════════════════════════════════════════════════════════════
-- SECTION  — element builders
-- ════════════════════════════════════════════════════════════════════
local Section = {}
Section.__index = Section

-- ── Label ──────────────────────────────────────────────────────────
function Section:Label(info)
    info = info or {}
    local name   = info.name or info.title or "Label"
    local middle = info.middle == true
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.Size         = UDim2.new(1,0,0,0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.Parent        = self._content
    local l = Label(f, name, T.textsize-1, T.textdim, T.font,
        UDim2.new(1,0,0,0), nil,
        middle and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left)
    l.TextWrapped   = true
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.Size          = UDim2.new(1,0,0,0)
end

-- ── Divider ────────────────────────────────────────────────────────
function Section:Divider()
    Frame(self._content, T.inline, UDim2.new(1,-4,0,1), UDim2.fromOffset(2,0), 0)
end

-- ── Toggle ─────────────────────────────────────────────────────────
function Section:Toggle(info)
    info = info or {}
    local name    = info.name    or info.title or "Toggle"
    local def     = info.def     == true
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end
    local val     = def
    local extraRight = 0  -- space consumed by sub-elements on right

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,34), nil, 5)
    local rowStroke = Stroke(row, T.border)

    local track = Frame(row, val and T.accent or Color3.fromRGB(45,45,45),
        UDim2.fromOffset(36,18), UDim2.new(1,-44,0.5,-9), 50)
    local trackStroke = Stroke(track, val and T.accent or T.border)

    local knob = Frame(track, Color3.fromRGB(238,238,238),
        UDim2.fromOffset(12,12), val and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3), 50)
    Stroke(knob, Color3.fromRGB(190,190,190), 0.5)

    local titleLbl = Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(1,-90,1,0), UDim2.fromOffset(8,0))

    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local function Apply(v)
        val = v
        Tw(track, {BackgroundColor3 = v and T.accent or Color3.fromRGB(45,45,45)}, 0.15)
        Tw(trackStroke, {Color = v and T.accent or T.border}, 0.15)
        Tw(knob, {Position = v and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)}, 0.18)
        cb(v)
    end

    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then Apply(not val) end
    end)

    local toggle = {
        Get = function() return val end,
        Set = function(_, v) Apply(v) end,
        _row = row,
        _track = track,
        _titleLbl = titleLbl,
        _popupRoot = self._popupRoot,
        _extraRight = function() return extraRight end,
    }

    -- ── toggle:Colorpicker ──────────────────────────────────────────
    function toggle:Colorpicker(ci)
        ci = ci or {}
        local cpLabel  = ci.info or ci.Info or name
        local defCol   = ci.def  or Color3.fromRGB(255,0,0)
        local defAlpha = ci.transparency or ci.alpha
        local cpPtr    = ci.pointer or ci.flag
        local cpCb     = ci.callback or function() end

        extraRight = extraRight + 38
        track.Position = UDim2.new(1, -(44+extraRight), 0.5, -9)
        titleLbl.Size  = UDim2.new(1, -(90+extraRight), 1, 0)

        local sw = Frame(row, defCol, UDim2.fromOffset(32,18),
            UDim2.new(1, -(6+extraRight), 0.5, -9), 3)

        local ctrl = MakeColorpicker(sw, self._popupRoot, cpLabel, defCol, defAlpha, cpCb)
        RegPtr(cpPtr, ctrl)
        return ctrl
    end

    -- ── toggle:Keybind ──────────────────────────────────────────────
    function toggle:Keybind(ki)
        ki = ki or {}
        local kbDef  = ki.def
        local kbMode = ki.mode       or "Always"
        local kbName = ki.keybindname or name
        local kbPtr  = ki.pointer    or ki.flag
        local kbCb   = ki.callback   or function() end

        extraRight = extraRight + 46
        track.Position = UDim2.new(1, -(44+extraRight), 0.5, -9)
        titleLbl.Size  = UDim2.new(1, -(90+extraRight), 1, 0)

        local kbox = Frame(row, T.dark_contrast,
            UDim2.fromOffset(44,20),
            UDim2.new(1, -(50+extraRight-46+44), 0.5, -10), 4)
        -- recalc pos so it sits just left of track
        kbox.Position = UDim2.new(1, -(8+extraRight), 0.5, -10)
        local kboxS = Stroke(kbox, T.border)
        local klbl = Label(kbox, "...", T.textsize-2, T.accent, T.font,
            nil, nil, Enum.TextXAlignment.Center)

        local ALLOWED_KEYS  = {"Q","W","E","R","T","Y","U","I","O","P","A","S","D","F","G","H","J","K","L","Z","X","C","V","B","N","M","One","Two","Three","Four","Five","Six","Seven","Eight","Nine","Insert","Tab","Home","End","LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"}
        local ALLOWED_MOUSE = {"MouseButton1","MouseButton2","MouseButton3"}
        local SHORT = {MouseButton1="MB1",MouseButton2="MB2",MouseButton3="MB3",Insert="Ins",LeftAlt="LAlt",LeftControl="LC",LeftShift="LS",RightAlt="RAlt",RightControl="RC",RightShift="RS",CapsLock="Caps"}
        local current   = {}
        local selecting = false
        local active    = (kbMode == "Always")
        local function Sh(s) return SHORT[s] or s end
        local function Chg(inp)
            if not inp or not inp.EnumType then return false end
            local n2 = inp.Name
            if inp.EnumType==Enum.KeyCode and table.find(ALLOWED_KEYS,n2) then
                current={"KeyCode",n2}
            elseif inp.EnumType==Enum.UserInputType and table.find(ALLOWED_MOUSE,n2) then
                current={"UserInputType",n2}
            else return false end
            klbl.Text = "["..Sh(current[2]).."]"; return true
        end
        if kbDef then Chg(kbDef) end

        kbox.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                selecting=true; klbl.Text="[...]"
                klbl.TextColor3=Color3.fromRGB(255,190,40)
                Tw(kboxS,{Color=T.accent},0.1)
            elseif i.UserInputType==Enum.UserInputType.MouseButton2 then
                local modes={"Always","Toggle","Hold"}
                for idx,m in ipairs(modes) do
                    if m==kbMode then kbMode=modes[idx==#modes and 1 or idx+1]; break end
                end
                active=(kbMode=="Always"); klbl.TextColor3=T.accent
            end
        end)
        UIS.InputBegan:Connect(function(i)
            if current[1] and current[2] and not selecting then
                local hit=(current[1]=="KeyCode" and i.KeyCode==Enum.KeyCode[current[2]])
                        or(current[1]=="UserInputType" and i.UserInputType==Enum.UserInputType[current[2]])
                if hit then
                    if kbMode=="Toggle" then active=not active; kbCb(Enum[current[1]][current[2]],active)
                    elseif kbMode=="Hold" then active=true; kbCb(Enum[current[1]][current[2]],active) end
                end
            end
            if selecting then
                local k=i.KeyCode.Name~="Unknown" and i.KeyCode or i.UserInputType
                if Chg(k) then
                    selecting=false; active=(kbMode=="Always")
                    klbl.TextColor3=T.accent; Tw(kboxS,{Color=T.border},0.1)
                    if current[1] then kbCb(Enum[current[1]][current[2]],active) end
                end
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if kbMode=="Hold" and current[1] and current[2] then
                local hit=(current[1]=="KeyCode" and i.KeyCode==Enum.KeyCode[current[2]])
                        or(current[1]=="UserInputType" and i.UserInputType==Enum.UserInputType[current[2]])
                if hit then active=false; kbCb(Enum[current[1]][current[2]],active) end
            end
        end)

        local obj={
            Get=function() return current end,
            Set=function(_,t) if t then current=t; klbl.Text="["..Sh(t[2]).."]" end end,
            Active=function() return active end,
        }
        RegPtr(kbPtr,obj); return obj
    end

    RegPtr(pointer, toggle); return toggle
end

-- ── Slider ─────────────────────────────────────────────────────────
function Section:Slider(info)
    info = info or {}
    local name    = info.name    or info.title or "Slider"
    local minV    = info.min     or 0
    local maxV    = info.max     or 100
    local def     = math.clamp(info.def or minV, minV, maxV)
    local suffix  = info.suffix  or ""
    local decs    = info.decimals or 1
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end
    local val     = def

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,50), nil, 5)
    Stroke(row, T.border)

    Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(0.65,0,0,18), UDim2.fromOffset(8,4))
    local valLbl = Label(row, tostring(def)..suffix, T.textsize-1, T.accent, T.font,
        UDim2.new(0.33,-8,0,18), UDim2.new(0.65,4,0,4), Enum.TextXAlignment.Right)

    local trackBg = Frame(row, Color3.fromRGB(30,30,30),
        UDim2.new(1,-16,0,6), UDim2.new(0,8,1,-16), 50)
    Stroke(trackBg, T.border)
    local fill = Frame(trackBg, T.accent,
        UDim2.new((def-minV)/(maxV-minV),0,1,0), nil, 50)
    Stroke(fill, T.accent, 0.4)
    local knob = Frame(trackBg, Color3.fromRGB(240,240,240),
        UDim2.fromOffset(14,14), UDim2.new((def-minV)/(maxV-minV),-7,0.5,-7), 50)
    Stroke(knob, T.accent)

    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local dragging = false
    local function SetVal(v)
        v = math.clamp(math.round(v*(1/decs))/(1/decs), minV, maxV)
        val = v
        valLbl.Text = tostring(val)..suffix
        local r = (val-minV)/(maxV-minV)
        Tw(fill, {Size=UDim2.new(r,0,1,0)}, 0.05)
        Tw(knob, {Position=UDim2.new(r,-7,0.5,-7)}, 0.05)
        cb(val)
    end
    local function FromX(x)
        local ax=trackBg.AbsolutePosition.X; local aw=trackBg.AbsoluteSize.X
        SetVal(minV+(maxV-minV)*math.clamp((x-ax)/aw,0,1))
    end
    trackBg.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; Tw(knob,{Size=UDim2.fromOffset(18,18)},0.1); FromX(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 and dragging then
            dragging=false; Tw(knob,{Size=UDim2.fromOffset(14,14)},0.1)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then FromX(i.Position.X) end
    end)
    SetVal(val)
    local obj={Get=function() return val end, Set=function(_,v) SetVal(v) end}
    RegPtr(pointer,obj); return obj
end

-- ── Button ─────────────────────────────────────────────────────────
function Section:Button(info)
    info = info or {}
    local name    = info.name    or info.title or "Button"
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,32), nil, 5)
    Stroke(row, T.border)
    -- subtle accent underline
    Frame(row, T.accent, UDim2.new(0.35,0,0,1), UDim2.new(0.325,0,1,-1), 0)
    local b = Btn(row, name, T.textsize, T.textcolor, T.font)

    b.MouseButton1Click:Connect(function()
        Tw(row,{BackgroundColor3=T.accent},0.07)
        task.delay(0.14,function() Tw(row,{BackgroundColor3=T.light_contrast},0.15) end)
        cb()
    end)
    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local obj={Get=function() end, Set=function() end}
    RegPtr(pointer,obj); return obj
end

-- ── ButtonHolder ───────────────────────────────────────────────────
function Section:ButtonHolder(info)
    info = info or {}
    local buttons = info.buttons or {}
    local holder  = Frame(self._content, Color3.fromRGB(0,0,0),
        UDim2.new(1,0,0,32), nil, 0)
    holder.BackgroundTransparency = 1
    List(holder, Enum.FillDirection.Horizontal, 4)
    for i=1,2 do
        local bd = buttons[i]; if not bd then break end
        local cell = Frame(holder, T.light_contrast, UDim2.new(0.5,-3,1,0), nil, 5)
        Stroke(cell, T.border)
        local b = Btn(cell, bd[1], T.textsize, T.textcolor, T.font)
        local cb2 = bd[2] or function() end
        b.MouseButton1Click:Connect(function()
            Tw(cell,{BackgroundColor3=T.accent},0.07)
            task.delay(0.14,function() Tw(cell,{BackgroundColor3=T.light_contrast},0.15) end)
            cb2()
        end)
        cell.MouseEnter:Connect(function() Tw(cell,{BackgroundColor3=T.dark_contrast},0.1) end)
        cell.MouseLeave:Connect(function() Tw(cell,{BackgroundColor3=T.light_contrast},0.1) end)
    end
end

-- ── Dropdown ───────────────────────────────────────────────────────
function Section:Dropdown(info)
    info = info or {}
    local name    = info.name    or info.title or "Dropdown"
    local options = info.options or {}
    local def     = info.def     or options[1] or ""
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end
    local sel     = tostring(def)
    local isOpen  = false

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,54), nil, 5)
    Stroke(row, T.border)
    Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(1,-16,0,18), UDim2.fromOffset(8,4))
    local dbox = Frame(row, T.dark_contrast, UDim2.new(1,-16,0,22), UDim2.new(0,8,1,-28), 4)
    local dboxS = Stroke(dbox, T.border)
    local disp  = Label(dbox, sel, T.textsize-1, T.textcolor, T.font,
        UDim2.new(1,-22,1,0), UDim2.fromOffset(5,0))
    local arrow = Label(dbox, "▾", T.textsize, T.textcolor, T.font,
        UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)

    local panel = Frame(self._popupRoot, T.dark_contrast, UDim2.fromOffset(10,0), nil, 5)
    panel.Visible=false; panel.ZIndex=150; panel.ClipsDescendants=true
    Stroke(panel, T.accent); List(panel,Enum.FillDirection.Vertical,2); Pad(panel,3,3,4,4)

    local function Rebuild()
        for _,c in ipairs(panel:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,opt in ipairs(options) do
            local chosen = tostring(opt)==sel
            local or2 = Frame(panel, chosen and T.light_contrast or T.dark_contrast,
                UDim2.new(1,0,0,22), nil, 4); or2.ZIndex=151
            local ors = Stroke(or2, chosen and T.accent or T.border)
            local ol  = Label(or2, tostring(opt), T.textsize-1,
                chosen and T.accent or T.textcolor, T.font,
                UDim2.new(1,-22,1,0), UDim2.fromOffset(7,0)); ol.ZIndex=152
            local ck  = Label(or2, chosen and "✔" or "", T.textsize-1, T.accent, T.font,
                UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)
            ck.ZIndex=152
            or2.MouseEnter:Connect(function()
                if tostring(opt)~=sel then Tw(or2,{BackgroundColor3=T.light_contrast},0.08) end
            end)
            or2.MouseLeave:Connect(function()
                if tostring(opt)~=sel then Tw(or2,{BackgroundColor3=T.dark_contrast},0.08) end
            end)
            or2.InputBegan:Connect(function(i2)
                if i2.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                sel=tostring(opt); disp.Text=sel; cb(sel)
                isOpen=false
                Tw(panel,{Size=UDim2.fromOffset(panel.AbsoluteSize.X,0)},0.14)
                Tw(arrow,{Rotation=0},0.14); Tw(dboxS,{Color=T.border},0.1)
                task.delay(0.15,function() panel.Visible=false end); Rebuild()
            end)
        end
    end
    Rebuild()

    local function Open()
        isOpen=true
        local w=dbox.AbsoluteSize.X; local p=dbox.AbsolutePosition
        panel.Position=UDim2.fromOffset(p.X, p.Y+dbox.AbsoluteSize.Y+3)
        panel.Size=UDim2.fromOffset(w,0); panel.Visible=true
        Tw(panel,{Size=UDim2.fromOffset(w,math.min(#options*26+10,230))},0.18)
        Tw(arrow,{Rotation=180},0.18); Tw(dboxS,{Color=T.accent},0.1)
    end
    local function Close()
        isOpen=false
        Tw(panel,{Size=UDim2.fromOffset(panel.AbsoluteSize.X,0)},0.14)
        Tw(arrow,{Rotation=0},0.14); Tw(dboxS,{Color=T.border},0.1)
        task.delay(0.15,function() panel.Visible=false end)
    end
    dbox.InputBegan:Connect(function(i)
        if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        if isOpen then Close() else Open() end
    end)
    UIS.InputBegan:Connect(function(i)
        if not isOpen or i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local m=UIS:GetMouseLocation()
        local pa=panel.AbsolutePosition; local ps=panel.AbsoluteSize
        local da=dbox.AbsolutePosition;  local ds=dbox.AbsoluteSize
        if not (m.X>=pa.X and m.X<=pa.X+ps.X and m.Y>=pa.Y and m.Y<=pa.Y+ps.Y)
        and not (m.X>=da.X and m.X<=da.X+ds.X and m.Y>=da.Y and m.Y<=da.Y+ds.Y) then
            Close()
        end
    end)
    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local obj={
        Get=function() return sel end,
        Set=function(_,v)
            if table.find(options,v) then sel=tostring(v); disp.Text=sel; Rebuild() end
        end,
        Refresh=function(_,newOpts) options=newOpts; Rebuild() end,
    }
    RegPtr(pointer,obj); return obj
end

-- ── Multibox ───────────────────────────────────────────────────────
function Section:Multibox(info)
    info = info or {}
    local name    = info.name    or info.title or "Multibox"
    local options = info.options or {}
    local def     = info.def     or {options[1]}
    local minSel  = info.min     or 0
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end
    local current = {table.unpack(def)}
    local isOpen  = false

    local function Serialize()
        local out={}
        for _,v in ipairs(options) do
            if table.find(current,v) then out[#out+1]=tostring(v) end
        end
        return table.concat(out,", ")
    end

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,54), nil, 5)
    Stroke(row, T.border)
    Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(1,-16,0,18), UDim2.fromOffset(8,4))
    local dbox = Frame(row, T.dark_contrast, UDim2.new(1,-16,0,22), UDim2.new(0,8,1,-28), 4)
    local dboxS = Stroke(dbox, T.border)
    local disp  = Label(dbox, Serialize(), T.textsize-1, T.textcolor, T.font,
        UDim2.new(1,-22,1,0), UDim2.fromOffset(5,0))
    local arrow = Label(dbox, "▾", T.textsize, T.textcolor, T.font,
        UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)

    local panel = Frame(self._popupRoot, T.dark_contrast, UDim2.fromOffset(10,0), nil, 5)
    panel.Visible=false; panel.ZIndex=150; panel.ClipsDescendants=true
    Stroke(panel,T.accent); List(panel,Enum.FillDirection.Vertical,2); Pad(panel,3,3,4,4)

    local function Rebuild()
        for _,c in ipairs(panel:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,opt in ipairs(options) do
            local chosen = table.find(current,opt)~=nil
            local or2 = Frame(panel, chosen and T.light_contrast or T.dark_contrast,
                UDim2.new(1,0,0,22), nil, 4); or2.ZIndex=151
            Stroke(or2, chosen and T.accent or T.border)
            local ol = Label(or2, tostring(opt), T.textsize-1,
                chosen and T.accent or T.textcolor, T.font,
                UDim2.new(1,-22,1,0), UDim2.fromOffset(7,0)); ol.ZIndex=152
            local ck = Label(or2, chosen and "✔" or "", T.textsize-1, T.accent, T.font,
                UDim2.fromOffset(16,22), UDim2.new(1,-18,0,0), Enum.TextXAlignment.Center)
            ck.ZIndex=152
            or2.MouseEnter:Connect(function()
                if not table.find(current,opt) then Tw(or2,{BackgroundColor3=T.light_contrast},0.08) end
            end)
            or2.MouseLeave:Connect(function()
                if not table.find(current,opt) then Tw(or2,{BackgroundColor3=T.dark_contrast},0.08) end
            end)
            or2.InputBegan:Connect(function(i2)
                if i2.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                local idx=table.find(current,opt)
                if idx then if #current>minSel then table.remove(current,idx) end
                else current[#current+1]=opt end
                disp.Text=Serialize(); cb(current); Rebuild()
            end)
        end
    end
    Rebuild()

    local function Open()
        isOpen=true
        local w=dbox.AbsoluteSize.X; local p=dbox.AbsolutePosition
        panel.Position=UDim2.fromOffset(p.X,p.Y+dbox.AbsoluteSize.Y+3)
        panel.Size=UDim2.fromOffset(w,0); panel.Visible=true
        Tw(panel,{Size=UDim2.fromOffset(w,math.min(#options*26+10,230))},0.18)
        Tw(arrow,{Rotation=180},0.18); Tw(dboxS,{Color=T.accent},0.1)
    end
    local function Close()
        isOpen=false
        Tw(panel,{Size=UDim2.fromOffset(panel.AbsoluteSize.X,0)},0.14)
        Tw(arrow,{Rotation=0},0.14); Tw(dboxS,{Color=T.border},0.1)
        task.delay(0.15,function() panel.Visible=false end)
    end
    dbox.InputBegan:Connect(function(i)
        if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        if isOpen then Close() else Open() end
    end)
    UIS.InputBegan:Connect(function(i)
        if not isOpen or i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local m=UIS:GetMouseLocation()
        local pa=panel.AbsolutePosition; local ps=panel.AbsoluteSize
        local da=dbox.AbsolutePosition;  local ds=dbox.AbsoluteSize
        if not (m.X>=pa.X and m.X<=pa.X+ps.X and m.Y>=pa.Y and m.Y<=pa.Y+ps.Y)
        and not (m.X>=da.X and m.X<=da.X+ds.X and m.Y>=da.Y and m.Y<=da.Y+ds.Y) then
            Close()
        end
    end)
    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local obj={
        Get=function() return current end,
        Set=function(_,t)
            if type(t)=="table" then current=t; disp.Text=Serialize(); Rebuild() end
        end,
    }
    RegPtr(pointer,obj); return obj
end

-- ── Keybind (standalone) ───────────────────────────────────────────
function Section:Keybind(info)
    info = info or {}
    local name    = info.name    or info.title or "Keybind"
    local kbDef   = info.def
    local kbMode  = info.mode    or "Always"
    local kbName  = info.keybindname or name
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end

    local ALLOWED_KEYS  = {"Q","W","E","R","T","Y","U","I","O","P","A","S","D","F","G","H","J","K","L","Z","X","C","V","B","N","M","One","Two","Three","Four","Five","Six","Seven","Eight","Nine","Insert","Tab","Home","End","LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"}
    local ALLOWED_MOUSE = {"MouseButton1","MouseButton2","MouseButton3"}
    local SHORT = {MouseButton1="MB1",MouseButton2="MB2",MouseButton3="MB3",Insert="Ins",LeftAlt="LAlt",LeftControl="LC",LeftShift="LS",RightAlt="RAlt",RightControl="RC",RightShift="RS",CapsLock="Caps"}
    local current={}; local selecting=false; local active=(kbMode=="Always")
    local function Sh(s) return SHORT[s] or s end

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,32), nil, 5)
    Stroke(row, T.border)
    Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(1,-100,1,0), UDim2.fromOffset(8,0))
    local kbox = Frame(row, T.dark_contrast, UDim2.fromOffset(86,22), UDim2.new(1,-94,0.5,-11), 4)
    local kboxS = Stroke(kbox, T.border)
    local klbl  = Label(kbox, "...", T.textsize-2, T.accent, T.font,
        nil, nil, Enum.TextXAlignment.Center)

    -- Mode popup
    local modePop = Frame(self._popupRoot, T.dark_contrast,
        UDim2.fromOffset(80,0), nil, 5)
    modePop.Visible=false; modePop.ZIndex=160; modePop.ClipsDescendants=true
    Stroke(modePop, T.accent); List(modePop,Enum.FillDirection.Vertical,1); Pad(modePop,3,3,4,4)
    local modeOpen=false

    local function RebuildModes()
        for _,c in ipairs(modePop:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,m2 in ipairs({"Always","Toggle","Hold"}) do
            local chosen=m2==kbMode
            local mr=Frame(modePop, chosen and T.light_contrast or T.dark_contrast,
                UDim2.new(1,0,0,20), nil, 4); mr.ZIndex=161
            Stroke(mr, chosen and T.accent or T.border)
            local ml=Label(mr, m2, T.textsize-1,
                chosen and T.accent or T.textcolor, T.font,
                nil, nil, Enum.TextXAlignment.Center); ml.ZIndex=162
            mr.InputBegan:Connect(function(i3)
                if i3.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                kbMode=m2; active=(kbMode=="Always")
                modeOpen=false
                Tw(modePop,{Size=UDim2.fromOffset(80,0)},0.12)
                task.delay(0.13,function() modePop.Visible=false end)
                RebuildModes()
                if current[1] then cb(Enum[current[1]][current[2]],active) end
            end)
        end
    end
    RebuildModes()

    local function Chg(inp)
        if not inp or not inp.EnumType then return false end
        local n2=inp.Name
        if inp.EnumType==Enum.KeyCode and table.find(ALLOWED_KEYS,n2) then
            current={"KeyCode",n2}
        elseif inp.EnumType==Enum.UserInputType and table.find(ALLOWED_MOUSE,n2) then
            current={"UserInputType",n2}
        else return false end
        klbl.Text="["..Sh(current[2]).."]"; return true
    end
    if kbDef then Chg(kbDef) end

    kbox.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            selecting=true; klbl.Text="[...]"
            klbl.TextColor3=Color3.fromRGB(255,190,40); Tw(kboxS,{Color=T.accent},0.1)
        elseif i.UserInputType==Enum.UserInputType.MouseButton2 then
            if modeOpen then
                modeOpen=false
                Tw(modePop,{Size=UDim2.fromOffset(80,0)},0.12)
                task.delay(0.13,function() modePop.Visible=false end)
            else
                modeOpen=true
                local ka=kbox.AbsolutePosition; local ks=kbox.AbsoluteSize
                modePop.Position=UDim2.fromOffset(ka.X+ks.X+4,ka.Y)
                modePop.Size=UDim2.fromOffset(80,0); modePop.Visible=true
                Tw(modePop,{Size=UDim2.fromOffset(80,68)},0.15)
            end
        end
    end)
    UIS.InputBegan:Connect(function(i)
        if current[1] and current[2] and not selecting then
            local hit=(current[1]=="KeyCode" and i.KeyCode==Enum.KeyCode[current[2]])
                    or(current[1]=="UserInputType" and i.UserInputType==Enum.UserInputType[current[2]])
            if hit then
                if kbMode=="Toggle" then active=not active; cb(Enum[current[1]][current[2]],active)
                elseif kbMode=="Hold" then active=true; cb(Enum[current[1]][current[2]],active) end
            end
        end
        if selecting then
            local k=i.KeyCode.Name~="Unknown" and i.KeyCode or i.UserInputType
            if Chg(k) then
                selecting=false; active=(kbMode=="Always")
                klbl.TextColor3=T.accent; Tw(kboxS,{Color=T.border},0.1)
                if current[1] then cb(Enum[current[1]][current[2]],active) end
            end
        end
        if modeOpen and i.UserInputType==Enum.UserInputType.MouseButton1 then
            local m2=UIS:GetMouseLocation()
            local pa=modePop.AbsolutePosition; local ps=modePop.AbsoluteSize
            if not (m2.X>=pa.X and m2.X<=pa.X+ps.X and m2.Y>=pa.Y and m2.Y<=pa.Y+ps.Y) then
                modeOpen=false
                Tw(modePop,{Size=UDim2.fromOffset(80,0)},0.12)
                task.delay(0.13,function() modePop.Visible=false end)
            end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if kbMode=="Hold" and current[1] and current[2] then
            local hit=(current[1]=="KeyCode" and i.KeyCode==Enum.KeyCode[current[2]])
                    or(current[1]=="UserInputType" and i.UserInputType==Enum.UserInputType[current[2]])
            if hit then active=false; cb(Enum[current[1]][current[2]],active) end
        end
    end)
    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)

    local obj={
        Get=function() return current end,
        Set=function(_,t) if t then current=t; klbl.Text="["..Sh(t[2]).."]" end end,
        Active=function() return active end,
    }
    RegPtr(pointer,obj); return obj
end

-- ── Colorpicker (standalone) ───────────────────────────────────────
function Section:Colorpicker(info)
    info = info or {}
    local name    = info.name    or info.title or "Color"
    local cpLabel = info.info    or info.Info  or name
    local def     = info.def     or Color3.fromRGB(255,0,0)
    local defAlp  = info.transparency or info.alpha
    local pointer = info.pointer or info.flag
    local cb      = info.callback or function() end

    local row = Frame(self._content, T.light_contrast, UDim2.new(1,0,0,32), nil, 5)
    Stroke(row, T.border)
    Label(row, name, T.textsize, T.textcolor, T.font,
        UDim2.new(1,-54,1,0), UDim2.fromOffset(8,0))

    local sw1 = Frame(row, def, UDim2.fromOffset(36,20), UDim2.new(1,-44,0.5,-10), 4)
    local ctrl = MakeColorpicker(sw1, self._popupRoot, cpLabel, def, defAlp, cb)
    RegPtr(pointer, ctrl)

    -- ── colorpicker:Colorpicker ─────────────────────────────────────
    function ctrl:Colorpicker(ci2)
        ci2 = ci2 or {}
        local lbl2  = ci2.info  or ci2.Info  or name.." 2"
        local def2  = ci2.def   or Color3.fromRGB(255,0,0)
        local alp2  = ci2.transparency or ci2.alpha
        local ptr2  = ci2.pointer or ci2.flag
        local cb2   = ci2.callback or function() end

        sw1.Position = UDim2.new(1,-82,0.5,-10)
        local sw2 = Frame(row, def2, UDim2.fromOffset(36,20), UDim2.new(1,-44,0.5,-10), 4)
        local c2  = MakeColorpicker(sw2, self._popupRoot, lbl2, def2, alp2, cb2)
        RegPtr(ptr2, c2)
        return c2
    end

    row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=T.dark_contrast},0.1) end)
    row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=T.light_contrast},0.1) end)
    return ctrl
end

-- ── ConfigBox ──────────────────────────────────────────────────────
function Section:ConfigBox()
    local SLOTS=8; local current=1
    local box = Frame(self._content, T.light_contrast,
        UDim2.new(1,0,0,SLOTS*22+8), nil, 5)
    Stroke(box, T.border); Pad(box,4,4,4,4); List(box,Enum.FillDirection.Vertical,2)
    local slots={}
    for i=1,SLOTS do
        local sr=Frame(box, T.dark_contrast, UDim2.new(1,0,0,18), nil, 3)
        local ss=Stroke(sr, i==1 and T.accent or T.border)
        local sl=Label(sr, "Slot "..i, T.textsize-2,
            i==1 and T.accent or T.textdim, T.font, nil, nil, Enum.TextXAlignment.Center)
        sr.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if slots[current] then
                Tw(slots[current].s,{Color=T.border},0.1)
                Tw(slots[current].l,{TextColor3=T.textdim},0.1)
            end
            current=i; Tw(ss,{Color=T.accent},0.1); Tw(sl,{TextColor3=T.accent},0.1)
        end)
        sr.MouseEnter:Connect(function()
            if i~=current then Tw(sr,{BackgroundColor3=T.light_contrast},0.08) end
        end)
        sr.MouseLeave:Connect(function()
            if i~=current then Tw(sr,{BackgroundColor3=T.dark_contrast},0.08) end
        end)
        slots[i]={row=sr,s=ss,l=sl}
    end
    return {
        Get=function() return current end,
        Set=function(_,n)
            if n<1 or n>SLOTS then return end
            if slots[current] then slots[current].s.Color=T.border; slots[current].l.TextColor3=T.textdim end
            current=n; slots[n].s.Color=T.accent; slots[n].l.TextColor3=T.accent
        end,
    }
end

-- ════════════════════════════════════════════════════════════════════
-- PAGE
-- ════════════════════════════════════════════════════════════════════
local Page={}; Page.__index=Page

-- Section (single, left or right column)
function Page:Section(info)
    info = info or {}
    local name = info.name or info.title or "Section"
    local side = (info.side or "left"):lower()
    local col  = side=="right" and self._rightCol or self._leftCol

    local card = Frame(col, Color3.fromRGB(14,14,14), UDim2.new(1,0,0,0), nil, 6)
    card.AutomaticSize = Enum.AutomaticSize.Y
    Stroke(card, T.accent)

    local hdr = Frame(card, Color3.fromRGB(10,10,10), UDim2.new(1,0,0,24), nil, 0); Corner(hdr,6)
    Frame(hdr, T.accent, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)
    Label(hdr, name:upper(), T.textsize-2, T.accent, T.fontBold,
        UDim2.new(1,-10,1,0), UDim2.fromOffset(8,0))

    local sf = ScrollFrame(card)
    List(sf,Enum.FillDirection.Vertical,4); Pad(sf,6,6,6,6)

    return setmetatable({_content=sf, _popupRoot=self._popupRoot}, Section)
end

-- MultiSection (tabbed)
function Page:MultiSection(info)
    info = info or {}
    local tabs = info.sections or info.tabs or {"Tab1","Tab2"}
    local side = (info.side or "left"):lower()
    local h    = info.size or 200
    local col  = side=="right" and self._rightCol or self._leftCol

    local card = Frame(col, Color3.fromRGB(14,14,14), UDim2.new(1,0,0,h), nil, 6)
    Stroke(card, T.accent)
    Frame(card, T.accent, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)

    local tabBar = Frame(card, Color3.fromRGB(10,10,10), UDim2.new(1,0,0,26), nil, 0); Corner(tabBar,6)
    Stroke(tabBar, T.border); List(tabBar,Enum.FillDirection.Horizontal,1)

    local host = Frame(card, Color3.fromRGB(0,0,0),
        UDim2.new(1,0,1,-28), UDim2.fromOffset(0,28), 0)
    host.BackgroundTransparency=1; host.ClipsDescendants=true

    local secs={}; local tbs={}; local activeIdx=1

    for i,tname in ipairs(tabs) do
        local tb  = Frame(tabBar, i==1 and Color3.fromRGB(26,26,26) or T.dark_contrast,
            UDim2.new(1/#tabs,-1,1,0), nil, 4)
        local tbS = Stroke(tb, i==1 and T.accent or T.border)
        local tl  = Label(tb, tname, T.textsize-2,
            i==1 and T.accent or T.textdim, T.font, nil, nil, Enum.TextXAlignment.Center)

        local sf = ScrollFrame(host)
        sf.Size=UDim2.new(1,0,1,0); sf.Visible=(i==1)
        List(sf,Enum.FillDirection.Vertical,4); Pad(sf,6,6,6,6)

        secs[i]=setmetatable({_content=sf, _popupRoot=self._popupRoot}, Section)
        tbs[i]={btn=tb, lbl=tl, stroke=tbS}

        tb.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            local old=tbs[activeIdx]
            Tw(old.btn,{BackgroundColor3=T.dark_contrast},0.1)
            Tw(old.lbl,{TextColor3=T.textdim},0.1)
            Tw(old.stroke,{Color=T.border},0.1)
            for _,sf2 in ipairs(host:GetChildren()) do
                if sf2:IsA("ScrollingFrame") then sf2.Visible=false end
            end
            activeIdx=i
            Tw(tb,{BackgroundColor3=Color3.fromRGB(26,26,26)},0.1)
            Tw(tl,{TextColor3=T.accent},0.1)
            Tw(tbS,{Color=T.accent},0.1)
            sf.Visible=true
        end)
    end
    return table.unpack(secs)
end

-- ════════════════════════════════════════════════════════════════════
-- WATERMARK
-- ════════════════════════════════════════════════════════════════════
local function MakeWatermark(root, accent2)
    local wm={visible=false, _label="SpixLib"}
    local frame=Frame(root, Color3.fromRGB(13,13,13),
        UDim2.fromOffset(200,22), UDim2.fromOffset(10,10), 4)
    frame.Visible=false; frame.ZIndex=50
    Stroke(frame, accent2)
    Frame(frame, accent2, UDim2.fromOffset(2,22), UDim2.fromOffset(0,0), 0).ZIndex=51
    local lbl=Label(frame, "SpixLib", T.textsize-1, Color3.fromRGB(215,215,215), T.font,
        UDim2.new(1,-8,1,0), UDim2.fromOffset(8,0)); lbl.ZIndex=51

    local fps,ping=0,0
    RS.RenderStepped:Connect(function(dt) fps=math.round(1/dt) end)
    task.spawn(function()
        while true do task.wait(0.5)
            pcall(function()
                ping=tonumber(tostring(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()):match("%d+")) or 0
            end)
            lbl.Text=string.format("%s  |  fps: %d  |  ping: %d", wm._label, fps, ping)
            local tw=TextSvc:GetTextSize(lbl.Text,T.textsize-1,T.font,Vector2.new(9999,22)).X
            frame.Size=UDim2.fromOffset(tw+18,22)
        end
    end)

    function wm:Update(t2,v)
        if t2=="Visible" then wm.visible=v; frame.Visible=v
        elseif t2=="Name" then wm._label=v
        elseif t2=="Offset" then frame.Position=UDim2.fromOffset(v.X,v.Y) end
    end
    return wm
end

-- ════════════════════════════════════════════════════════════════════
-- KEYBINDS LIST
-- ════════════════════════════════════════════════════════════════════
local function MakeKeybindsList(root, accent2)
    local kbl={visible=false, _items={}}
    local frame=Frame(root, Color3.fromRGB(13,13,13),
        UDim2.fromOffset(160,26), UDim2.fromOffset(10,40), 4)
    frame.Visible=false; frame.ZIndex=50
    Stroke(frame, accent2)
    local hdr=Frame(frame, Color3.fromRGB(10,10,10), UDim2.new(1,0,0,24), nil, 0)
    hdr.ZIndex=51
    local hl=Label(hdr,"— Keybinds —",T.textsize-1,Color3.fromRGB(170,170,170),T.font,
        nil,nil,Enum.TextXAlignment.Center); hl.ZIndex=52
    List(frame,Enum.FillDirection.Vertical,0)

    local function Resize()
        local n=0; for _ in pairs(kbl._items) do n=n+1 end
        frame.Size=UDim2.fromOffset(160, 26+n*20+4)
    end

    function kbl:Add(kname, kval)
        if kbl._items[kname] then return end
        local iRow=Frame(frame,Color3.fromRGB(19,19,19),UDim2.new(1,0,0,20),nil,0)
        iRow.ZIndex=51
        local nl=Label(iRow,kname,T.textsize-2,Color3.fromRGB(200,200,200),T.font,
            UDim2.new(0.6,0,1,0), UDim2.fromOffset(5,0)); nl.ZIndex=52
        local vl=Label(iRow,"["..kval.."]",T.textsize-2,accent2,T.font,
            UDim2.new(0.38,0,1,0),UDim2.new(0.6,0,0,0),Enum.TextXAlignment.Right); vl.ZIndex=52
        kbl._items[kname]={row=iRow}; Resize()
    end
    function kbl:Remove(kname)
        if kbl._items[kname] then kbl._items[kname].row:Destroy(); kbl._items[kname]=nil; Resize() end
    end
    function kbl:Update(t2,v)
        if t2=="Visible" then kbl.visible=v; frame.Visible=v end
    end
    return kbl
end

-- ════════════════════════════════════════════════════════════════════
-- CURSOR  (Drawing API — gracefully degraded if not available)
-- ════════════════════════════════════════════════════════════════════
local function MakeCursor(accent2)
    local hasDrawing = pcall(function() local _=Drawing end)
    if not hasDrawing then return {cursor=nil, cursor_inline=nil} end
    UIS.MouseIconEnabled = false
    local outer=Drawing.new("Triangle")
    outer.Filled=false; outer.Thickness=2; outer.Color=Color3.fromRGB(0,0,0)
    outer.Visible=true; outer.ZIndex=9999
    local inner=Drawing.new("Triangle")
    inner.Filled=true; inner.Thickness=0; inner.Color=accent2
    inner.Visible=true; inner.ZIndex=9999
    RS.RenderStepped:Connect(function()
        local m=UIS:GetMouseLocation()
        outer.PointA=Vector2.new(m.X,m.Y); outer.PointB=Vector2.new(m.X+16,m.Y+6); outer.PointC=Vector2.new(m.X+6,m.Y+16)
        inner.PointA=outer.PointA; inner.PointB=outer.PointB; inner.PointC=outer.PointC
    end)
    return {cursor=outer, cursor_inline=inner}
end

-- ════════════════════════════════════════════════════════════════════
-- LIBRARY  (main entry)
-- ════════════════════════════════════════════════════════════════════
function SpixLib.new(info)
    info = info or {}
    local winName = info.name   or info.Name   or "UI"
    local winSize = info.size   or info.Size   or Vector2.new(620,560)
    local accent2 = info.accent or info.Accent or T.accent

    -- Patch theme
    T.accent = accent2
    T.border = Color3.new(
        math.clamp(accent2.R*0.35+0.16,0,1),
        math.clamp(accent2.G*0.35+0.16,0,1),
        math.clamp(accent2.B*0.35+0.16,0,1)
    )

    -- ── ScreenGui ──────────────────────────────────────────────
    local gui = Instance.new("ScreenGui")
    gui.Name="SpixLib_"..winName; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=999
    local ok=false
    pcall(function() gui.Parent=game:GetService("CoreGui"); ok=true end)
    if not ok then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

    local TITLE_H=38; local TABS_H=32

    -- ── Main window ────────────────────────────────────────────
    local win = Frame(gui, T.panel,
        UDim2.fromOffset(winSize.X, winSize.Y),
        UDim2.fromOffset(
            math.floor((workspace.CurrentCamera.ViewportSize.X-winSize.X)/2),
            math.floor((workspace.CurrentCamera.ViewportSize.Y-winSize.Y)/2)
        ), 8)
    win.ClipsDescendants = false
    Stroke(win, T.border)
    -- Accent bar at top
    local abar=Frame(win, accent2, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), 0)
    abar.ZIndex=4; Stroke(abar,accent2,0.4)

    -- ── Title bar ──────────────────────────────────────────────
    local titleBar=Frame(win, Color3.fromRGB(12,12,12),
        UDim2.new(1,0,0,TITLE_H), UDim2.new(0,0,0,0), 0); Corner(titleBar,8)
    titleBar.ZIndex=3; Stroke(titleBar,T.border)
    Label(titleBar, winName, T.textsize+1, T.textcolor, T.fontBold,
        UDim2.new(1,-80,1,0), UDim2.fromOffset(12,0)).ZIndex=4

    -- ── Tab strip ──────────────────────────────────────────────
    local tabStrip=Frame(win, Color3.fromRGB(11,11,11),
        UDim2.new(1,0,0,TABS_H), UDim2.fromOffset(0,TITLE_H), 0)
    tabStrip.ZIndex=3; Stroke(tabStrip,T.border)
    List(tabStrip,Enum.FillDirection.Horizontal,3); Pad(tabStrip,4,4,5,5)

    -- ── Content area ───────────────────────────────────────────
    local HEADER_H=TITLE_H+TABS_H
    local content=Frame(win, Color3.fromRGB(16,16,16),
        UDim2.new(1,0,1,-HEADER_H), UDim2.fromOffset(0,HEADER_H), 0)
    content.ClipsDescendants=true

    -- ── Window object ──────────────────────────────────────────
    local window={
        _gui=gui, _win=win, _tabStrip=tabStrip, _content=content,
        _pages={}, _activePage=nil,
        uibind=Enum.KeyCode.RightControl, isVisible=true,
    }

    -- Drag
    do
        local drag,ds,sp=false,nil,nil
        titleBar.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                drag=true; ds=i.Position; sp=win.Position end
        end)
        titleBar.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d=i.Position-ds
                win.Position=UDim2.fromOffset(sp.X.Offset+d.X, sp.Y.Offset+d.Y)
            end
        end)
    end

    -- Toggle visibility
    UIS.InputBegan:Connect(function(i,gp)
        if gp then return end
        if i.KeyCode==window.uibind then
            window.isVisible=not window.isVisible
            Tw(win, {BackgroundTransparency=window.isVisible and 0 or 1}, 0.18)
        end
    end)

    -- Open anim
    win.Size=UDim2.fromOffset(winSize.X,0)
    Tw(win,{Size=UDim2.fromOffset(winSize.X,winSize.Y)},0.35,Enum.EasingStyle.Quint)

    -- ── Page ───────────────────────────────────────────────────
    function window:Page(pi)
        pi=pi or {}
        local pname=pi.name or pi.title or "Page"

        local tb=Frame(tabStrip, Color3.fromRGB(16,16,16), UDim2.fromOffset(0,TABS_H-8), nil, 4)
        tb.AutomaticSize=Enum.AutomaticSize.X
        local tbS=Stroke(tb, T.border)
        local tl=Label(tb, pname, T.textsize-1, T.textdim, T.font,
            UDim2.new(0,0,1,0), nil, Enum.TextXAlignment.Center)
        tl.AutomaticSize=Enum.AutomaticSize.X; Pad(tl,0,0,10,10)

        local pf=Frame(content, Color3.fromRGB(0,0,0), UDim2.new(1,0,1,0), nil, 0)
        pf.BackgroundTransparency=1; pf.Visible=false

        local cols=Instance.new("Frame")
        cols.BackgroundTransparency=1; cols.BorderSizePixel=0
        cols.Size=UDim2.new(1,0,1,0); cols.Parent=pf
        List(cols,Enum.FillDirection.Horizontal,6); Pad(cols,6,6,6,6)

        local function mkCol()
            local c=Frame(cols, Color3.fromRGB(0,0,0), UDim2.new(0.5,-3,1,0), nil, 0)
            c.BackgroundTransparency=1; c.AutomaticSize=Enum.AutomaticSize.Y
            List(c,Enum.FillDirection.Vertical,6); return c
        end

        local pageObj=setmetatable({
            _popupRoot=gui,
            _leftCol=mkCol(), _rightCol=mkCol(),
            _frame=pf, _tb=tb, _tl=tl, _tbS=tbS,
        }, Page)

        table.insert(window._pages, pageObj)

        local function ShowPage()
            if window._activePage then
                window._activePage._frame.Visible=false
                local old=window._activePage
                Tw(old._tb,{BackgroundColor3=Color3.fromRGB(16,16,16)},0.12)
                Tw(old._tl,{TextColor3=T.textdim},0.12)
                Tw(old._tbS,{Color=T.border},0.12)
            end
            window._activePage=pageObj; pf.Visible=true
            Tw(tb,{BackgroundColor3=Color3.fromRGB(30,30,30)},0.12)
            Tw(tl,{TextColor3=accent2},0.12)
            Tw(tbS,{Color=accent2},0.12)
        end

        tb.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then ShowPage() end
        end)
        tb.MouseEnter:Connect(function()
            if window._activePage~=pageObj then Tw(tb,{BackgroundColor3=Color3.fromRGB(22,22,22)},0.1) end
        end)
        tb.MouseLeave:Connect(function()
            if window._activePage~=pageObj then Tw(tb,{BackgroundColor3=Color3.fromRGB(16,16,16)},0.1) end
        end)
        if #window._pages==1 then task.defer(ShowPage) end
        return pageObj
    end

    -- ── Watermark ──────────────────────────────────────────────
    function window:Watermark(wi)
        wi=wi or {}
        local wm=MakeWatermark(gui, accent2)
        wm._label=wi.name or wi.Name or winName
        window.watermark=wm; return wm
    end

    -- ── KeybindsList ───────────────────────────────────────────
    function window:KeybindsList()
        local kbl=MakeKeybindsList(gui, accent2)
        window.keybindslist=kbl; return kbl
    end

    -- ── Cursor ─────────────────────────────────────────────────
    function window:Cursor()
        local c=MakeCursor(accent2)
        window._cursor=c; return c
    end

    -- ── GetConfig ──────────────────────────────────────────────
    function window:GetConfig()
        local cfg={}
        for k,obj in pairs(Pointers) do
            local v=obj:Get()
            if typeof(v)=="Color3" then
                local h,s,vv=v:ToHSV()
                cfg[k]={t="Color3",H=h,S=s,V=vv}
            elseif type(v)=="table" then
                cfg[k]={t="table",v=v}
            else
                cfg[k]={t="val",v=v}
            end
        end
        return HS:JSONEncode(cfg)
    end

    -- ── LoadConfig ─────────────────────────────────────────────
    function window:LoadConfig(json)
        local ok2,cfg=pcall(function() return HS:JSONDecode(json) end)
        if not ok2 then return end
        for k,data in pairs(cfg) do
            if Pointers[k] then
                if data.t=="Color3" then Pointers[k]:Set(Color3.fromHSV(data.H,data.S,data.V))
                else Pointers[k]:Set(data.v) end
            end
        end
    end

    -- ── File helpers ───────────────────────────────────────────
    function window:SaveToFile(path)
        pcall(function() writefile(path, window:GetConfig()) end)
    end
    function window:LoadFromFile(path)
        local ok2,data=pcall(function() return readfile(path) end)
        if ok2 and data then window:LoadConfig(data) end
    end

    -- ── Unload ─────────────────────────────────────────────────
    function window:Unload()
        if window._cursor then
            pcall(function()
                if window._cursor.cursor then window._cursor.cursor:Remove() end
                if window._cursor.cursor_inline then window._cursor.cursor_inline:Remove() end
                UIS.MouseIconEnabled=true
            end)
        end
        gui:Destroy()
    end

    return window
end

return SpixLib
