-- ============================================
--  BoxESP Module (основан на wa0101/Roblox-ESP)
--  by nitarte
--  Поддерживает: Full Box, Corner Box
-- ============================================

local BoxESP = {
    Enabled = false,
    BoxStyle = "Full", -- "Full" или "Corner"
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,
    MaxDistance = 2000,
    Padding = 3,

    _players = {},
    _connection = nil,
    _cleaning = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

-- Получить все видимые части персонажа
local function GetCharacterParts(character)
    local parts = {}
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("BasePart") and child.Transparency < 1 then
            table.insert(parts, child)
        end
    end
    return parts
end

-- === СОЗДАНИЕ / УДАЛЕНИЕ БОКСА ===

function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        parts = {},
        character = nil,
        lastMinX = nil, lastMaxX = nil,
        lastMinY = nil, lastMaxY = nil
    }

    -- Создаём 4 линии для полного бокса
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
        table.insert(box.lines, line)
    end

    -- Создаём 8 линий для углового бокса (по 2 на каждый угол)
    for i = 1, 8 do
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

function BoxESP:_removeBox(player)
    local box = self._players[player]
    if box then
        for _, line in pairs(box.lines) do
            line:Remove()
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
    end
    table.clear(self._players)
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._cleaning = false
end

-- === РИСОВАНИЕ БОКСА ===

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

    -- Обновляем кэш частей при смене персонажа
    if box.character ~= character then
        box.character = character
        box.parts = GetCharacterParts(character)
    end

    if #box.parts == 0 then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- TeamCheck
    if self.TeamCheck and player.Team == LocalPlayer.Team then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Дистанция
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        if dist > self.MaxDistance then
            for _, line in pairs(box.lines) do line.Visible = false end
            return
        end
    end

    -- Проецируем все части и находим границы
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

    if not anyOnScreen then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    local pad = self.Padding
    minX = minX - pad
    maxX = maxX + pad
    minY = minY - pad
    maxY = maxY + pad

    -- Если координаты не изменились — не обновляем (оптимизация)
    if box.lastMinX == minX and box.lastMaxX == maxX and
       box.lastMinY == minY and box.lastMaxY == maxY then
        return
    end

    -- === РИСУЕМ В ЗАВИСИМОСТИ ОТ СТИЛЯ ===
    local lines = box.lines
    local style = self.BoxStyle

    if style == "Full" then
        -- 4 линии: верх, право, низ, лево
        lines[1].From = Vector2.new(minX, minY); lines[1].To = Vector2.new(maxX, minY)
        lines[2].From = Vector2.new(maxX, minY); lines[2].To = Vector2.new(maxX, maxY)
        lines[3].From = Vector2.new(maxX, maxY); lines[3].To = Vector2.new(minX, maxY)
        lines[4].From = Vector2.new(minX, maxY); lines[4].To = Vector2.new(minX, minY)

        -- Скрываем линии углов (5-8)
        for i = 5, 8 do lines[i].Visible = false end

        -- Показываем основные линии
        for i = 1, 4 do
            lines[i].Visible = true
            lines[i].Color = self.Color
            lines[i].Thickness = self.Thickness
            lines[i].Transparency = self.Transparency
        end

    elseif style == "Corner" then
        -- Угловой бокс: 8 линий (по 2 на угол)
        local cornerSize = math.min((maxX - minX) * 0.2, (maxY - minY) * 0.2)
        cornerSize = math.max(cornerSize, 10) -- минимум 10px

        -- Верхний-левый угол
        lines[1].From = Vector2.new(minX, minY + cornerSize); lines[1].To = Vector2.new(minX, minY)
        lines[2].From = Vector2.new(minX, minY); lines[2].To = Vector2.new(minX + cornerSize, minY)

        -- Верхний-правый угол
        lines[3].From = Vector2.new(maxX - cornerSize, minY); lines[3].To = Vector2.new(maxX, minY)
        lines[4].From = Vector2.new(maxX, minY); lines[4].To = Vector2.new(maxX, minY + cornerSize)

        -- Нижний-правый угол
        lines[5].From = Vector2.new(maxX, maxY - cornerSize); lines[5].To = Vector2.new(maxX, maxY)
        lines[6].From = Vector2.new(maxX, maxY); lines[6].To = Vector2.new(maxX - cornerSize, maxY)

        -- Нижний-левый угол
        lines[7].From = Vector2.new(minX + cornerSize, maxY); lines[7].To = Vector2.new(minX, maxY)
        lines[8].From = Vector2.new(minX, maxY); lines[8].To = Vector2.new(minX, maxY - cornerSize)

        -- Скрываем линии полного бокса (1-4)
        for i = 1, 4 do lines[i].Visible = false end

        -- Показываем линии углов
        for i = 5, 8 do
            lines[i].Visible = true
            lines[i].Color = self.Color
            lines[i].Thickness = self.Thickness
            lines[i].Transparency = self.Transparency
        end
    end

    -- Сохраняем координаты для кэша
    box.lastMinX, box.lastMaxX = minX, maxX
    box.lastMinY, box.lastMaxY = minY, maxY
end

-- === ГЛАВНЫЙ ЦИКЛ ===

function BoxESP:_startLoop()
    if self._connection then return end
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        for _, player in pairs(Players:GetPlayers()) do
            if not self._players[player] then
                self:_createBox(player)
            end
        end

        for _, box in pairs(self._players) do
            self:_updateBox(box)
        end
    end)
end

-- === ПУБЛИЧНЫЕ МЕТОДЫ ===

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

function BoxESP:SetStyle(style)
    if style == "Full" or style == "Corner" then
        self.BoxStyle = style
    end
end

function BoxESP:SetColor(color)
    self.Color = color
end

function BoxESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

-- Автоудаление при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
