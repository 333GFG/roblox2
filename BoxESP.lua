-- ============================================
--  BoxESP Module by nitarte (v5.0 — ОПТИМИЗИРОВАННЫЙ)
--  2D Box ESP вокруг ВСЕГО персонажа
--  Оптимизация: кэширование, реже обновления, меньше объектов Drawing
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,
    MaxDistance = 2000,

    -- Внутренние таблицы
    _players = {},
    _connection = nil,
    _cleaning = false,
    _lastUpdate = 0,
    _updateInterval = 1/60  -- 60 FPS max (было без ограничения)
}

-- Сервисы (кэшируем)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Кэш частей тела (чтобы не искать каждый кадр)
local BodyPartCache = {}

-- ============================================
--  ПОЛУЧИТЬ НИЖНЮЮ ТОЧКУ ПЕРСОНАЖА (ноги)
-- ============================================
local function GetBottomPart(character)
    local cache = BodyPartCache[character]
    if cache and cache.bottom then
        return cache.bottom.Position
    end

    -- R15
    local leftFoot = character:FindFirstChild("LeftFoot")
    local rightFoot = character:FindFirstChild("RightFoot")
    if leftFoot and rightFoot then
        if not cache then BodyPartCache[character] = {} end
        BodyPartCache[character].bottom = leftFoot
        return (leftFoot.Position + rightFoot.Position) / 2
    end

    -- R6
    local leftLeg = character:FindFirstChild("Left Leg")
    local rightLeg = character:FindFirstChild("Right Leg")
    if leftLeg and rightLeg then
        if not cache then BodyPartCache[character] = {} end
        BodyPartCache[character].bottom = leftLeg
        return (leftLeg.Position + rightLeg.Position) / 2
    end

    -- Fallback
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position - Vector3.new(0, 2.5, 0)
    end

    return nil
end

-- ============================================
--  ПОЛУЧИТЬ ГОЛОВУ (с кэшем)
-- ============================================
local function GetHead(character)
    local cache = BodyPartCache[character]
    if cache and cache.head then
        return cache.head
    end

    local head = character:FindFirstChild("Head")
    if head then
        if not cache then BodyPartCache[character] = {} end
        BodyPartCache[character].head = head
    end

    return head
end

-- ============================================
--  ОЧИСТКА КЭША ПРИ СМЕРТИ/ВЫХОДЕ
-- ============================================
local function ClearCache(character)
    BodyPartCache[character] = nil
end

-- ============================================
--  СОЗДАНИЕ ЛИНИЙ (ТОЛЬКО 4 ЛИНИИ + outline через толщину)
-- ============================================
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        lastVisible = false,
        lastHeadPos = Vector3.new(),
        lastBottomPos = Vector3.new(),
    }

    -- 8 линий: 1-4 outline, 5-8 основной цвет
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Transparency = self.Transparency
        table.insert(box.lines, line)
    end

    self._players[player] = box
    return box
end

function BoxESP:_removeBox(player)
    local box = self._players[player]
    if box then
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        if box.player.Character then
            ClearCache(box.player.Character)
        end
        self._players[player] = nil
    end
end

function BoxESP:_clearAll()
    if self._cleaning then return end
    self._cleaning = true

    for player, box in pairs(self._players) do
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        if box.player.Character then
            ClearCache(box.player.Character)
        end
    end
    table.clear(self._players)
    table.clear(BodyPartCache)

    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end

    self._cleaning = false
end

