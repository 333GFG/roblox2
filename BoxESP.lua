-- ============================================
--  BoxESP Module by nitarte
--  Простой 2D Box ESP вокруг игроков
--  Использует Roblox Drawing API
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),   -- синий акцент под твою тему
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,                       -- true = не рисовать тиммейтов
    MaxDistance = 2000,                      -- макс. дистанция в студиях
    
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

-- Создать 4 линии бокса для одного игрока
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        character = nil,
        hrp = nil
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

-- Удалить бокс игрока
function BoxESP:_removeBox(player)
    local box = self._players[player]
    if box then
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        self._players[player] = nil
    end
end

-- Очистить все боксы
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

-- Обновить позицию одного бокса
function BoxESP:_updateBox(box)
    -- Проверяем персонажа
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
    
    -- Размер бокса (зависит от расстояния)
    local head = character:FindFirstChild("Head")
    local rootPos = hrp.Position
    local headPos = head and head.Position or (rootPos + Vector3.new(0, 3, 0))
    
    local rootScreen, rootOnScreen = Camera:WorldToViewportPoint(rootPos)
    local headScreen, headOnScreen = Camera:WorldToViewportPoint(headPos)
    
    if not rootOnScreen and not headOnScreen then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Рассчитываем размер бокса
    local height = math.abs(headScreen.Y - rootScreen.Y)
    local width = height * 0.6   -- соотношение сторон персонажа Roblox
    
    local topLeft = Vector2.new(rootScreen.X - width / 2, headScreen.Y)
    local topRight = Vector2.new(rootScreen.X + width / 2, headScreen.Y)
    local bottomLeft = Vector2.new(rootScreen.X - width / 2, rootScreen.Y)
    local bottomRight = Vector2.new(rootScreen.X + width / 2, rootScreen.Y)
    
    -- Обновляем линии: Top, Right, Bottom, Left
    local l = box.lines
    l[1].From = topLeft;     l[1].To = topRight
    l[2].From = topRight;    l[2].To = bottomRight
    l[3].From = bottomRight; l[3].To = bottomLeft
    l[4].From = bottomLeft;  l[4].To = topLeft
    
    for _, line in pairs(l) do
        line.Visible = true
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
    end
end

-- Главный цикл
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

-- Изменить цвет (можно привязать к Colorpicker из Mentality)
function BoxESP:SetColor(color)
    self.Color = color
end

-- Полностью выгрузить модуль (убить все линии)
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
