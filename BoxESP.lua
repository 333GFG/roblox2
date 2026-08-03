-- ============================================
--  BoxESP Module by nitarte (v2.0)
--  Рабочий 2D Box ESP вокруг ВСЕГО персонажа
--  Использует Roblox Drawing API
--  Основан на: Blissful4992, Stefanuk12, WA-ESP
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
    _cleaning = false
}

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================
--  ГЛАВНАЯ ФУНКЦИЯ: Получить 2D бокс персонажа
--  Использует Model:GetExtentsSize() — точно охватывает всё тело
-- ============================================
local function GetCharacterBox(character)
    if not character then return nil end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    -- Получаем реальные границы модели (включая все части тела)
    local success, extentSize = pcall(function()
        return character:GetExtentsSize()
    end)

    if not success or not extentSize then return nil end

    -- Центр модели
    local cf = hrp.CFrame
    local pos = cf.Position

    -- Размеры bounding box
    local sizeX = extentSize.X
    local sizeY = extentSize.Y
    local sizeZ = extentSize.Z

    -- 8 углов 3D бокса (относительно центра модели)
    local corners = {
        pos + cf.RightVector * (sizeX/2) + cf.UpVector * (sizeY/2) + cf.LookVector * (sizeZ/2),
        pos + cf.RightVector * (sizeX/2) + cf.UpVector * (sizeY/2) - cf.LookVector * (sizeZ/2),
        pos + cf.RightVector * (sizeX/2) - cf.UpVector * (sizeY/2) + cf.LookVector * (sizeZ/2),
        pos + cf.RightVector * (sizeX/2) - cf.UpVector * (sizeY/2) - cf.LookVector * (sizeZ/2),
        pos - cf.RightVector * (sizeX/2) + cf.UpVector * (sizeY/2) + cf.LookVector * (sizeZ/2),
        pos - cf.RightVector * (sizeX/2) + cf.UpVector * (sizeY/2) - cf.LookVector * (sizeZ/2),
        pos - cf.RightVector * (sizeX/2) - cf.UpVector * (sizeY/2) + cf.LookVector * (sizeZ/2),
        pos - cf.RightVector * (sizeX/2) - cf.UpVector * (sizeY/2) - cf.LookVector * (sizeZ/2),
    }

    -- Конвертируем в 2D экранные координаты
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOnScreen = false

    for _, corner in pairs(corners) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(corner)

        if onScreen then
            anyOnScreen = true
        end

        minX = math.min(minX, screenPos.X)
        minY = math.min(minY, screenPos.Y)
        maxX = math.max(maxX, screenPos.X)
        maxY = math.max(maxY, screenPos.Y)
    end

    if not anyOnScreen then return nil end

    return {
        min = Vector2.new(minX, minY),
        max = Vector2.new(maxX, maxY),
        width = maxX - minX,
        height = maxY - minY,
        center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
    }
end

-- ============================================
--  УПРАВЛЕНИЕ ОБЪЕКТАМИ DRAWING
-- ============================================
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
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

-- ============================================
--  ОБНОВЛЕНИЕ ПОЗИЦИИ БОКСА
-- ============================================
function BoxESP:_updateBox(box)
    -- Проверяем игрока
    if not box.player or not box.player.Parent then
        self:_removeBox(box.player)
        return
    end

    local character = box.player.Character
    if not character then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- TeamCheck
    if self.TeamCheck and box.player.Team == LocalPlayer.Team then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Дистанция
    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Получаем 2D бокс персонажа
    local bounds = GetCharacterBox(character)

    if not bounds then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Проверяем, что бокс в пределах экрана
    local screenSize = Camera.ViewportSize
    if bounds.max.X < 0 or bounds.min.X > screenSize.X or 
       bounds.max.Y < 0 or bounds.min.Y > screenSize.Y then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end

    -- Рисуем 4 линии бокса
    local topLeft = bounds.min
    local topRight = Vector2.new(bounds.max.X, bounds.min.Y)
    local bottomRight = bounds.max
    local bottomLeft = Vector2.new(bounds.min.X, bounds.max.Y)

    local l = box.lines
    l[1].From = topLeft;     l[1].To = topRight      -- Верхняя линия
    l[2].From = topRight;    l[2].To = bottomRight   -- Правая линия
    l[3].From = bottomRight; l[3].To = bottomLeft    -- Нижняя линия
    l[4].From = bottomLeft;  l[4].To = topLeft       -- Левая линия

    for _, line in pairs(l) do
        line.Visible = true
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
    end
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ
-- ============================================
function BoxESP:_startLoop()
    if self._connection then return end

    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        -- Добавляем новых игроков
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
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

-- Включить/выключить ESP
function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        self:_startLoop()
    else
        -- Прячем все линии
        for _, box in pairs(self._players) do
            for _, line in pairs(box.lines) do
                line.Visible = false
            end
        end
    end
end

-- Изменить цвет
function BoxESP:SetColor(color)
    self.Color = color
end

-- Полностью выгрузить модуль
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

return BoxESP
