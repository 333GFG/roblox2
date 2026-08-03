-- ============================================
--  BoxESP Module by nitarte (v4.0 — РАБОЧИЙ)
--  2D Box ESP вокруг ВСЕГО персонажа (включая ноги)
--  Основан на: Blissful4992 + WA-ESP
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

-- ============================================
--  ПОЛУЧИТЬ НИЖНЮЮ ТОЧКУ ПЕРСОНАЖА (ноги)
-- ============================================
local function GetBottomPart(character)
    -- R15
    local leftFoot = character:FindFirstChild("LeftFoot")
    local rightFoot = character:FindFirstChild("RightFoot")
    if leftFoot and rightFoot then
        -- Возвращаем точку между ног (среднее арифметическое)
        return (leftFoot.Position + rightFoot.Position) / 2
    end
    
    -- R6
    local leftLeg = character:FindFirstChild("Left Leg")
    local rightLeg = character:FindFirstChild("Right Leg")
    if leftLeg and rightLeg then
        return (leftLeg.Position + rightLeg.Position) / 2
    end
    
    -- Fallback на HumanoidRootPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position - Vector3.new(0, 2.5, 0)  -- примерно на уровне ног
    end
    
    return nil
end

-- ============================================
--  СОЗДАНИЕ ЛИНИЙ
-- ============================================
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
    }
    
    -- 4 линии основного бокса + 4 для outline
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
--  ОБНОВЛЕНИЕ БОКСА
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
    
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local bottomPos = GetBottomPart(character)
    
    if not head or not humanoid or humanoid.Health <= 0 or not bottomPos then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- TeamCheck
    if self.TeamCheck and box.player.Team == LocalPlayer.Team then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Дистанция от камеры до головы
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Проецируем на экран
    local headScreen, headOnScreen = Camera:WorldToViewportPoint(head.Position)
    local bottomScreen, bottomOnScreen = Camera:WorldToViewportPoint(bottomPos)
    
    if not headOnScreen and not bottomOnScreen then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- ============================================
    --  РАСЧЁТ РАЗМЕРА БОКСА (от головы до ног)
    -- ============================================
    
    -- Высота = от головы до ног на экране
    local height = math.abs(bottomScreen.Y - headScreen.Y)
    
    -- Ширина = высота * 0.6 (пропорции персонажа Roblox)
    -- Увеличиваем до 0.7, чтобы точно захватить руки
    local width = height * 0.7
    
    -- Центр по X
    local centerX = (headScreen.X + bottomScreen.X) / 2
    
    -- Верхняя точка (немного выше головы)
    local topY = headScreen.Y - height * 0.08
    
    -- Нижняя точка (немного ниже ног)
    local bottomY = bottomScreen.Y + height * 0.05
    
    -- Пересчитываем высоту с отступами
    height = bottomY - topY
    width = height * 0.6
    
    -- Углы бокса
    local topLeft     = Vector2.new(centerX - width / 2, topY)
    local topRight    = Vector2.new(centerX + width / 2, topY)
    local bottomRight = Vector2.new(centerX + width / 2, bottomY)
    local bottomLeft  = Vector2.new(centerX - width / 2, bottomY)
    
    -- ============================================
    --  ОБНОВЛЯЕМ ЛИНИИ (1-4 = outline, 5-8 = цвет)
    -- ============================================
    
    local lines = box.lines
    local color = self.Color
    local thickness = self.Thickness
    local outlineThickness = thickness + 2
    
    -- Outline (чёрная обводка)
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
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ
-- ============================================
function BoxESP:_startLoop()
    if self._connection then return end
    
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createBox(player)
            end
        end
        
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
