-- ============================================================
--  JumpingJackBot.lua
--  Loadstring compatible — works in any Roblox game via executor
--
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/davinsotuffczpro/Roblox-JJBot/main/jjbot.lua"))()
-- ============================================================

-- ── Safety: prevent duplicate GUIs ───────────────────────────
local existingGui = game:GetService("CoreGui"):FindFirstChild("JumpingJackBot")
    or game:GetService("Players").LocalPlayer
        :FindFirstChild("PlayerGui")
        and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("JumpingJackBot")

if existingGui then existingGui:Destroy() end

-- ── Services ──────────────────────────────────────────────────
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local localPlayer   = Players.LocalPlayer

-- Executors run as LocalScripts so PlayerGui is accessible,
-- but parenting to CoreGui is more reliable across games.
local guiParent = (syn and syn.protect_gui and game:GetService("CoreGui"))
    or (gethui and gethui())
    or (game:GetService("CoreGui"))

-- ── Number-to-words ───────────────────────────────────────────
local ONES = {
    [0]="",      [1]="One",      [2]="Two",       [3]="Three",
    [4]="Four",  [5]="Five",     [6]="Six",        [7]="Seven",
    [8]="Eight", [9]="Nine",     [10]="Ten",       [11]="Eleven",
    [12]="Twelve",[13]="Thirteen",[14]="Fourteen", [15]="Fifteen",
    [16]="Sixteen",[17]="Seventeen",[18]="Eighteen",[19]="Nineteen",
}
local TENS = {
    [2]="Twenty",[3]="Thirty",[4]="Forty",[5]="Fifty",
    [6]="Sixty",[7]="Seventy",[8]="Eighty",[9]="Ninety",
}

local function toWords(n)
    if n == 0 then return "Zero" end
    local r = ""
    if n >= 1000000 then r = r..toWords(math.floor(n/1000000)).." Million "; n = n%1000000 end
    if n >= 1000    then r = r..toWords(math.floor(n/1000)).." Thousand ";   n = n%1000    end
    if n >= 100     then r = r..ONES[math.floor(n/100)].." Hundred ";        n = n%100     end
    if n >= 20 then
        r = r..TENS[math.floor(n/10)]..(ONES[n%10] ~= "" and "-"..ONES[n%10] or "")
    elseif n > 0 then
        r = r..ONES[n]
    end
    return r:match("^%s*(.-)%s*$")
end

-- ── Sequence builders ─────────────────────────────────────────
local function buildHell(count)
    local seq = {}
    for i = 1, count do
        local word = toWords(i):upper():gsub("[^A-Z]","")
        for j = 1, #word do table.insert(seq, word:sub(j,j)) end
        table.insert(seq, word)
    end
    return seq
end

local function buildGrammar(count)
    local seq = {}
    for i = 1, count do table.insert(seq, toWords(i)..".") end
    return seq
end

local function buildJJ(count)
    local seq = {}
    for i = 1, count do table.insert(seq, toWords(i):upper()) end
    return seq
end

-- ── Chat sender ───────────────────────────────────────────────
-- Tries multiple methods so it works across different games
-- and chat system versions.
local function sendChat(msg)
    -- Method 1: Default Roblox chat (most games)
    local ok = pcall(function()
        game:GetService("ReplicatedStorage")
            :WaitForChild("DefaultChatSystemChatEvents", 2)
            :WaitForChild("SayMessageRequest", 2)
            :FireServer(msg, "All")
    end)
    if ok then return end

    -- Method 2: TextChatService (newer games using the new chat)
    ok = pcall(function()
        local tcs = game:GetService("TextChatService")
        local channel = tcs:FindFirstChild("TextChannels")
            and tcs.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel:SendAsync(msg)
        end
    end)
    if ok then return end

    -- Method 3: Legacy Chat service bubble
    pcall(function()
        local head = localPlayer.Character
            and localPlayer.Character:FindFirstChild("Head")
        if head then
            game:GetService("Chat"):Chat(head, msg, Enum.ChatColor.White)
        end
    end)
