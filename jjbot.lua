-- ============================================================
--  JumpingJackBot.lua
--  LocalScript → StarterPlayerScripts
--
--  Builds a ScreenGui inside the player's PlayerGui.
--  The GUI controls (mode, count, delay, start/stop) all
--  stay on-screen in Roblox. Pressing Start sends each word
--  to Roblox chat one at a time using SayMessageRequest.
-- ============================================================

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local localPlayer        = Players.LocalPlayer
local playerGui          = localPlayer:WaitForChild("PlayerGui")

-- ── Number-to-words ─────────────────────────────────────────

local ONES = {
    [0]="", [1]="One",  [2]="Two",    [3]="Three", [4]="Four",
    [5]="Five", [6]="Six", [7]="Seven", [8]="Eight", [9]="Nine",
    [10]="Ten", [11]="Eleven", [12]="Twelve", [13]="Thirteen",
    [14]="Fourteen", [15]="Fifteen",  [16]="Sixteen",
    [17]="Seventeen", [18]="Eighteen", [19]="Nineteen",
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

-- ── Sequence builders ────────────────────────────────────────

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

-- ── Chat sender ──────────────────────────────────────────────

local chatEvent
local function getSayEvent()
    if chatEvent then return chatEvent end
    local ok, ev = pcall(function()
        return ReplicatedStorage
            :WaitForChild("DefaultChatSystemChatEvents", 3)
            :WaitForChild("SayMessageRequest", 3)
    end)
    if ok and ev then chatEvent = ev end
    return chatEvent
end

local function sendChat(msg)
    local ev = getSayEvent()
    if ev then
        pcall(function() ev:FireServer(msg, "All") end)
    else
        -- fallback for non-default chat systems
        pcall(function()
            game:GetService("Chat"):Chat(
                localPlayer.Character and localPlayer.Character:FindFirstChild("Head"),
                msg, Enum.ChatColor.White
            )
        end)
    end
end

-- ── Bot state ────────────────────────────────────────────────

local running    = false
local stopSignal = false

-- ── GUI builder ──────────────────────────────────────────────

local BG      = Color3.fromRGB(10,  10,  15)
local SURFACE = Color3.fromRGB(17,  17,  24)
local SURF2   = Color3.fromRGB(24,  24,  31)
local BORDER  = Color3.fromRGB(42,  42,  58)
local ACCENT  = Color3.fromRGB(0,   255, 231)
local MUTED   = Color3.fromRGB(85,  85,  112)
local SUCCESS = Color3.fromRGB(0,   255, 153)
local DANGER  = Color3.fromRGB(255, 79,  123)
local WHITE   = Color3.fromRGB(232, 232, 240)

local function makeBorder(parent, color)
    local f = Instance.new("UIStroke")
    f.Color = color or BORDER
    f.Thickness = 1
    f.Parent = parent
    return f
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function makeLabel(parent, text, size, color, bold, xAlign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or WHITE
    l.TextSize = size or 14
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, size and size + 6 or 20)
    l.Parent = parent
    return l
end

local function makeButton(parent, text, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = bgColor or SURF2
    b.TextColor3 = textColor or WHITE
    b.Text = text
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Size = UDim2.new(0.48, 0, 0, 36)
    makeCorner(b, 6)
    makeBorder(b, bgColor or BORDER)
    b.Parent = parent

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.7}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.85}):Play()
    end)
    b.BackgroundTransparency = 0.85
    return b
end

local function makeInput(parent, placeholder, default)
    local box = Instance.new("TextBox")
    box.BackgroundColor3 = SURF2
    box.BackgroundTransparency = 0
    box.TextColor3 = WHITE
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = MUTED
    box.Text = default or ""
    box.TextSize = 14
    box.Font = Enum.Font.GothamMedium
    box.ClearTextOnFocus = false
    box.Size = UDim2.new(1, 0, 0, 32)
    makeCorner(box, 6)
    makeBorder(box, BORDER)
    box.Parent = parent

    box.Focused:Connect(function()
        TweenService:Create(box:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Color = ACCENT}):Play()
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(box:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Color = BORDER}):Play()
    end)

    -- inner padding
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = box
    return box
end

-- ── Build the ScreenGui ───────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "JumpingJackBot"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 320, 0, 0)  -- height set by layout
main.Position = UDim2.new(0, 16, 0.5, -200)
main.BackgroundColor3 = BG
main.AnchorPoint = Vector2.new(0, 0.5)
makeCorner(main, 10)
makeBorder(main, BORDER)
main.Parent = screenGui

