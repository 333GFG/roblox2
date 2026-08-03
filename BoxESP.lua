-- ============================================
--  BoxESP Module by nitarte (v2)
--  Полный обвод всей модели игрока
--  Использует все части тела для точного бокса
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,
    MaxDistance = 2000,
    Padding = 3,   -- отступ в пикселях

    _players = {},
    _connection = nil,
    _cleaning = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Получить все части тела персонажа (BasePart)
local function GetCharacterParts(character)
    local parts = {}
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("BasePart") and child.Transparency < 1 then  -- игнорируем невидимые части
            table.insert(parts, child)
        end
    end
    return parts
end

-- Создать бокс для игрока
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        parts = {},      -- кэш частей
        character = nil,
        lastMinX = nil, lastMaxX = nil,
        lastMinY = nil, lastMaxY = nil
    }
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
        table.insert(box.lines, line)
    end
    self._players[player] = box
    return box
end

-- Удалить бокс
function BoxESP:_removeBox(player)
    local box = self._players[player]
    if box then
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        self._players[player] = nil
    end
end

-- Очистить все
function BoxESP:_clearAll()
    if self._cleaning then return end
    self._cleaning = true
    for player, box in pairs(self._players) do
        for _, line in pairs(box.lines) do
            line:Remove()
        end
    end
    table.clear(self._players)
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._cleaning = false
end

-- Обновить бокс для одного игрока
function BoxESP:_updateBox(box)
    local player = box.player
    if not player or not player.Parent then
        self:_removeBox(player)
        return
    end

    local character = player.Character
    if not character then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Проверяем, не изменился ли персонаж (перерождение)
    if box.character ~= character then
        box.character = character
        box.parts = GetCharacterParts(character)
    end

    -- Если нет частей – скрываем
    if #box.parts == 0 then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- TeamCheck
    if self.TeamCheck and player.Team == LocalPlayer.Team then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Дистанция (используем HumanoidRootPart, если есть)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist > self.MaxDistance then
            for _, line in pairs(box.lines) do line.Visible = false end
            return
        end
    end

    -- Проецируем все части и находим экстремумы
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOnScreen = false

    for _, part in ipairs(box.parts) do
        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if onScreen then
            anyOnScreen = true
            local x, y = pos.X, pos.Y
            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end
    end

    -- Если ни одна часть не видна – скрываем
    if not anyOnScreen then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Добавляем отступ
    local pad = self.Padding
    minX = minX - pad
    maxX = maxX + pad
    minY = minY - pad
    maxY = maxY + pad

    -- Если координаты не изменились – не обновляем линии (оптимизация)
    if box.lastMinX == minX and box.lastMaxX == maxX and
       box.lastMinY == minY and box.lastMaxY == maxY then
        return
    end

    -- Обновляем линии
    local l = box.lines
    l[1].From = Vector2.new(minX, minY); l[1].To = Vector2.new(maxX, minY)  -- верх
    l[2].From = Vector2.new(maxX, minY); l[2].To = Vector2.new(maxX, maxY)  -- право
    l[3].From = Vector2.new(maxX, maxY); l[3].To = Vector2.new(minX, maxY)  -- низ
    l[4].From = Vector2.new(minX, maxY); l[4].To = Vector2.new(minX, minY)  -- лево

    for _, line in pairs(l) do
        line.Visible = true
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
    end

    -- Сохраняем текущие координаты для кэша
    box.lastMinX, box.lastMaxX = minX, maxX
    box.lastMinY, box.lastMaxY = minY, maxY
end

-- Главный цикл
function BoxESP:_startLoop()
    if self._connection then return end
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        -- Добавляем новых игроков (включая себя)
        for _, player in pairs(Players:GetPlayers()) do
            if not self._players[player] then
                self:_createBox(player)
            end
        end

        -- Обновляем все боксы
        for _, box in pairs(self._players) do
            self:_updateBox(box)
        end
    end)
end

-- ============================================
--  ПУБЛИЧНЫЕ МЕТОДЫ
-- ============================================

function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        for _, player in pairs(Players:GetPlayers()) do
            if not self._players[player] then
                self:_createBox(player)
            end
        end
        self:_startLoop()
    else
        for _, box in pairs(self._players) do
            for _, line in pairs(box.lines) do
                line.Visible = false
            end
        end
    end
end

function BoxESP:SetColor(color)
    self.Color = color
end

function BoxESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

-- Автоудаление при выходе
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
