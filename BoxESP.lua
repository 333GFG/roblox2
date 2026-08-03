-- ============================================
--  Простой Box ESP (X-Ray стиль)
--  Основан на xarenav/Roblox-ESP-x-ray-script
-- ============================================

local BoxESP = {
    Enabled = false,
    Color = Color3.fromRGB(0, 255, 0),  -- Зелёный, как в оригинале
    Thickness = 2,
    Transparency = 1,
    _boxes = {},
    _connection = nil
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Создаёт 4 линии для одного игрока
local function CreateBoxLines(player)
    local lines = {}
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = BoxESP.Color
        line.Thickness = BoxESP.Thickness
        line.Transparency = BoxESP.Transparency
        table.insert(lines, line)
    end
    return lines
end

-- Обновление позиций бокса
local function UpdateBox(player, lines)
    local character = player.Character
    if not character then
        for _, line in pairs(lines) do line.Visible = false end
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for _, line in pairs(lines) do line.Visible = false end
        return
    end

    -- Получаем позицию на экране
    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then
        for _, line in pairs(lines) do line.Visible = false end
        return
    end

    -- Размер бокса (фиксированный, можно настроить)
    local size = 50
    local x, y = pos.X, pos.Y

    -- Верхняя, правая, нижняя, левая линии
    lines[1].From = Vector2.new(x - size, y - size)
    lines[1].To = Vector2.new(x + size, y - size)
    
    lines[2].From = Vector2.new(x + size, y - size)
    lines[2].To = Vector2.new(x + size, y + size)
    
    lines[3].From = Vector2.new(x + size, y + size)
    lines[3].To = Vector2.new(x - size, y + size)
    
    lines[4].From = Vector2.new(x - size, y + size)
    lines[4].To = Vector2.new(x - size, y - size)

    for _, line in pairs(lines) do
        line.Visible = true
        line.Color = BoxESP.Color
        line.Thickness = BoxESP.Thickness
        line.Transparency = BoxESP.Transparency
    end
end

-- Главный цикл
local function OnRender()
    if not BoxESP.Enabled then return end

    -- Добавляем новых игроков
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not BoxESP._boxes[player] then
            BoxESP._boxes[player] = CreateBoxLines(player)
        end
    end

    -- Обновляем все боксы
    for player, lines in pairs(BoxESP._boxes) do
        UpdateBox(player, lines)
    end
end

-- Публичные методы
function BoxESP:Toggle(state)
    self.Enabled = state
    if state then
        if not self._connection then
            self._connection = RunService.RenderStepped:Connect(OnRender)
        end
    else
        for _, lines in pairs(self._boxes) do
            for _, line in pairs(lines) do
                line.Visible = false
            end
        end
    end
end

function BoxESP:SetColor(color)
    self.Color = color
end

function BoxESP:Unload()
    self.Enabled = false
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    for _, lines in pairs(self._boxes) do
        for _, line in pairs(lines) do
            line:Remove()
        end
    end
    self._boxes = {}
end

-- Авто-удаление при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if BoxESP._boxes[player] then
        for _, line in pairs(BoxESP._boxes[player]) do
            line:Remove()
        end
        BoxESP._boxes[player] = nil
    end
end)

return BoxESP