local mainLayout = Instance.new("UIListLayout")
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Padding = UDim.new(0, 0)
mainLayout.Parent = main

local mainPad = Instance.new("UIPadding")
mainPad.PaddingLeft   = UDim.new(0, 14)
mainPad.PaddingRight  = UDim.new(0, 14)
mainPad.PaddingTop    = UDim.new(0, 14)
mainPad.PaddingBottom = UDim.new(0, 14)
mainPad.Parent = main

-- Auto-resize main frame height
local function updateHeight()
    task.wait()
    main.Size = UDim2.new(0, 320, 0, mainLayout.AbsoluteContentSize.Y + 28)
end

-- ── Title ────────────────────────────────────────────────────

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "JUMPING JACK BOT"
titleLabel.TextColor3 = ACCENT
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Size = UDim2.new(1, 0, 0, 28)
titleLabel.LayoutOrder = 1
titleLabel.Parent = main

-- ── Section: Mode ────────────────────────────────────────────

local modeSection = Instance.new("Frame")
modeSection.BackgroundTransparency = 1
modeSection.Size = UDim2.new(1, 0, 0, 90)
modeSection.LayoutOrder = 2
modeSection.Parent = main

local modeSectionLayout = Instance.new("UIListLayout")
modeSectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeSectionLayout.Padding = UDim.new(0, 6)
modeSectionLayout.Parent = modeSection

local sectionDivider = Instance.new("Frame")
sectionDivider.BackgroundColor3 = BORDER
sectionDivider.Size = UDim2.new(1, 0, 0, 1)
sectionDivider.LayoutOrder = 1
sectionDivider.Parent = modeSection

local modeLabel = makeLabel(modeSection, "MODE", 10, MUTED, true)
modeLabel.LayoutOrder = 2
modeLabel.TextSize = 10
modeLabel.Size = UDim2.new(1, 0, 0, 16)

local modeRow = Instance.new("Frame")
modeRow.BackgroundTransparency = 1
modeRow.Size = UDim2.new(1, 0, 0, 56)
modeRow.LayoutOrder = 3
modeRow.Parent = modeSection

local modeRowLayout = Instance.new("UIListLayout")
modeRowLayout.FillDirection = Enum.FillDirection.Horizontal
modeRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeRowLayout.Padding = UDim.new(0, 6)
modeRowLayout.Parent = modeRow

local modes = {
    { id = "hell",    label = "Hell Jacks",    sub = "O→N→E→ONE→..." },
    { id = "grammar", label = "Grammar Jacks", sub = "One.→Two.→..." },
    { id = "jj",      label = "Jumping Jacks", sub = "ONE→TWO→..."   },
}

local selectedMode   = "hell"
local modeButtons    = {}

for i, m in ipairs(modes) do
    local btn = Instance.new("TextButton")
    btn.Name = m.id
    btn.Size = UDim2.new(0, 92, 0, 50)
    btn.BackgroundColor3 = SURF2
    btn.BackgroundTransparency = 0.4
    btn.TextColor3 = MUTED
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    makeCorner(btn, 6)
    local stroke = makeBorder(btn, BORDER)

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1, 0, 1, 0)
    inner.Parent = btn
    local innerLayout = Instance.new("UIListLayout")
    innerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    innerLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    innerLayout.Padding = UDim.new(0, 2)
    innerLayout.Parent = inner

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

    modeButtons[m.id] = { btn = btn, stroke = stroke, topL = topL, subL = subL }
    btn.Parent = modeRow
end

local function setMode(id)
    selectedMode = id
    for mid, obj in pairs(modeButtons) do
        if mid == id then
            TweenService:Create(obj.btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.85, BackgroundColor3 = ACCENT}):Play()
            TweenService:Create(obj.stroke, TweenInfo.new(0.15), {Color = ACCENT}):Play()
            obj.topL.TextColor3 = ACCENT
            obj.subL.TextColor3 = Color3.fromRGB(0, 180, 160)
        else
            TweenService:Create(obj.btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.4, BackgroundColor3 = SURF2}):Play()
            TweenService:Create(obj.stroke, TweenInfo.new(0.15), {Color = BORDER}):Play()
            obj.topL.TextColor3 = MUTED
            obj.subL.TextColor3 = MUTED
        end
    end
end