-- ============================================
--  ОБНОВЛЕНИЕ БОКСА (ОПТИМИЗИРОВАННОЕ)
-- ============================================
function BoxESP:_updateBox(box)
    if not box.player or not box.player.Parent then
        self:_removeBox(box.player)
        return
    end

    local character = box.player.Character
    if not character then
        if box.lastVisible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.lastVisible = false
        end
        return
    end

    local head = GetHead(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local bottomPos = GetBottomPart(character)

    if not head or not humanoid or humanoid.Health <= 0 or not bottomPos then
        if box.lastVisible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.lastVisible = false
        end
        return
    end

    -- TeamCheck
    if self.TeamCheck and box.player.Team == LocalPlayer.Team then
        if box.lastVisible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.lastVisible = false
        end
        return
    end

    -- Дистанция
    local headPos = head.Position
    local distance = (headPos - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        if box.lastVisible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.lastVisible = false
        end
        return
    end

    -- ОПТИМИЗАЦИЯ: если позиция почти не изменилась — пропускаем кадр
    local posDelta = (headPos - box.lastHeadPos).Magnitude + (bottomPos - box.lastBottomPos).Magnitude
    if posDelta < 0.5 and box.lastVisible then
        return  -- Позиция почти не изменилась, линии уже правильные
    end

    box.lastHeadPos = headPos
    box.lastBottomPos = bottomPos

    -- Проецируем на экран
    local headScreen, headOnScreen = Camera:WorldToViewportPoint(headPos)
    local bottomScreen, bottomOnScreen = Camera:WorldToViewportPoint(bottomPos)

    if not headOnScreen and not bottomOnScreen then
        if box.lastVisible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.lastVisible = false
        end
        return
    end

    -- ============================================
    --  РАСЧЁТ РАЗМЕРА БОКСА
    -- ============================================
    local height = math.abs(bottomScreen.Y - headScreen.Y)
    local width = height * 0.6
    local centerX = (headScreen.X + bottomScreen.X) / 2
    local topY = headScreen.Y - height * 0.08
    local bottomY = bottomScreen.Y + height * 0.05

    height = bottomY - topY
    width = height * 0.6

    local topLeft     = Vector2.new(centerX - width / 2, topY)
    local topRight    = Vector2.new(centerX + width / 2, topY)
    local bottomRight = Vector2.new(centerX + width / 2, bottomY)
    local bottomLeft  = Vector2.new(centerX - width / 2, bottomY)

    -- ============================================
    --  ОБНОВЛЯЕМ ЛИНИИ (1-4 outline, 5-8 цвет)
    -- ============================================
    local lines = box.lines
    local color = self.Color
    local thickness = self.Thickness
    local outlineThickness = thickness + 2

    -- Outline
    lines[1].From = topLeft;      lines[1].To = topRight;       lines[1].Color = Color3.new(0, 0, 0); lines[1].Thickness = outlineThickness
    lines[2].From = topRight;     lines[2].To = bottomRight;    lines[2].Color = Color3.new(0, 0, 0); lines[2].Thickness = outlineThickness
    lines[3].From = bottomRight;  lines[3].To = bottomLeft;     lines[3].Color = Color3.new(0, 0, 0); lines[3].Thickness = outlineThickness
    lines[4].From = bottomLeft;   lines[4].To = topLeft;        lines[4].Color = Color3.new(0, 0, 0); lines[4].Thickness = outlineThickness

    -- Основной бокс
    lines[5].From = topLeft;      lines[5].To = topRight;       lines[5].Color = color; lines[5].Thickness = thickness
    lines[6].From = topRight;     lines[6].To = bottomRight;    lines[6].Color = color; lines[6].Thickness = thickness
    lines[7].From = bottomRight;  lines[7].To = bottomLeft;     lines[7].Color = color; lines[7].Thickness = thickness
    lines[8].From = bottomLeft;   lines[8].To = topLeft;        lines[8].Color = color; lines[8].Thickness = thickness

    for _, line in pairs(lines) do
        line.Visible = true
        line.Transparency = self.Transparency
    end

    box.lastVisible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ (С ОГРАНИЧЕНИЕМ FPS)
-- ============================================
function BoxESP:_startLoop()
    if self._connection then return end

    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        -- ОГРАНИЧЕНИЕ: обновляем не чаще 60 раз в секунду
        local now = tick()
        if now - self._lastUpdate < self._updateInterval then
            return
        end
        self._lastUpdate = now

        -- Добавляем новых игроков
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createBox(player)
            end
        end

        -- Обновляем боксы (не все сразу, а пачками)
        local count = 0
        for _, box in pairs(self._players) do
            self:_updateBox(box)
            count = count + 1
            -- Если много игроков — не обновляем все за один кадр
            if count > 10 then
                count = 0
                task.wait()
            end
        end
    end)
end

-- ============================================
--  ПУБЛИЧНЫЕ МЕТОДЫ
-- ============================================

function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        self:_startLoop()
    else
        for _, box in pairs(self._players) do
            for _, line in pairs(box.lines) do
                line.Visible = false
            end
            box.lastVisible = false
        end
    end
end

function BoxESP:SetColor(color)
    self.Color = color
    -- Обновляем цвет у всех видимых боксов сразу
    for _, box in pairs(self._players) do
        if box.lastVisible then
            local lines = box.lines
            for i = 5, 8 do
                lines[i].Color = color
            end
        end
    end
end

function BoxESP:SetThickness(thickness)
    self.Thickness = thickness
end

function BoxESP:SetMaxDistance(distance)
    self.MaxDistance = distance
end

function BoxESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

-- ============================================
--  АВТО-ОЧИСТКА
-- ============================================
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

-- Очистка кэша при смерти персонажа
Players.PlayerAdded:Connect(function(player)
    player.CharacterRemoving:Connect(function(char)
        ClearCache(char)
    end)
end)

return BoxESP
