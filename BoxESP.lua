-- ============================================
--  BoxESP Module by nitarte (v5.2 — исправление зависаний)
--  Обновляется каждый кадр через RenderStepped
--  Полная перезагрузка бокса при смене персонажа
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1.5,
    Transparency = 1,
    TeamCheck = false,
    MaxDistance = 2000,
    UseOutline = true,
    
    _players = {},
    _connection = nil,
    _cleaning = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================
--  ПОЛУЧИТЬ НИЖНЮЮ ТОЧКУ (ноги) — кэшируем части
-- ============================================
local function GetBottomPart(character)
    if not character then return nil end
    -- Ищем ноги
    local leftFoot = character:FindFirstChild("LeftFoot")
    local rightFoot = character:FindFirstChild("RightFoot")
    if leftFoot and rightFoot then
        return (leftFoot.Position + rightFoot.Position) / 2
    end
    local leftLeg = character:FindFirstChild("Left Leg")
    local rightLeg = character:FindFirstChild("Right Leg")
    if leftLeg and rightLeg then
        return (leftLeg.Position + rightLeg.Position) / 2
    end
    -- R6 или другие
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position - Vector3.new(0, 2.5, 0)
    end
    -- Fallback: просто корень
    return nil
end

-- ============================================
--  СОЗДАНИЕ ЛИНИЙ
-- ============================================
function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
        character = nil,   -- запоминаем персонажа для проверки
        visible = false
    }
    
    local count = self.UseOutline and 8 or 4
    for i = 1, count do
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
--  ОБНОВЛЕНИЕ БОКСА (синхронизировано с рендером)
-- ============================================
function BoxESP:_updateBox(box)
    if not box.player or not box.player.Parent then
        self:_removeBox(box.player)
        return
    end
    
    local character = box.player.Character
    -- Если персонаж изменился (перерождение) – пересоздаём бокс
    if box.character ~= character then
        -- Удаляем старые линии и создаём новые
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        local count = self.UseOutline and 8 or 4
        box.lines = {}
        for i = 1, count do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Transparency = self.Transparency
            table.insert(box.lines, line)
        end
        box.character = character
        box.visible = false
    end
    
    if not character then
        if box.visible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.visible = false
        end
        return
    end
    
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local bottomPos = GetBottomPart(character)
    
    if not head or not humanoid or humanoid.Health <= 0 or not bottomPos then
        if box.visible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.visible = false
        end
        return
    end
    
    if self.TeamCheck and box.player.Team == LocalPlayer.Team then
        if box.visible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.visible = false
        end
        return
    end
    
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        if box.visible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.visible = false
        end
        return
    end
    
    local headScreen, headOn = Camera:WorldToViewportPoint(head.Position)
    local bottomScreen, bottomOn = Camera:WorldToViewportPoint(bottomPos)
    
    if not headOn and not bottomOn then
        if box.visible then
            for _, line in pairs(box.lines) do line.Visible = false end
            box.visible = false
        end
        return
    end
    
    -- Расчёт углов (каждый кадр)
    local height = math.abs(bottomScreen.Y - headScreen.Y)
    if height < 1 then height = 1 end
    local width = height * 0.7
    local centerX = (headScreen.X + bottomScreen.X) / 2
    local topY = headScreen.Y - height * 0.08
    local bottomY = bottomScreen.Y + height * 0.05
    height = bottomY - topY
    width = height * 0.6
    
    local topLeft = Vector2.new(centerX - width/2, topY)
    local topRight = Vector2.new(centerX + width/2, topY)
    local bottomLeft = Vector2.new(centerX - width/2, bottomY)
    local bottomRight = Vector2.new(centerX + width/2, bottomY)
    
    local lines = box.lines
    local color = self.Color
    local thickness = self.Thickness
    local outlineThickness = thickness + 2
    
    if self.UseOutline then
        lines[1].From = topLeft;      lines[1].To = topRight;       lines[1].Color = Color3.new(0,0,0); lines[1].Thickness = outlineThickness
        lines[2].From = topRight;     lines[2].To = bottomRight;    lines[2].Color = Color3.new(0,0,0); lines[2].Thickness = outlineThickness
        lines[3].From = bottomRight;  lines[3].To = bottomLeft;     lines[3].Color = Color3.new(0,0,0); lines[3].Thickness = outlineThickness
        lines[4].From = bottomLeft;   lines[4].To = topLeft;        lines[4].Color = Color3.new(0,0,0); lines[4].Thickness = outlineThickness
        lines[5].From = topLeft;      lines[5].To = topRight;       lines[5].Color = color; lines[5].Thickness = thickness
        lines[6].From = topRight;     lines[6].To = bottomRight;    lines[6].Color = color; lines[6].Thickness = thickness
        lines[7].From = bottomRight;  lines[7].To = bottomLeft;     lines[7].Color = color; lines[7].Thickness = thickness
        lines[8].From = bottomLeft;   lines[8].To = topLeft;        lines[8].Color = color; lines[8].Thickness = thickness
        for i = 1, 8 do lines[i].Visible = true end
    else
        lines[1].From = topLeft;      lines[1].To = topRight;       lines[1].Color = color; lines[1].Thickness = thickness
        lines[2].From = topRight;     lines[2].To = bottomRight;    lines[2].Color = color; lines[2].Thickness = thickness
        lines[3].From = bottomRight;  lines[3].To = bottomLeft;     lines[3].Color = color; lines[3].Thickness = thickness
        lines[4].From = bottomLeft;   lines[4].To = topLeft;        lines[4].Color = color; lines[4].Thickness = thickness
        for i = 1, 4 do lines[i].Visible = true end
    end
    
    box.visible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ (RenderStepped)
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

function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        self:_startLoop()
    else
        for _, box in pairs(self._players) do
            for _, line in pairs(box.lines) do
                line.Visible = false
            end
            box.visible = false
        end
    end
end

function BoxESP:SetColor(color)
    self.Color = color
    for _, box in pairs(self._players) do
        local lines = box.lines
        local start = self.UseOutline and 5 or 1
        local count = self.UseOutline and 8 or 4
        for i = start, count do
            lines[i].Color = color
        end
    end
end

function BoxESP:SetOutline(enable)
    if self.UseOutline == enable then return end
    self.UseOutline = enable
    for player, box in pairs(self._players) do
        for _, line in pairs(box.lines) do
            line:Remove()
        end
        self._players[player] = self:_createBox(player)
    end
end

function BoxESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

-- ============================================
--  АВТО-ОЧИСТКА ПРИ ВЫХОДЕ ИГРОКА
-- ============================================
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
