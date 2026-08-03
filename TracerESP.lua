-- ============================================
--  TracerESP Module by nitarte (v2)
--  Рисует линии от игрока к другим игрокам
-- ============================================

local TracerESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 116, 224),
    Thickness = 1,
    MaxDistance = 2000,
    TeamCheck = false,
    OffsetY = 0,

    _players = {},
    _connection = nil,
    _cleaning = false,
    _frameCounter = 0
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Проверка поддержки Drawing.Line
local canDrawLine = pcall(function()
    local l = Drawing.new("Line")
    l:Remove()
end)

if not canDrawLine then
    return {
        Toggle = function() end,
        SetColor = function() end,
        SetThickness = function() end,
        SetMaxDistance = function() end,
        SetOffsetY = function() end,
        Unload = function() end,
    }
end

-- ============================================
--  СОЗДАНИЕ ЛИНИИ
-- ============================================
function TracerESP:_createPlayerObjects(player)
    local objects = {
        player = player,
        line = nil,
        character = nil,
        visible = false
    }

    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = self.Color
    line.Thickness = self.Thickness
    line.Transparency = 1

    objects.line = line
    self._players[player] = objects
    return objects
end

-- ============================================
--  УДАЛЕНИЕ
-- ============================================
function TracerESP:_removePlayer(player)
    local objs = self._players[player]
    if objs then
        if objs.line then objs.line:Remove() end
        self._players[player] = nil
    end
end

function TracerESP:_clearAll()
    if self._cleaning then return end
    self._cleaning = true
    for player, objs in pairs(self._players) do
        if objs.line then objs.line:Remove() end
    end
    table.clear(self._players)
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._cleaning = false
end

-- ============================================
--  ОБНОВЛЕНИЕ ЛИНИИ
-- ============================================
function TracerESP:_updatePlayer(objs)
    local player = objs.player
    if not player or not player.Parent then
        self:_removePlayer(player)
        return
    end

    local localChar = LocalPlayer.Character
    if not localChar then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local localHrp = localChar:FindFirstChild("HumanoidRootPart")
    if not localHrp then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local character = player.Character
    if objs.character ~= character then
        objs.character = character
        objs.visible = false
    end

    if not character then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not hrp or not humanoid or humanoid.Health <= 0 then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    if self.TeamCheck and player.Team == LocalPlayer.Team then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local distance = (hrp.Position - localHrp.Position).Magnitude
    if distance > self.MaxDistance then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local localPos, localOn = Camera:WorldToViewportPoint(localHrp.Position)
    local targetPos, targetOn = Camera:WorldToViewportPoint(hrp.Position)

    if not localOn or not targetOn then
        if objs.visible then
            objs.line.Visible = false
            objs.visible = false
        end
        return
    end

    local line = objs.line
    if not line then return end

    line.From = Vector2.new(localPos.X, localPos.Y + self.OffsetY)
    line.To = Vector2.new(targetPos.X, targetPos.Y + self.OffsetY)
    line.Visible = true
    line.Color = self.Color
    line.Thickness = self.Thickness
    line.Transparency = 1

    objs.visible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ
-- ============================================
function TracerESP:_startLoop()
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

function TracerESP:Toggle(state)
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
            if objs.line then objs.line.Visible = false end
            objs.visible = false
        end
    end
end

function TracerESP:SetColor(color)
    self.Color = color
    for _, objs in pairs(self._players) do
        if objs.line then objs.line.Color = color end
    end
end

function TracerESP:SetThickness(thickness)
    self.Thickness = math.max(thickness, 0.5)
    for _, objs in pairs(self._players) do
        if objs.line then objs.line.Thickness = self.Thickness end
    end
end

function TracerESP:SetMaxDistance(distance)
    self.MaxDistance = math.max(distance, 10)
end

function TracerESP:SetOffsetY(offset)
    self.OffsetY = offset or 0
end

function TracerESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

Players.PlayerRemoving:Connect(function(player)
    if TracerESP._players[player] then
        TracerESP:_removePlayer(player)
    end
end)

return TracerESP
