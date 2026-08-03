-- ============================================
--  BoxESP Module by nitarte (v3.0 — РАБОЧИЙ)
--  Рабочий 2D Box ESP вокруг персонажа
--  Основан на: Blissful4992 (проверенный метод)
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
    _cleaning = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
-- В BoxESP.lua добавь:
BoxESP.ShowSelf = false  -- по умолчанию выключено
-- ============================================
--  СОЗДАНИЕ ЛИНИЙ ДЛЯ ОДНОГО ИГРОКА
-- ============================================
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
    }
    
    -- 4 линии для полного бокса + 4 для outline (чёрная обводка)
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
--  ОБНОВЛЕНИЕ БОКСА (ГЛАВНАЯ ФУНКЦИЯ)
-- ============================================
function BoxESP:_updateBox(box)
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
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not head or not humanoid or humanoid.Health <= 0 then
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
    
    -- ПРОВЕРЯЕМ ВИДИМОСТЬ НА ЭКРАНЕ
    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
    local hrpPos, hrpOnScreen = Camera:WorldToViewportPoint(hrp.Position)
    
    if not headOnScreen and not hrpOnScreen then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- ============================================
    --  РАСЧЁТ РАЗМЕРА БОКСА (метод Blissful4992)
    -- ============================================
    
    -- Высота бокса = расстояние от головы до HRP на экране
    local height = math.abs(headPos.Y - hrpPos.Y)
    
    -- Ширина = высота * 0.65 (пропорции персонажа Roblox)
    -- Увеличиваем множитель, чтобы захватить руки
    local width = height * 0.75
    
    -- Центр бокса по X = середина между головой и HRP
    local centerX = (headPos.X + hrpPos.X) / 2
    
    -- Верхняя точка бокса (немного выше головы)
    local topY = headPos.Y - height * 0.15
    
    -- Координаты углов бокса
    local topLeft     = Vector2.new(centerX - width / 2, topY)
    local topRight    = Vector2.new(centerX + width / 2, topY)
    local bottomRight = Vector2.new(centerX + width / 2, hrpPos.Y + height * 0.15)
    local bottomLeft  = Vector2.new(centerX - width / 2, hrpPos.Y + height * 0.15)
    
    -- ============================================
    --  ОБНОВЛЯЕМ ЛИНИИ (1-4 = outline, 5-8 = основной цвет)
    -- ============================================
    
    local lines = box.lines
    local color = self.Color
    local thickness = self.Thickness
    local outlineThickness = thickness + 2
    
    -- Outline (чёрная обводка) — линии 1-4
    lines[1].From = topLeft;      lines[1].To = topRight;       lines[1].Color = Color3.new(0, 0, 0); lines[1].Thickness = outlineThickness
    lines[2].From = topRight;     lines[2].To = bottomRight;    lines[2].Color = Color3.new(0, 0, 0); lines[2].Thickness = outlineThickness
    lines[3].From = bottomRight;  lines[3].To = bottomLeft;     lines[3].Color = Color3.new(0, 0, 0); lines[3].Thickness = outlineThickness
    lines[4].From = bottomLeft;   lines[4].To = topLeft;        lines[4].Color = Color3.new(0, 0, 0); lines[4].Thickness = outlineThickness
    
    -- Основной бокс — линии 5-8
    lines[5].From = topLeft;      lines[5].To = topRight;       lines[5].Color = color; lines[5].Thickness = thickness
    lines[6].From = topRight;     lines[6].To = bottomRight;    lines[6].Color = color; lines[6].Thickness = thickness
    lines[7].From = bottomRight;  lines[7].To = bottomLeft;     lines[7].Color = color; lines[7].Thickness = thickness
    lines[8].From = bottomLeft;   lines[8].To = topLeft;        lines[8].Color = color; lines[8].Thickness = thickness
    
    -- Показываем все линии
    for _, line in pairs(lines) do
        line.Visible = true
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
            if (player ~= LocalPlayer or self.ShowSelf) and not self._players[player] then
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

-- ============================================
--  АВТО-ОЧИСТКА
-- ============================================
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