end

-- ── Bot state ─────────────────────────────────────────────────
local running    = false
local stopSignal = false

-- ── Colours ───────────────────────────────────────────────────
local BG      = Color3.fromRGB(10,  10,  15)
local SURFACE = Color3.fromRGB(17,  17,  24)
local SURF2   = Color3.fromRGB(24,  24,  31)
local BORDER  = Color3.fromRGB(42,  42,  58)
local ACCENT  = Color3.fromRGB(0,   255, 231)
local MUTED   = Color3.fromRGB(85,  85,  112)
local SUCCESS = Color3.fromRGB(0,   255, 153)
local DANGER  = Color3.fromRGB(255, 79,  123)
local WHITE   = Color3.fromRGB(232, 232, 240)

-- ── GUI helpers ───────────────────────────────────────────────
local function makeCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or BORDER
    s.Thickness = thick or 1
    s.Parent = parent
    return s
end

local function makePad(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

local function makeList(parent, dir, padding, hAlign, vAlign)
    local l = Instance.new("UIListLayout")
    l.FillDirection        = dir or Enum.FillDirection.Vertical
    l.SortOrder            = Enum.SortOrder.LayoutOrder
    l.Padding               = UDim.new(0, padding or 0)
    l.HorizontalAlignment   = hAlign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment     = vAlign or Enum.VerticalAlignment.Top
    l.Parent = parent
    return l
end

-- ── Build ScreenGui ───────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "JumpingJackBot"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder     = 999
-- protect_gui for Synapse/other executors
if syn and syn.protect_gui then syn.protect_gui(screenGui) end
screenGui.Parent = guiParent

-- Outer frame
local main = Instance.new("Frame")
main.Name               = "Main"
main.Size               = UDim2.new(0, 310, 0, 420)
main.Position           = UDim2.new(0, 16, 0.5, -210)
main.BackgroundColor3   = BG
main.BorderSizePixel    = 0
makeCorner(main, 10)
makeStroke(main, BORDER)
makePad(main, 14, 14, 12, 14)
makeList(main, Enum.FillDirection.Vertical, 0)
main.Parent = screenGui

-- ── Drag to move ─────────────────────────────────────────────
do
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = main.Position
        end
    end)
    main.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ── Title bar ─────────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.BackgroundTransparency = 1
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.LayoutOrder = 1
makeList(titleBar, Enum.FillDirection.Horizontal, 0,
    Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
titleBar.Parent = main

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "JUMPING JACK BOT"
titleLabel.TextColor3 = ACCENT
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Size = UDim2.new(1, -30, 1, 0)
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = MUTED
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Size = UDim2.new(0, 28, 1, 0)
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- ── Divider helper ────────────────────────────────────────────
local function divider(order)
    local d = Instance.new("Frame")
    d.BackgroundColor3 = BORDER
    d.BorderSizePixel  = 0
    d.Size = UDim2.new(1, 0, 0, 1)
    d.LayoutOrder = order
    d.Parent = main
    return d
end

-- ── Section label helper ──────────────────────────────────────
local function sectionLabel(text, order)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = MUTED
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, 18)
    l.LayoutOrder = order
    l.Parent = main
    return l
end

-- ── Mode buttons ──────────────────────────────────────────────
divider(2)
sectionLabel("MODE", 3)