for _, m in ipairs(modes) do
    modeButtons[m.id].btn.MouseButton1Click:Connect(function()
        if not running then setMode(m.id) end
    end)
end

setMode("hell")

-- ── Section: Settings ────────────────────────────────────────

local settingsSection = Instance.new("Frame")
settingsSection.BackgroundTransparency = 1
settingsSection.Size = UDim2.new(1, 0, 0, 110)
settingsSection.LayoutOrder = 3
settingsSection.Parent = main

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Padding = UDim.new(0, 6)
settingsLayout.Parent = settingsSection

local div2 = Instance.new("Frame")
div2.BackgroundColor3 = BORDER
div2.Size = UDim2.new(1, 0, 0, 1)
div2.LayoutOrder = 1
div2.Parent = settingsSection

local settingsLabel = makeLabel(settingsSection, "SETTINGS", 10, MUTED, true)
settingsLabel.LayoutOrder = 2
settingsLabel.TextSize = 10
settingsLabel.Size = UDim2.new(1, 0, 0, 16)

-- Count row
local countRow = Instance.new("Frame")
countRow.BackgroundTransparency = 1
countRow.Size = UDim2.new(1, 0, 0, 32)
countRow.LayoutOrder = 3
countRow.Parent = settingsSection
local countRowL = Instance.new("UIListLayout")
countRowL.FillDirection = Enum.FillDirection.Horizontal
countRowL.VerticalAlignment = Enum.VerticalAlignment.Center
countRowL.Padding = UDim.new(0, 8)
countRowL.Parent = countRow
local countLbl = Instance.new("TextLabel")
countLbl.BackgroundTransparency = 1
countLbl.Text = "Count"
countLbl.TextColor3 = MUTED
countLbl.TextSize = 13
countLbl.Font = Enum.Font.GothamMedium
countLbl.Size = UDim2.new(0, 55, 1, 0)
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = countRow
local countWrap = Instance.new("Frame")
countWrap.BackgroundTransparency = 1
countWrap.Size = UDim2.new(1, -63, 1, 0)
countWrap.Parent = countRow
local countInput = makeInput(countWrap, "e.g. 10", "10")
countInput.Size = UDim2.new(1, 0, 0, 32)

-- Delay row
local delayRow = Instance.new("Frame")
delayRow.BackgroundTransparency = 1
delayRow.Size = UDim2.new(1, 0, 0, 32)
delayRow.LayoutOrder = 4
delayRow.Parent = settingsSection
local delayRowL = Instance.new("UIListLayout")
delayRowL.FillDirection = Enum.FillDirection.Horizontal
delayRowL.VerticalAlignment = Enum.VerticalAlignment.Center
delayRowL.Padding = UDim.new(0, 8)
delayRowL.Parent = delayRow
local delayLbl = Instance.new("TextLabel")
delayLbl.BackgroundTransparency = 1
delayLbl.Text = "Delay ms"
delayLbl.TextColor3 = MUTED
delayLbl.TextSize = 13
delayLbl.Font = Enum.Font.GothamMedium
delayLbl.Size = UDim2.new(0, 55, 1, 0)
delayLbl.TextXAlignment = Enum.TextXAlignment.Left
delayLbl.Parent = delayRow
local delayWrap = Instance.new("Frame")
delayWrap.BackgroundTransparency = 1
delayWrap.Size = UDim2.new(1, -63, 1, 0)
delayWrap.Parent = delayRow
local delayInput = makeInput(delayWrap, "0–5000 ms", "500")
delayInput.Size = UDim2.new(1, 0, 0, 32)

-- ── Section: Preview + buttons ───────────────────────────────

local previewSection = Instance.new("Frame")
previewSection.BackgroundTransparency = 1
previewSection.Size = UDim2.new(1, 0, 0, 130)
previewSection.LayoutOrder = 4
previewSection.Parent = main

local previewLayout = Instance.new("UIListLayout")
previewLayout.SortOrder = Enum.SortOrder.LayoutOrder
previewLayout.Padding = UDim.new(0, 8)
previewLayout.Parent = previewSection

local div3 = Instance.new("Frame")
div3.BackgroundColor3 = BORDER
div3.Size = UDim2.new(1, 0, 0, 1)
div3.LayoutOrder = 1
div3.Parent = previewSection

