-- ============================================
--  HealthESP Module by nitarte (исправленный)
--  Вертикальная полоска здоровья справа от игрока
-- ============================================

local HealthESP = {
    Enabled = false,
    ColorLow = Color3.fromRGB(255, 50, 50),
    ColorHigh = Color3.fromRGB(50, 255, 50),
    Width = 6,
    OffsetX = 10,
    Position = "Right",
    
    _players = {},
    _connection = nil,
    _cleaning = false,
    _frameCounter = 0
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Проверка поддержки Drawing.Square
local canDrawSquare = pcall(function()
    local s = Drawing.new("Square")
    s:Remove()
end)

if not canDrawSquare then
    return {
        Toggle = function() end,
        SetColors = function() end,
        SetWidth = function() end,
        SetOffset = function() end,
        SetPosition = function() end,
        Unload = function() end,
    }
end

-- ============================================
--  ПОЛУЧИТЬ НИЖНЮЮ ТОЧКУ (ноги)
-- ============================================
local function GetBottomPart(character)
    if not character then return nil end
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
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position - Vector3.new(0, 2.5, 0)
    end
    return nil
end

-- ============================================
--  СОЗДАНИЕ ОБЪЕКТОВ
-- ============================================
function HealthESP:_createPlayerObjects(player)
    local objects = {
        player = player,
        background = nil,
        fill = nil,
        visible = false
    }
    
    local bg = Drawing.new("Square")
    bg.Visible = false
    bg.Color = Color3.fromRGB(30, 30, 30)
    bg.Thickness = 0
    bg.Filled = true
    bg.Transparency = 0.5
    
    local fill = Drawing.new("Square")
    fill.Visible = false
    fill.Color = self.ColorHigh
    fill.Thickness = 0
    fill.Filled = true
    fill.Transparency = 0.8
    
    objects.background = bg
    objects.fill = fill
    self._players[player] = objects
    return objects
end

-- ============================================
--  УДАЛЕНИЕ
-- ============================================
function HealthESP:_removePlayer(player)
    local objs = self._players[player]
    if objs then
        if objs.background then objs.background:Remove() end
        if objs.fill then objs.fill:Remove() end
        self._players[player] = nil
    end
end

function HealthESP:_clearAll()
    if self._cleaning then return end
    self._cleaning = true
    for player, objs in pairs(self._players) do
        if objs.background then objs.background:Remove() end
        if objs.fill then objs.fill:Remove() end
    end
    table.clear(self._players)
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._cleaning = false
end

-- ============================================
--  ОБНОВЛЕНИЕ ПОЛОСКИ
-- ============================================
function HealthESP:_updatePlayer(objs)
    local player = objs.player
    if not player or not player.Parent then
        self:_removePlayer(player)
        return
    end
    
    local character = player.Character
    if not character then
        if objs.visible then
            objs.background.Visible = false
            objs.fill.Visible = false
            objs.visible = false
        end
        return
    end
    
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local bottomPos = GetBottomPart(character)
    
    if not head or not humanoid or humanoid.Health <= 0 or not bottomPos then
        if objs.visible then
            objs.background.Visible = false
            objs.fill.Visible = false
            objs.visible = false
        end
        return
    end
    
    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local healthPercent = math.clamp(health / maxHealth, 0, 1)
    
    local headScreen, headOn = Camera:WorldToViewportPoint(head.Position)
    local bottomScreen, bottomOn = Camera:WorldToViewportPoint(bottomPos)
    
    if not headOn and not bottomOn then
        if objs.visible then
            objs.background.Visible = false
            objs.fill.Visible = false
            objs.visible = false
        end
        return
    end
    
    local height = math.abs(bottomScreen.Y - headScreen.Y)
    if height < 1 then height = 1 end   -- ✅ исправлено: добавлен end
    local barHeight = height + 10
    local barWidth = self.Width
    
    local centerX = (headScreen.X + bottomScreen.X) / 2
    local topY = headScreen.Y - 5
    local bottomY = bottomScreen.Y + 5
    
    local barX
    if self.Position == "Left" then
        barX = centerX - barWidth - self.OffsetX
    else
        barX = centerX + self.OffsetX
    end
    
    objs.background.Position = Vector2.new(barX, topY)
    objs.background.Size = Vector2.new(barWidth, barHeight)
    objs.background.Visible = true
    objs.background.Color = Color3.fromRGB(30, 30, 30)
    
    local fillHeight = barHeight * healthPercent
    local fillY = topY + (barHeight - fillHeight)
    local color = self.ColorLow:Lerp(self.ColorHigh, healthPercent)
    
    objs.fill.Position = Vector2.new(barX, fillY)
    objs.fill.Size = Vector2.new(barWidth, fillHeight)
    objs.fill.Visible = true
    objs.fill.Color = color
    objs.fill.Transparency = 0.8
    
    objs.visible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ
-- ============================================
function HealthESP:_startLoop()
    if self._connection then return end
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end
        
        self._frameCounter = self._frameCounter + 1
        if self._frameCounter % 2 ~= 0 then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createPlayerObjects(player)
            end
        end
        
        for _, objs in pairs(self._players) do
            self:_updatePlayer(objs)
        end
    end)
end

-- ============================================
--  ПУБЛИЧНЫЕ МЕТОДЫ
-- ============================================

function HealthESP:Toggle(state)
    self.Enabled = state
    if state then
        self:_startLoop()
    else
        for _, objs in pairs(self._players) do
            if objs.background then objs.background.Visible = false end
            if objs.fill then objs.fill.Visible = false end
            objs.visible = false
        end
    end
end

function HealthESP:SetColors(lowColor, highColor)
    self.ColorLow = lowColor or self.ColorLow
    self.ColorHigh = highColor or self.ColorHigh
end

function HealthESP:SetWidth(width)
    self.Width = math.max(width, 2)
end

function HealthESP:SetOffset(offsetX, offsetY)
    self.OffsetX = offsetX or self.OffsetX
end

function HealthESP:SetPosition(pos)
    if pos == "Left" or pos == "Right" then
        self.Position = pos
    end
end

function HealthESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

Players.PlayerRemoving:Connect(function(player)
    if HealthESP._players[player] then
        HealthESP:_removePlayer(player)
    end
end)

return HealthESP