local modeFrame = Instance.new("Frame")
modeFrame.BackgroundTransparency = 1
modeFrame.Size = UDim2.new(1, 0, 0, 52)
modeFrame.LayoutOrder = 4
makeList(modeFrame, Enum.FillDirection.Horizontal, 5,
    Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
modeFrame.Parent = main

local MODES = {
    { id="hell",    label="Hell Jacks",    sub="O→N→E→ONE" },
    { id="grammar", label="Grammar Jacks", sub="One.→Two."  },
    { id="jj",      label="Jump Jacks",    sub="ONE→TWO"    },
}

local selectedMode = "hell"
local modeBtns = {}

for i, m in ipairs(MODES) do
    local btn = Instance.new("TextButton")
    btn.Name = m.id
    btn.Size = UDim2.new(0, 91, 0, 48)
    btn.BackgroundColor3 = SURF2
    btn.BackgroundTransparency = 0.3
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    makeCorner(btn, 6)
    local stroke = makeStroke(btn, BORDER)

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, 0, 1, 0)
    inner.Parent = btn
    makeList(inner, Enum.FillDirection.Vertical, 2,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

    local topL = Instance.new("TextLabel")
    topL.BackgroundTransparency = 1
    topL.Text = m.label
    topL.TextColor3 = MUTED
    topL.TextSize = 10
    topL.Font = Enum.Font.GothamBold
    topL.TextXAlignment = Enum.TextXAlignment.Center
    topL.Size = UDim2.new(1, 0, 0, 14)
    topL.Parent = inner

    local subL = Instance.new("TextLabel")
    subL.BackgroundTransparency = 1
    subL.Text = m.sub
    subL.TextColor3 = MUTED
    subL.TextSize = 9
    subL.Font = Enum.Font.GothamMedium
    subL.TextXAlignment = Enum.TextXAlignment.Center
    subL.Size = UDim2.new(1, 0, 0, 12)
    subL.Parent = inner

    modeBtns[m.id] = { btn=btn, stroke=stroke, topL=topL, subL=subL }
    btn.Parent = modeFrame
end

local function setMode(id)
    selectedMode = id
    for mid, obj in pairs(modeBtns) do
        if mid == id then
            obj.btn.BackgroundTransparency = 0.85
            obj.btn.BackgroundColor3 = ACCENT
            obj.stroke.Color = ACCENT
            obj.topL.TextColor3 = ACCENT
            obj.subL.TextColor3 = Color3.fromRGB(0, 180, 160)
        else
            obj.btn.BackgroundTransparency = 0.3
            obj.btn.BackgroundColor3 = SURF2
            obj.stroke.Color = BORDER
            obj.topL.TextColor3 = MUTED
            obj.subL.TextColor3 = MUTED
        end
    end
end

for _, m in ipairs(MODES) do
    modeBtns[m.id].btn.MouseButton1Click:Connect(function()
        if not running then setMode(m.id) end
    end)
end

setMode("hell")

-- ── Settings inputs ───────────────────────────────────────────
divider(5)
sectionLabel("SETTINGS", 6)

local function inputRow(labelText, placeholder, default, order)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 32)
    row.LayoutOrder = order
    makeList(row, Enum.FillDirection.Horizontal, 8,
        Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    row.Parent = main

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = MUTED
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size = UDim2.new(0, 60, 1, 0)
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.BackgroundColor3 = SURF2
    box.BackgroundTransparency = 0
    box.TextColor3 = WHITE
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = MUTED
    box.Text = default or ""
    box.TextSize = 13
    box.Font = Enum.Font.GothamMedium
    box.ClearTextOnFocus = false
    box.Size = UDim2.new(1, -68, 1, 0)
    makeCorner(box, 6)
    local boxStroke = makeStroke(box, BORDER)
    makePad(box, 10, 0, 0, 0)
    box.Parent = row

    box.Focused:Connect(function()
        boxStroke.Color = ACCENT
    end)
    box.FocusLost:Connect(function()
        boxStroke.Color = BORDER
    end)

    return box
end

local countInput = inputRow("Count",    "e.g. 10",    "10",  7)
local delayInput = inputRow("Delay ms", "0 – 5000",   "500", 8)

-- ── Preview box ───────────────────────────────────────────────
divider(9)
sectionLabel("PREVIEW", 10)

local previewOuter = Instance.new("Frame")
previewOuter.BackgroundColor3 = SURF2
previewOuter.BorderSizePixel  = 0
previewOuter.Size = UDim2.new(1, 0, 0, 54)
previewOuter.LayoutOrder = 11
makeCorner(previewOuter, 6)
makeStroke(previewOuter, BORDER)
previewOuter.Parent = main

makeList(previewOuter, Enum.FillDirection.Vertical, 0,
    Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

local previewWord = Instance.new("TextLabel")
previewWord.BackgroundTransparency = 1
previewWord.Text = "—"
previewWord.TextColor3 = ACCENT
previewWord.TextSize = 22
previewWord.Font = Enum.Font.GothamBold
previewWord.TextXAlignment = Enum.TextXAlignment.Center
previewWord.Size = UDim2.new(1, 0, 0, 30)
previewWord.Parent = previewOuter

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = MUTED
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Size = UDim2.new(1, 0, 0, 16)
statusLabel.Parent = previewOuter

-- Progress bar
local progBg = Instance.new("Frame")
progBg.BackgroundColor3 = SURF2
progBg.BorderSizePixel  = 0
progBg.Size = UDim2.new(1, 0, 0, 4)
progBg.LayoutOrder = 12
makeCorner(progBg, 2)
makeStroke(progBg, BORDER)
progBg.Parent = main

local progFill = Instance.new("Frame")
progFill.BackgroundColor3 = ACCENT
progFill.BorderSizePixel  = 0
progFill.Size = UDim2.new(0, 0, 1, 0)
makeCorner(progFill, 2)
progFill.Parent = progBg

-- ── Start / Stop buttons ──────────────────────────────────────
local btnFrame = Instance.new("Frame")
btnFrame.BackgroundTransparency = 1
btnFrame.Size = UDim2.new(1, 0, 0, 36)
btnFrame.LayoutOrder = 13
makeList(btnFrame, Enum.FillDirection.Horizontal, 8,
    Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
btnFrame.Parent = main

local function actionBtn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 136, 0, 34)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.85
    b.TextColor3 = color
    b.Text = text
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    makeCorner(b, 6)
    makeStroke(b, color)
    b.Parent = btnFrame
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency=0.7}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency=0.85}):Play()
    end)
    return b
