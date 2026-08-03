-- ============================================
--  BoxESP Module by nitarte (оптимизированный)
--  Идеальный 2D Box ESP с расчётом по размеру персонажа
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,
    MaxDistance = 2000,

    _players = {},
    _connection = nil,
    _cleaning = false,
    _cache = {} -- для кэширования позиций линий
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Создание 4 линий
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        lastTopLeft = nil,
        lastTopRight = nil,
        lastBottomLeft = nil,
        lastBottomRight = nil
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

-- Удаление бокса
function BoxESP:_removeBox(player)
    local box = self._players[player]
    if box then
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        self._players[player] = nil
    end
end

-- Очистка всех
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

-- Функция для получения габаритов персонажа (голова и стопы)
local function GetCharacterBounds(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil, nil end
    
    -- Ищем голову
    local head = character:FindFirstChild("Head")
    local headPos
    if head then
        headPos = head.Position
    else
        -- Если головы нет, берём верхнюю точку HumanoidRootPart + половина роста
        local rootPos = hrp.Position
        local hipHeight = humanoid.HipHeight or 2
        headPos = rootPos + Vector3.new(0, hipHeight + 1, 0) -- приблизительно
    end
    
    local footPos = hrp.Position - Vector3.new(0, humanoid.HipHeight or 2, 0)
    return headPos, footPos
end

-- Обновление бокса (с кэшированием)
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
    
    local headPos, footPos = GetCharacterBounds(character)
    if not headPos then
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
    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Проекция на экран
    local headScreen, headOn = Camera:WorldToViewportPoint(headPos)
    local footScreen, footOn = Camera:WorldToViewportPoint(footPos)
    
    if not headOn and not footOn then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Расчёт ширины по высоте
    local height = math.abs(headScreen.Y - footScreen.Y)
    local width = height * 0.55   -- соотношение сторон (можно подкрутить)
    
    local centerX = (headScreen.X + footScreen.X) / 2
    local topY = headScreen.Y
    local bottomY = footScreen.Y
    
    local leftX = centerX - width / 2
    local rightX = centerX + width / 2
    
    local topLeft = Vector2.new(leftX, topY)
    local topRight = Vector2.new(rightX, topY)
    local bottomLeft = Vector2.new(leftX, bottomY)
    local bottomRight = Vector2.new(rightX, bottomY)
    
    -- Обновляем линии только если координаты изменились
    if box.lastTopLeft ~= topLeft or box.lastTopRight ~= topRight or 
       box.lastBottomLeft ~= bottomLeft or box.lastBottomRight ~= bottomRight then
        local l = box.lines
        l[1].From = topLeft;     l[1].To = topRight
        l[2].From = topRight;    l[2].To = bottomRight
        l[3].From = bottomRight; l[3].To = bottomLeft
        l[4].From = bottomLeft;  l[4].To = topLeft
        
        box.lastTopLeft = topLeft
        box.lastTopRight = topRight
        box.lastBottomLeft = bottomLeft
        box.lastBottomRight = bottomRight
    end
    
    -- Показываем линии
    for _, line in pairs(box.lines) do
        line.Visible = true
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
    end
end

-- Главный цикл (RenderStepped)
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

-- Публичные методы
function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        -- Создаём для всех существующих (включая себя)
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

-- Автоудаление при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
