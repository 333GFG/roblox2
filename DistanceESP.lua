-- ============================================
--  DistanceESP Module by nitarte
--  Отображает расстояние до игроков (в студиях)
--  Добавлена буква "m" после числа
-- ============================================

local DistanceESP = {
    Enabled = false,
    Color = Color3.fromRGB(255, 255, 255),
    Size = 14,
    Position = "Center",
    OffsetY = -25,

    _players = {},
    _connection = nil,
    _cleaning = false,
    _frameCounter = 0
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Проверка поддержки Drawing.Text
local canDrawText = pcall(function()
    local t = Drawing.new("Text")
    t:Remove()
end)

if not canDrawText then
    return {
        Toggle = function() end,
        SetColor = function() end,
        SetSize = function() end,
        SetPosition = function() end,
        SetOffsetY = function() end,
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
--  СОЗДАНИЕ ТЕКСТА ДЛЯ ИГРОКА
-- ============================================
function DistanceESP:_createPlayerObjects(player)
    local objects = {
        player = player,
        text = nil,
        character = nil,
        visible = false
    }

    local text = Drawing.new("Text")
    text.Visible = false
    text.Color = self.Color
    text.Size = self.Size
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.new(0, 0, 0)
    text.Text = "0"

    objects.text = text
    self._players[player] = objects
    return objects
end

-- ============================================
--  УДАЛЕНИЕ
-- ============================================
function DistanceESP:_removePlayer(player)
    local objs = self._players[player]
    if objs then
        if objs.text then objs.text:Remove() end
        self._players[player] = nil
    end
end

function DistanceESP:_clearAll()
    if self._cleaning then return end
    self._cleaning = true
    for player, objs in pairs(self._players) do
        if objs.text then objs.text:Remove() end
    end
    table.clear(self._players)
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._cleaning = false
end

-- ============================================
--  ОБНОВЛЕНИЕ ДИСТАНЦИИ
-- ============================================
function DistanceESP:_updatePlayer(objs)
    local player = objs.player
    if not player or not player.Parent then
        self:_removePlayer(player)
        return
    end

    local character = player.Character
    if objs.character ~= character then
        objs.character = character
        objs.visible = false
    end

    if not character then
        if objs.visible then
            objs.text.Visible = false
            objs.visible = false
        end
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not hrp or not humanoid or humanoid.Health <= 0 then
        if objs.visible then
            objs.text.Visible = false
            objs.visible = false
        end
        return
    end

    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    local distText = string.format("%.0fm", distance)   -- ✅ добавлена буква m

    local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))
    local headScreen, headOn = Camera:WorldToViewportPoint(headPos)

    if not headOn then
        if objs.visible then
            objs.text.Visible = false
            objs.visible = false
        end
        return
    end

    local text = objs.text
    if not text then return end

    text.Visible = true
    text.Color = self.Color
    text.Size = self.Size
    text.Text = distText
    text.Position = Vector2.new(headScreen.X, headScreen.Y + self.OffsetY)

    objs.visible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ
-- ============================================
function DistanceESP:_startLoop()
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

function DistanceESP:Toggle(state)
    self.Enabled = state
    if state then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createPlayerObjects(player)
            end
        end
        self:_startLoop()
    else
        for _, objs in pairs(self._players) do
            if objs.text then objs.text.Visible = false end
            objs.visible = false
        end
    end
end

function DistanceESP:SetColor(color)
    self.Color = color
    for _, objs in pairs(self._players) do
        if objs.text then objs.text.Color = color end
    end
end

function DistanceESP:SetSize(size)
    self.Size = math.max(size, 8)
    for _, objs in pairs(self._players) do
        if objs.text then objs.text.Size = self.Size end
    end
end

function DistanceESP:SetPosition(pos)
    self.Position = pos or "Center"
end

function DistanceESP:SetOffsetY(offset)
    self.OffsetY = offset or 0
end

function DistanceESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

Players.PlayerRemoving:Connect(function(player)
    if DistanceESP._players[player] then
        DistanceESP:_removePlayer(player)
    end
end)

return DistanceESP
