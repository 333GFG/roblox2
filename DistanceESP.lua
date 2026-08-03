-- ============================================
--  DistanceESP Module by nitarte (с ЛОГАМИ)
--  Отображает расстояние до игроков (в студиях)
-- ============================================

print("[DistanceESP] Модуль начал загрузку")

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

print("[DistanceESP] Сервисы получены")

-- Проверка поддержки Drawing.Text
local canDrawText = pcall(function()
    local t = Drawing.new("Text")
    t:Remove()
end)

if not canDrawText then
    warn("[DistanceESP] Drawing.Text НЕ ПОДДЕРЖИВАЕТСЯ! Возвращаем заглушку.")
    return {
        Toggle = function() end,
        SetColor = function() end,
        SetSize = function() end,
        SetPosition = function() end,
        SetOffsetY = function() end,
        Unload = function() end,
    }
end

print("[DistanceESP] Drawing.Text поддерживается")

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
    print("[DistanceESP] _createPlayerObjects для", player.Name)
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
    text.Font = Enum.Font.GothamBold
    text.Text = "0"

    objects.text = text
    self._players[player] = objects
    print("[DistanceESP] Объекты созданы для", player.Name)
    return objects
end

-- ============================================
--  УДАЛЕНИЕ
-- ============================================
function DistanceESP:_removePlayer(player)
    print("[DistanceESP] _removePlayer для", player and player.Name or "nil")
    local objs = self._players[player]
    if objs then
        if objs.text then objs.text:Remove() end
        self._players[player] = nil
    end
end

function DistanceESP:_clearAll()
    print("[DistanceESP] _clearAll")
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
        print("[DistanceESP] _updatePlayer: игрок удалён, удаляем объекты")
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

    -- Расстояние от камеры до игрока
    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    local distText = string.format("%.0f", distance)

    -- Проекция головы на экран
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
    if not text then
        warn("[DistanceESP] text is nil для", player.Name)
        return
    end

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
    if self._connection then
        print("[DistanceESP] _startLoop: цикл уже запущен")
        return
    end
    print("[DistanceESP] _startLoop: запускаем цикл")
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        self._frameCounter = self._frameCounter + 1
        if self._frameCounter % 2 ~= 0 then return end

        -- Добавляем новых игроков
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createPlayerObjects(player)
            end
        end

        -- Обновляем все дистанции
        for _, objs in pairs(self._players) do
            self:_updatePlayer(objs)
        end
    end)
    print("[DistanceESP] Цикл успешно запущен")
end

-- ============================================
--  ПУБЛИЧНЫЕ МЕТОДЫ
-- ============================================

function DistanceESP:Toggle(state)
    print("[DistanceESP] Toggle вызван со значением:", state)
    self.Enabled = state
    if state then
        print("[DistanceESP] Включаем ESP, создаём объекты для всех игроков")
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self._players[player] then
                self:_createPlayerObjects(player)
            end
        end
        self:_startLoop()
        print("[DistanceESP] ESP включён")
    else
        print("[DistanceESP] Выключаем ESP")
        for _, objs in pairs(self._players) do
            if objs.text then objs.text.Visible = false end
            objs.visible = false
        end
        print("[DistanceESP] ESP выключен")
    end
end

function DistanceESP:SetColor(color)
    print("[DistanceESP] SetColor вызван")
    self.Color = color
    for _, objs in pairs(self._players) do
        if objs.text then objs.text.Color = color end
    end
end

function DistanceESP:SetSize(size)
    print("[DistanceESP] SetSize вызван, размер:", size)
    self.Size = math.max(size, 8)
    for _, objs in pairs(self._players) do
        if objs.text then objs.text.Size = self.Size end
    end
end

function DistanceESP:SetPosition(pos)
    print("[DistanceESP] SetPosition вызван, позиция:", pos)
    self.Position = pos or "Center"
end

function DistanceESP:SetOffsetY(offset)
    print("[DistanceESP] SetOffsetY вызван, смещение:", offset)
    self.OffsetY = offset or 0
end

function DistanceESP:Unload()
    print("[DistanceESP] Unload вызван")
    self:_clearAll()
    self.Enabled = false
    print("[DistanceESP] Выгружен")
end

-- Авто-удаление при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if DistanceESP._players[player] then
        DistanceESP:_removePlayer(player)
    end
end)

print("[DistanceESP] Модуль успешно загружен!")
return DistanceESP