end

local startBtn = actionBtn("▶  START", SUCCESS)
local stopBtn  = actionBtn("■  STOP",  DANGER)

-- ── Logic ─────────────────────────────────────────────────────
local function setProgress(f)
    progFill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
end

local function setBusy(busy)
    startBtn.Active = not busy
    stopBtn.Active  = busy
    startBtn.TextColor3 = busy and MUTED or SUCCESS
    for _, s in pairs(modeBtns) do s.btn.Active = not busy end
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end

    local count = tonumber(countInput.Text)
    local delay = tonumber(delayInput.Text)

    if not count or count < 1 then
        statusLabel.Text = "Count must be ≥ 1"
        return
    end
    if not delay or delay < 0 or delay > 5000 then
        statusLabel.Text = "Delay must be 0–5000ms"
        return
    end

    local seq
    if selectedMode == "hell" then
        seq = buildHell(math.floor(count))
    elseif selectedMode == "grammar" then
        seq = buildGrammar(math.floor(count))
    else
        seq = buildJJ(math.floor(count))
    end

    local total = #seq

    task.spawn(function()
        running    = true
        stopSignal = false
        setBusy(true)
        setProgress(0)
        previewWord.Text = "—"

        local delaySec = math.max(delay / 1000, 0.04)

        for i, word in ipairs(seq) do
            if stopSignal then break end
            previewWord.Text  = word
            statusLabel.Text  = word .. "  (" .. i .. " / " .. total .. ")"
            setProgress(i / total)
            sendChat(word)
            task.wait(delaySec)
        end

        if not stopSignal then
            local last = seq[#seq]
            statusLabel.Text = "Done — " .. (selectedMode=="hell"
                and math.floor(count).." hell jack(s)"
                or "counted to "..last)
            setProgress(1)
        else
            statusLabel.Text = "Stopped"
        end

        running    = false
        stopSignal = false
        setBusy(false)
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    if running then stopSignal = true end
end)
