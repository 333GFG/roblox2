-- ============================================
--  BoxESP Module by nitarte
--  2D Box ESP вокруг тела персонажа (без оружия/аксессуаров)
--  Использует Roblox Drawing API
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

-- Список ВАЛИДНЫХ частей тела (только тело, без оружия/аксессуаров)
local VALID_BODY_PARTS = {
    ["Head"] = true,
    ["HumanoidRootPart"] = true,
    ["Torso"] = true,
    ["UpperTorso"] = true,
    ["LowerTorso"] = true,
    ["LeftArm"] = true,
    ["RightArm"] = true,
    ["LeftLeg"] = true,
    ["RightLeg"] = true,
    ["LeftUpperArm"] = true,
    ["LeftLowerArm"] = true,
    ["LeftHand"] = true,
    ["RightUpperArm"] = true,
    ["RightLowerArm"] = true,
    ["RightHand"] = true,
    ["LeftUpperLeg"] = true,
    ["LeftLowerLeg"] = true,
    ["LeftFoot"] = true,
    ["RightUpperLeg"] = true,
    ["RightLowerLeg"] = true,
    ["RightFoot"] = true,
}

-- Получить 2D bounds ТОЛЬКО тела персонажа (без оружия)
local function GetBodyBounds(character)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    local hasValidParts = false
    
    for _, part in pairs(character:GetDescendants()) do
        -- Только BasePart И только из списка VALID_BODY_PARTS
        if part:IsA("BasePart") and VALID_BODY_PARTS[part.Name] then
            hasValidParts = true
            
            local size = part.Size
            local cf = part.CFrame
            
            -- 8 углов bounding box части
            local corners = {
                cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
                cf * CFrame.new(-size.X/2, -size.Y/2,  size.Z/2),
                cf * CFrame.new(-size.X/2,  size.Y/2, -size.Z/2),
                cf * CFrame.new(-size.X/2,  size.Y/2,  size.Z/2),
                cf * CFrame.new( size.X/2, -size.Y/2, -size.Z/2),
                cf * CFrame.new( size.X/2, -size.Y/2,  size.Z/2),
                cf * CFrame.new( size.X/2,  size.Y/2, -size.Z/2),
                cf * CFrame.new( size.X/2,  size.Y/2,  size.Z/2),
            }
            
            for _, corner in pairs(corners) do
                local pos = corner.Position
                local screenPos = Camera:WorldToViewportPoint(pos)
                
                minX = math.min(minX, screenPos.X)
                minY = math.min(minY, screenPos.Y)
                maxX = math.max(maxX, screenPos.X)
                maxY = math.max(maxY, screenPos.Y)
            end
        end
    end
    
    if not hasValidParts then return nil end
    
    return {
        min = Vector2.new(minX, minY),
        max = Vector2.new(maxX, maxY),
        center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
    }
end

-- Быстрый вариант через GetExtentsSize (если character — Model)
local function GetBodyBoundsFast(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    -- Создаём временную модель только с частями тела
    local tempModel = Instance.new("Model")
    tempModel.Name = "TempBounds"
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and VALID_BODY_PARTS[part.Name] then
            local clone = part:Clone()
            clone.Parent = tempModel
        end
    end
    
    if #tempModel:GetChildren() == 0 then
        tempModel:Destroy()
        return nil
    end
    
    local extentSize = tempModel:GetExtentsSize()
    local centerCFrame = tempModel:GetBoundingBox()
    tempModel:Destroy()
    
    local halfSize = extentSize / 2
    local cf = centerCFrame
    
    local corners = {
        cf * CFrame.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
        cf * CFrame.new(-halfSize.X, -halfSize.Y,  halfSize.Z),
        cf * CFrame.new(-halfSize.X,  halfSize.Y, -halfSize.Z),
        cf * CFrame.new(-halfSize.X,  halfSize.Y,  halfSize.Z),
        cf * CFrame.new( halfSize.X, -halfSize.Y, -halfSize.Z),
        cf * CFrame.new( halfSize.X, -halfSize.Y,  halfSize.Z),
        cf * CFrame.new( halfSize.X,  halfSize.Y, -halfSize.Z),
        cf * CFrame.new( halfSize.X,  halfSize.Y,  halfSize.Z),
    }
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    for _, corner in pairs(corners) do
        local pos = corner.Position
        local screenPos = Camera:WorldToViewportPoint(pos)
        
        minX = math.min(minX, screenPos.X)
        minY = math.min(minY, screenPos.Y)
        maxX = math.max(maxX, screenPos.X)
        maxY = math.max(maxY, screenPos.Y)
    end
    
    return {
        min = Vector2.new(minX, minY),
        max = Vector2.new(maxX, maxY),
        center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
    }
end

function BoxESP:_createBox(player)
    local box = {
        player = player,
        lines = {},
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
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    if self.TeamCheck and box.player.Team == LocalPlayer.Team then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    if distance > self.MaxDistance then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- ИСПРАВЛЕНИЕ: только части тела, без оружия/аксессуаров
    local bounds = GetBodyBounds(character)
    -- ИЛИ для производительности: bounds = GetBodyBoundsFast(character)
    
    if not bounds then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    -- Проверяем, виден ли хоть один угол на экране
    local screenSize = Camera.ViewportSize
    if bounds.max.X < 0 or bounds.min.X > screenSize.X or 
       bounds.max.Y < 0 or bounds.min.Y > screenSize.Y then
        for _, line in pairs(box.lines) do line.Visible = false end
        return
    end
    
    local topLeft = bounds.min
    local topRight = Vector2.new(bounds.max.X, bounds.min.Y)
    local bottomRight = bounds.max
    local bottomLeft = Vector2.new(bounds.min.X, bounds.max.Y)
    
    local l = box.lines
    l[1].From = topLeft;     l[1].To = topRight      -- Top
    l[2].From = topRight;    l[2].To = bottomRight   -- Right
    l[3].From = bottomRight; l[3].To = bottomLeft    -- Bottom
    l[4].From = bottomLeft;  l[4].To = topLeft       -- Left
    
    for _, line in pairs(l) do
        line.Visible = true
        line.Color = self.Color
        line.Thickness = self.Thickness
        line.Transparency = self.Transparency
    end
end

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

Players.PlayerRemoving:Connect(function(player)
    if BoxESP._players[player] then
        BoxESP:_removeBox(player)
    end
end)

return BoxESP