-- Preview box
local previewBox = Instance.new("Frame")
previewBox.BackgroundColor3 = SURF2
previewBox.Size = UDim2.new(1, 0, 0, 52)
previewBox.LayoutOrder = 2
makeCorner(previewBox, 6)
makeBorder(previewBox, BORDER)
previewBox.Parent = previewSection

local previewInnerLayout = Instance.new("UIListLayout")
previewInnerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
previewInnerLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
previewInnerLayout.Parent = previewBox

local previewWord = Instance.new("TextLabel")
previewWord.BackgroundTransparency = 1
previewWord.Text = "—"
previewWord.TextColor3 = ACCENT
previewWord.TextSize = 22
previewWord.Font = Enum.Font.GothamBold
previewWord.TextXAlignment = Enum.TextXAlignment.Center
previewWord.Size = UDim2.new(1, 0, 0, 28)
previewWord.Parent = previewBox

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = MUTED
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Size = UDim2.new(1, 0, 0, 14)
statusLabel.Parent = previewBox

-- Progress bar
local progressBg = Instance.new("Frame")
progressBg.BackgroundColor3 = SURF2
progressBg.Size = UDim2.new(1, 0, 0, 4)
progressBg.LayoutOrder = 3
makeCorner(progressBg, 2)
progressBg.Parent = previewSection

local progressFill = Instance.new("Frame")
progressFill.BackgroundColor3 = ACCENT
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.AnchorPoint = Vector2.new(0, 0)
makeCorner(progressFill, 2)
progressFill.Parent = progressBg

-- Start / Stop buttons
local btnRow = Instance.new("Frame")
btnRow.BackgroundTransparency = 1
btnRow.Size = UDim2.new(1, 0, 0, 36)
btnRow.LayoutOrder = 4
btnRow.Parent = previewSection

local btnRowLayout = Instance.new("UIListLayout")
btnRowLayout.FillDirection = Enum.FillDirection.Horizontal
btnRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
btnRowLayout.Padding = UDim.new(0, 8)
btnRowLayout.Parent = btnRow

local startBtn = makeButton(btnRow, "▶  START", SUCCESS, SUCCESS)
local stopBtn  = makeButton(btnRow, "■  STOP",  DANGER,  DANGER)
stopBtn.Active = false
TweenService:Create(stopBtn, TweenInfo.new(0), {BackgroundTransparency = 0.85}):Play()

-- ── Wire up Start / Stop ──────────────────────────────────────

local function setStatus(msg)
    statusLabel.Text = msg
end

local function setPreview(word)
    previewWord.Text = word
    TweenService:Create(previewWord, TweenInfo.new(0.05), {TextTransparency = 0}):Play()
end

local function setProgress(fraction)
    TweenService:Create(progressFill, TweenInfo.new(0.15), {
        Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
    }):Play()
end

local function setBusy(busy)
    startBtn.Active = not busy
    stopBtn.Active  = busy
    startBtn.TextColor3 = busy and MUTED or SUCCESS
    stopBtn.TextColor3  = busy and DANGER or MUTED
    -- dim mode buttons while running
    for _, obj in pairs(modeButtons) do
        obj.btn.Active = not busy
    end
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end

    local count = tonumber(countInput.Text)
    local delay = tonumber(delayInput.Text)

    if not count or count < 1 then
        setStatus("Count must be ≥ 1")
        return
    end
    if not delay or delay < 0 or delay > 5000 then
        setStatus("Delay must be 0–5000 ms")
        return
    end

    local sequence
    if selectedMode == "hell" then
        sequence = buildHell(count)
    elseif selectedMode == "grammar" then
        sequence = buildGrammar(count)
    else
        sequence = buildJJ(count)
    end

    local total = #sequence

    task.spawn(function()
        running    = true
        stopSignal = false
        setBusy(true)
        setProgress(0)
        setPreview("—")

        local delaySec = math.max(delay / 1000, 0.04)

        for i, word in ipairs(sequence) do
            if stopSignal then break end

            setPreview(word)
            setStatus(word .. "  (" .. i .. " / " .. total .. ")")
            setProgress(i / total)
            sendChat(word)

            task.wait(delaySec)
        end

        if not stopSignal then
            setStatus("Done — " .. (selectedMode == "hell" and count .. " hell jack(s)" or "counted to " .. sequence[#sequence]))
            setProgress(1)
        else
            setStatus("Stopped")
        end

        running    = false
        stopSignal = false
        setBusy(false)
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    if running then
        stopSignal = true
    end
end)

updateHeight()
