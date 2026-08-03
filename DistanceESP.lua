-- ============================================
--  DistanceESP Module by nitarte
--  Отображает расстояние до игроков (в студиях)
-- ============================================

local DistanceESP = {
    Enabled = false,
    Color = Color3.fromRGB(255, 255, 255),
    Size = 14,
    Position = "Center",  -- "Left", "Center", "Right" (относительно бокса)
    OffsetY = -25,        -- смещение по вертикали (отрицательное = выше)
    
    _players = {},
    _connection = nil,
    _cleaning = false
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
        Unload = function() end,
    }
end

-- ============================================
--  ПОЛУЧИТЬ НИЖНЮЮ ТОЧКУ (ноги) – для высоты бокса
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
    text.Center = false
    text.Outline = true
    text.OutlineColor = Color3.new(0, 0, 0)
    text.Font = Enum.Font.GothamBold
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
    local bottomPos = GetBottomPart(character)

    if not hrp or not humanoid or humanoid.Health <= 0 then
        if objs.visible then
            objs.text.Visible = false
            objs.visible = false
        end
        return
    end

    -- Вычисляем расстояние от камеры до игрока
    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    local distText = string.format("%.0f", distance)  -- целое число

    -- Проекция головы и нижней точки для определения позиции
    local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))
    local headScreen, headOn = Camera:WorldToViewportPoint(headPos)

    if not headOn then
        if objs.visible then
            objs.text.Visible = false
            objs.visible = false
        end
        return
    end

    -- Используем позицию головы, чтобы разместить текст над ней
    local textX = headScreen.X
    local textY = headScreen.Y + self.OffsetY  -- выше головы (отрицательное смещение)

    -- Сдвиг в зависимости от Position (Left/Center/Right) относительно головы
    -- Но у нас нет ширины бокса, поэтому используем просто смещение от центра.
    -- Проще: если Position == "Center", то оставляем как есть.
    -- Если "Left" или "Right", сдвигаем в сторону.
    -- Для простоты можно оставить только Center и добавить OffsetX.
    -- Но пользователь может захотеть слева/справа, как в Name ESP.
    -- Однако у нас нет бокса, чтобы вычислить ширину. Поэтому предлагаю просто размещать над головой по центру,
    -- а сдвиг по X задавать через отдельный параметр или игнорировать Position.
    -- Лучше сделать как в Name ESP: используем ширину бокса, если BoxESP активен?
    -- Но это усложнит. Предлагаю размещать над головой по центру, а Position использовать для
    -- горизонтального выравнивания относительно головы (но без учёта ширины).

    -- Сделаем так: определяем ширину головы (примерно) и сдвигаем.
    -- Но проще: использовать OffsetX отдельно.
    -- Для этого добавим свойство OffsetX = 0 по умолчанию.
    -- Пока оставим только OffsetY.

    -- Обновляем текст
    local text = objs.text
    text.Visible = true
    text.Color = self.Color
    text.Size = self.Size
    text.Text = distText

    -- Центрируем текст по X относительно головы
    local textBounds = text.TextBounds
    text.Position = Vector2.new(textX - textBounds.X / 2, textY)

    objs.visible = true
end

-- ============================================
--  ГЛАВНЫЙ ЦИКЛ (обновление раз в 2 кадра)
-- ============================================
function DistanceESP:_startLoop()
    if self._connection then return end
    self._connection = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end

        self._frameCounter = (self._frameCounter or 0) + 1
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
end

-- ============================================
--  ПУБЛИЧНЫЕ МЕТОДЫ
-- ============================================

function DistanceESP:Toggle(state)
    self.Enabled = state
    if state then
        -- Создаём объекты для всех существующих игроков
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
    -- Position игнорируется, так как мы центрируем над головой
    self.Position = pos or "Center"
end

function DistanceESP:SetOffsetY(offset)
    self.OffsetY = offset or 0
end

function DistanceESP:Unload()
    self:_clearAll()
    self.Enabled = false
end

-- Авто-удаление при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if DistanceESP._players[player] then
        DistanceESP:_removePlayer(player)
    end
end)

return DistanceESP
