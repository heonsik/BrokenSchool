local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local worldFolder = workspace:WaitForChild(GameConfig.WorldFolderName)

local remotesFolder = ReplicatedStorage:FindFirstChild(GameConfig.RemotesFolderName)
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = GameConfig.RemotesFolderName
    remotesFolder.Parent = ReplicatedStorage
end

local gameEvent = remotesFolder:FindFirstChild("GameEvent")
if not gameEvent then
    gameEvent = Instance.new("RemoteEvent")
    gameEvent.Name = "GameEvent"
    gameEvent.Parent = remotesFolder
end

local playerAction = remotesFolder:FindFirstChild("PlayerAction")
if not playerAction then
    playerAction = Instance.new("RemoteEvent")
    playerAction.Name = "PlayerAction"
    playerAction.Parent = remotesFolder
end

-- 클라이언트에서 손전등 상태를 받아 서버 속성으로 기록
playerAction.OnServerEvent:Connect(function(player, action, value)
    if action == "Flashlight" then
        player:SetAttribute("FlashlightActive", value == true and player:GetAttribute("HasFlashlight") == true)
    end
end)

Lighting.ClockTime = 5.8
Lighting.Brightness = 2.4
Lighting.FogColor = Color3.fromRGB(56, 61, 72)
Lighting.FogStart = 100
Lighting.FogEnd = 320
Lighting.Ambient = Color3.fromRGB(96, 106, 122)
Lighting.OutdoorAmbient = Color3.fromRGB(72, 78, 90)
Lighting.ExposureCompensation = 0.2

local colors = {
    floor = Color3.fromRGB(92, 98, 105),
    corridor = Color3.fromRGB(76, 92, 112),
    wall = Color3.fromRGB(132, 137, 143),
    wallTrim = Color3.fromRGB(62, 70, 82),
    darkWall = Color3.fromRGB(72, 78, 90),
    door = Color3.fromRGB(130, 78, 38),
    desk = Color3.fromRGB(150, 92, 48),
    chair = Color3.fromRGB(64, 98, 145),
    warning = Color3.fromRGB(225, 185, 66),
    guide = Color3.fromRGB(55, 210, 255),
    exit = Color3.fromRGB(70, 220, 130),
    locked = Color3.fromRGB(220, 65, 65),
    fuse = Color3.fromRGB(255, 220, 70),
    generator = Color3.fromRGB(65, 170, 230),
    shield = Color3.fromRGB(150, 105, 255),
    boost = Color3.fromRGB(255, 125, 55),
    monster = Color3.fromRGB(210, 87, 52),
    ghost = Color3.fromRGB(205, 245, 255),
    ghostBlue = Color3.fromRGB(105, 200, 255),
}

local gameState = {
    collectedFuses = 0,
    exitOpen = false,
    generatorPowered = false,
}

local rainState = {
    active = false,
    startedAt = os.clock(),
    endsAt = os.clock() + GameConfig.Rain.InitialClearDuration,
}

-- 탈출 완료 플레이어 집합 (잡히지 않도록)
local wonPlayers = {}

local hideZones = {}
local exitDoorPart = nil
local exitLockPart = nil
local monsterModel = nil
local ghostModel = nil

local function createPart(name, size, cframe, color, material, parent)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent or worldFolder
    return part
end

local function findWorldPart(name)
    local instance = worldFolder:FindFirstChild(name, true)
    if instance and instance:IsA("BasePart") then
        return instance
    end
    return nil
end

local function getOrCreatePart(name, size, cframe, color, material, parent)
    return findWorldPart(name) or createPart(name, size, cframe, color, material, parent)
end

local function addWall(name, position, size)
    local wall = createPart(name, size, CFrame.new(position), colors.wall, Enum.Material.Concrete)
    createPart(name .. "Trim", Vector3.new(size.X, 0.45, size.Z), CFrame.new(position - Vector3.new(0, 5.6, 0)), colors.wallTrim, Enum.Material.SmoothPlastic)
    return wall
end

local function addLabelBillboard(part, text, color)
    if part:FindFirstChild("Label") then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Label"
    billboard.Size = UDim2.fromOffset(240, 52)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Size = UDim2.fromScale(1, 1)
    label.Parent = billboard
end

local function addLight(name, position, brightness, range, color)
    local holder = createPart(name .. "Holder", Vector3.new(1, 0.3, 1), CFrame.new(position), Color3.fromRGB(35, 35, 42), Enum.Material.Metal)
    holder.CanCollide = false

    local light = Instance.new("PointLight")
    light.Name = name
    light.Brightness = brightness
    light.Range = range
    light.Color = color or Color3.fromRGB(255, 235, 190)
    light.Shadows = true
    light.Parent = holder

    return holder
end

local function addAreaLightPanel(name, position, size, color)
    local panel = createPart(name, size, CFrame.new(position), color or Color3.fromRGB(255, 244, 196), Enum.Material.Neon)
    panel.CanCollide = false

    local light = Instance.new("PointLight")
    light.Name = name .. "Glow"
    light.Brightness = 2.2
    light.Range = 34
    light.Color = color or Color3.fromRGB(255, 244, 196)
    light.Shadows = false
    light.Parent = panel

    return panel
end

local function addSign(name, position, text, color)
    local sign = createPart(name, Vector3.new(7.5, 3, 0.35), CFrame.new(position), color or Color3.fromRGB(35, 55, 85), Enum.Material.SmoothPlastic)
    sign.CanCollide = false
    addLabelBillboard(sign, text, Color3.fromRGB(255, 255, 255))
    return sign
end

local function addGuideTile(name, position, size, color)
    local tile = createPart(name, size, CFrame.new(position), color or colors.guide, Enum.Material.Neon)
    tile.CanCollide = false
    tile.Transparency = 0.25
    return tile
end

local function broadcastProgress()
    gameEvent:FireAllClients("Progress", {
        fuses = gameState.collectedFuses,
        required = GameConfig.Objective.RequiredFuses,
        exitOpen = gameState.exitOpen,
        generatorPowered = gameState.generatorPowered,
    })
end

local function makeRainPayload()
    return {
        active = rainState.active,
        remaining = math.max(0, rainState.endsAt - os.clock()),
        duration = rainState.active and GameConfig.Rain.Duration or GameConfig.Rain.ClearDuration,
    }
end

local function setRainActive(active)
    local duration = active and GameConfig.Rain.Duration or GameConfig.Rain.ClearDuration
    rainState.active = active
    rainState.startedAt = os.clock()
    rainState.endsAt = rainState.startedAt + duration
    gameEvent:FireAllClients("Rain", makeRainPayload())
end

local function sendRainState(player)
    gameEvent:FireClient(player, "Rain", makeRainPayload())
end

local function triggerLightning()
    gameEvent:FireAllClients("Lightning", {
        intensity = math.random(75, 115) / 100,
        thunderDelay = math.random(
            math.floor(GameConfig.Rain.ThunderMinDelay * 10),
            math.floor(GameConfig.Rain.ThunderMaxDelay * 10)
        ) / 10,
    })
end

local function fireMessage(player, action, text)
    gameEvent:FireClient(player, action, text)
end

local function fireMessageAndSync(player, action, text)
    gameEvent:FireClient(player, action, text)
    broadcastProgress()
end

local function setPlayerAttributeNumber(player, name, value)
    player:SetAttribute(name, value)
    gameEvent:FireClient(player, "Inventory", {
        flashlight = player:GetAttribute("HasFlashlight") == true,
        shield = player:GetAttribute("ShieldCount") or 0,
    })
end

local function pointInsidePart(part, point)
    local localPoint = part.CFrame:PointToObjectSpace(point)
    local halfSize = part.Size * 0.5
    return math.abs(localPoint.X) <= halfSize.X
        and math.abs(localPoint.Y) <= halfSize.Y
        and math.abs(localPoint.Z) <= halfSize.Z
end

local function isPlayerHidden(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end

    for _, zone in ipairs(hideZones) do
        if pointInsidePart(zone, root.Position) then
            player:SetAttribute("IsHidden", true)
            return true
        end
    end

    player:SetAttribute("IsHidden", false)
    return false
end

local function hasClearLineOfSight(fromPosition, targetPart, extraIgnore)
    if not targetPart then
        return false
    end

    local ignore = { targetPart.Parent }
    if monsterModel then
        table.insert(ignore, monsterModel)
    end
    if ghostModel then
        table.insert(ignore, ghostModel)
    end
    if extraIgnore then
        for _, instance in ipairs(extraIgnore) do
            if instance then
                table.insert(ignore, instance)
            end
        end
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = ignore
    rayParams.RespectCanCollide = true

    local direction = targetPart.Position - fromPosition
    local hit = workspace:Raycast(fromPosition, direction, rayParams)
    return hit == nil
end

local function hasClearMovementSegment(fromPosition, toPosition, movingModel)
    local direction = toPosition - fromPosition
    if direction.Magnitude < 0.05 then
        return true
    end

    local ignore = {}
    if movingModel then
        table.insert(ignore, movingModel)
    end
    if monsterModel and monsterModel ~= movingModel then
        table.insert(ignore, monsterModel)
    end
    if ghostModel and ghostModel ~= movingModel then
        table.insert(ignore, ghostModel)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(ignore, player.Character)
        end
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = ignore
    rayParams.RespectCanCollide = true

    return workspace:Raycast(fromPosition, direction, rayParams) == nil
end

local function addDesk(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local top = createPart("BrokenDeskTop", Vector3.new(5, 0.5, 3), base, colors.desk, Enum.Material.Wood)
    createPart("BrokenDeskLegA", Vector3.new(0.35, 2, 0.35), base * CFrame.new(-2, -1.25, -1), colors.desk, Enum.Material.Wood)
    createPart("BrokenDeskLegB", Vector3.new(0.35, 1.3, 0.35), base * CFrame.new(2, -1.55, 1), colors.desk, Enum.Material.Wood)
    return top
end

local function addBlackboard(position, rotation, text)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local board = createPart("ClassroomBlackboard", Vector3.new(10, 4.5, 0.35), base, Color3.fromRGB(24, 88, 58), Enum.Material.SmoothPlastic)
    board.CanCollide = false
    addLabelBillboard(board, text or "퓨즈를 찾아라", Color3.fromRGB(220, 255, 230))
end

local function addDoorMarker(position, rotation, text, color)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local door = createPart("RoomDoorMarker", Vector3.new(4, 7, 0.45), base, color or colors.door, Enum.Material.Wood)
    door.CanCollide = false
    addLabelBillboard(door, text, Color3.fromRGB(255, 240, 190))
end

local function addChair(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("FallenChairSeat", Vector3.new(2.4, 0.35, 2.2), base, colors.chair, Enum.Material.Wood)
    createPart("FallenChairBack", Vector3.new(2.4, 2.2, 0.35), base * CFrame.new(0, 1.1, 1), colors.chair, Enum.Material.Wood)
end

local function addCrack(position, size, rotation)
    local crack = createPart("WallCrack", size, CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0), Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic)
    crack.CanCollide = false
    return crack
end

local function addLocker(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local locker = createPart("SafeLocker", Vector3.new(3, 7, 2.2), base, Color3.fromRGB(35, 70, 95), Enum.Material.Metal)
    createPart("SafeLockerDoor", Vector3.new(2.6, 5.8, 0.16), base * CFrame.new(0, 0, -1.15), Color3.fromRGB(45, 105, 135), Enum.Material.Metal)
    addLabelBillboard(locker, "숨기", Color3.fromRGB(190, 240, 255))

    local zone = createPart("LockerHideZone", Vector3.new(5, 7, 5), base, Color3.fromRGB(60, 180, 230), Enum.Material.ForceField)
    zone.Transparency = 0.82
    zone.CanCollide = false
    zone.CanTouch = false
    table.insert(hideZones, zone)
end

local function addShelf(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("LibraryShelf", Vector3.new(2.2, 7, 10), base, Color3.fromRGB(76, 48, 32), Enum.Material.Wood)
    createPart("LibraryShelfBooksA", Vector3.new(2.35, 1.1, 8.8), base * CFrame.new(0, 1.8, 0), Color3.fromRGB(95, 120, 170), Enum.Material.SmoothPlastic)
    createPart("LibraryShelfBooksB", Vector3.new(2.35, 1.1, 8.8), base * CFrame.new(0, -0.6, 0), Color3.fromRGB(150, 75, 80), Enum.Material.SmoothPlastic)
end

local function addCafeteriaTable(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("CafeteriaTable", Vector3.new(7, 0.45, 2.4), base, Color3.fromRGB(110, 72, 46), Enum.Material.Wood)
    createPart("CafeteriaBenchA", Vector3.new(7, 0.35, 0.8), base * CFrame.new(0, -0.5, -2.1), Color3.fromRGB(75, 85, 95), Enum.Material.Metal)
    createPart("CafeteriaBenchB", Vector3.new(7, 0.35, 0.8), base * CFrame.new(0, -0.5, 2.1), Color3.fromRGB(75, 85, 95), Enum.Material.Metal)
end

local function addVendingMachine(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local machine = createPart("VendingMachine", Vector3.new(3.2, 6, 2), base, Color3.fromRGB(210, 45, 65), Enum.Material.SmoothPlastic)
    createPart("VendingMachineScreen", Vector3.new(2, 2, 0.18), base * CFrame.new(0, 1.1, -1.05), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
    addLabelBillboard(machine, "매점", Color3.fromRGB(255, 235, 235))
end

local function addTrophyCase(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    local case = createPart("TrophyCase", Vector3.new(8, 5, 1.2), base, Color3.fromRGB(120, 78, 42), Enum.Material.Wood)
    createPart("TrophyGlass", Vector3.new(7.6, 4.3, 0.18), base * CFrame.new(0, 0.2, -0.7), Color3.fromRGB(170, 230, 255), Enum.Material.Glass)
    createPart("TrophyA", Vector3.new(1, 1.8, 1), base * CFrame.new(-2.2, 0, -0.95), Color3.fromRGB(245, 198, 55), Enum.Material.Neon)
    createPart("TrophyB", Vector3.new(1, 1.4, 1), base * CFrame.new(0.2, -0.2, -0.95), Color3.fromRGB(230, 230, 235), Enum.Material.Neon)
    createPart("TrophyC", Vector3.new(1, 1.6, 1), base * CFrame.new(2.4, -0.1, -0.95), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
    addLabelBillboard(case, "트로피 진열장", Color3.fromRGB(255, 245, 190))
end

local function addTree(position, scale)
    scale = scale or 1
    createPart("CampusTreeTrunk", Vector3.new(2 * scale, 8 * scale, 2 * scale), CFrame.new(position + Vector3.new(0, 4 * scale, 0)), Color3.fromRGB(95, 55, 28), Enum.Material.Wood)
    local leaves = createPart("CampusTreeLeaves", Vector3.new(8 * scale, 8 * scale, 8 * scale), CFrame.new(position + Vector3.new(0, 10 * scale, 0)), Color3.fromRGB(45, 130, 72), Enum.Material.Grass)
    leaves.Shape = Enum.PartType.Ball
end

local function addGymBleacher(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    for stepIndex = 1, 4 do
        createPart("GymBleacherStep" .. stepIndex, Vector3.new(34, 1, 4), base * CFrame.new(0, stepIndex * 1.1, stepIndex * 4), Color3.fromRGB(85, 95, 115), Enum.Material.Metal)
    end
end

local function addLargeClassroomCeiling(center)
    local cx, cz = center.X, center.Z
    createPart("ClassCeiling" .. cx, Vector3.new(56, 0.4, 38),
        CFrame.new(cx, 12.2, cz),
        Color3.fromRGB(205, 205, 210), Enum.Material.SmoothPlastic)
    local crack = createPart("ClassCeilingCrack" .. cx, Vector3.new(0.18, 0.05, 14),
        CFrame.new(cx + 10, 12.38, cz - 4) * CFrame.Angles(0, math.rad(18), 0),
        Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic)
    crack.CanCollide = false
end

local function addCorridorColumn(id, position)
    createPart("CorridorColumn" .. id, Vector3.new(1.4, 12, 1.4),
        CFrame.new(position + Vector3.new(0, 6, 0)),
        Color3.fromRGB(185, 190, 198), Enum.Material.SmoothPlastic)
    createPart("CorridorColumnCap" .. id, Vector3.new(2.2, 0.5, 2.2),
        CFrame.new(position + Vector3.new(0, 12.25, 0)),
        Color3.fromRGB(170, 175, 185), Enum.Material.SmoothPlastic)
end

local function addOuterWallWindow(id, position)
    local win = createPart("OuterWallWindow" .. id, Vector3.new(7, 4.5, 0.2),
        CFrame.new(position),
        Color3.fromRGB(175, 220, 255), Enum.Material.Glass)
    win.Transparency = 0.5
    win.CanCollide = false
    local sill = createPart("OuterWallSill" .. id, Vector3.new(7.6, 0.3, 0.3),
        CFrame.new(position - Vector3.new(0, 2.4, 0)),
        Color3.fromRGB(210, 215, 220), Enum.Material.SmoothPlastic)
    sill.CanCollide = false
end

local function addLargeClassroomWalls(center)
    local cx, cz = center.X, center.Z
    addWall("ClassNorthWall" .. cx, Vector3.new(cx, 6, cz + 18), Vector3.new(56, 12, 2))
    addWall("ClassEastWall" .. cx, Vector3.new(cx + 27, 6, cz), Vector3.new(2, 12, 36))
    addWall("ClassWestWall" .. cx, Vector3.new(cx - 27, 6, cz), Vector3.new(2, 12, 36))
    addAreaLightPanel("ClassCeilingLight" .. cx, Vector3.new(cx, 11.2, cz + 4), Vector3.new(28, 0.25, 10))
    -- 걸레받이 (wainscoting)
    local wainColor = Color3.fromRGB(148, 136, 122)
    local wN = createPart("ClassWainscotN" .. cx, Vector3.new(56, 2.8, 0.22), CFrame.new(cx, 1.4, cz + 17.9), wainColor, Enum.Material.SmoothPlastic)
    wN.CanCollide = false
    local wE = createPart("ClassWainscotE" .. cx, Vector3.new(0.22, 2.8, 36), CFrame.new(cx + 26.9, 1.4, cz), wainColor, Enum.Material.SmoothPlastic)
    wE.CanCollide = false
    local wW = createPart("ClassWainscotW" .. cx, Vector3.new(0.22, 2.8, 36), CFrame.new(cx - 26.9, 1.4, cz), wainColor, Enum.Material.SmoothPlastic)
    wW.CanCollide = false
    -- 창문 (동쪽/서쪽 벽)
    for wI = 0, 1 do
        local winZ = cz - 8 + wI * 16
        local winE = createPart("ClassWinE" .. cx .. "_" .. wI, Vector3.new(0.2, 4.5, 7), CFrame.new(cx + 27.1, 7, winZ), Color3.fromRGB(175, 220, 255), Enum.Material.Glass)
        winE.Transparency = 0.5; winE.CanCollide = false
        local winW = createPart("ClassWinW" .. cx .. "_" .. wI, Vector3.new(0.2, 4.5, 7), CFrame.new(cx - 27.1, 7, winZ), Color3.fromRGB(175, 220, 255), Enum.Material.Glass)
        winW.Transparency = 0.5; winW.CanCollide = false
    end
end

local function addScienceLabProps(center)
    local cx, cz = center.X, center.Z
    for row = 0, 1 do
        for col = 0, 3 do
            createPart("LabTable", Vector3.new(5, 0.3, 2.2),
                CFrame.new(cx - 14 + col * 10, 1.7, cz - 6 + row * 10),
                Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic)
        end
    end
    for i = 1, 5 do
        local flask = createPart("LabFlask", Vector3.new(0.5, 0.9, 0.5),
            CFrame.new(cx - 16 + i * 7, 2.25, cz - 6),
            Color3.fromRGB(90, 180, 255), Enum.Material.Glass)
        flask.Transparency = 0.35
        local glow = Instance.new("PointLight")
        glow.Color = Color3.fromRGB(90, 180, 255)
        glow.Brightness = 0.5
        glow.Range = 5
        glow.Parent = flask
    end
    createPart("SkeletonBody", Vector3.new(1, 5.5, 1),
        CFrame.new(cx + 24, 3.75, cz + 14),
        Color3.fromRGB(228, 215, 190), Enum.Material.SmoothPlastic)
    createPart("SkeletonHead", Vector3.new(1.2, 1.2, 1.2),
        CFrame.new(cx + 24, 7.1, cz + 14),
        Color3.fromRGB(228, 215, 190), Enum.Material.SmoothPlastic)
    createPart("PeriodicTable", Vector3.new(10, 6, 0.18),
        CFrame.new(cx, 6.5, cz + 17.2),
        Color3.fromRGB(235, 235, 215), Enum.Material.SmoothPlastic)
    local brokenFlask = createPart("BrokenFlask", Vector3.new(0.4, 0.1, 0.4),
        CFrame.new(cx + 8, 0.9, cz + 2),
        Color3.fromRGB(180, 220, 255), Enum.Material.Glass)
    brokenFlask.Transparency = 0.2
    brokenFlask.CanCollide = false
end

local function addMusicRoomProps(center)
    local cx, cz = center.X, center.Z
    for i = 0, 4 do
        createPart("MusicStandPole", Vector3.new(0.35, 3.5, 0.35),
            CFrame.new(cx - 18 + i * 9, 2.25, cz - 5),
            Color3.fromRGB(38, 38, 40), Enum.Material.Metal)
        createPart("MusicStandDesk", Vector3.new(2.2, 0.12, 1.6),
            CFrame.new(cx - 18 + i * 9, 4.0, cz - 5),
            Color3.fromRGB(35, 35, 38), Enum.Material.Metal)
    end
    createPart("PianoBody", Vector3.new(5.5, 5, 2.4),
        CFrame.new(cx - 21, 3.5, cz + 14),
        Color3.fromRGB(18, 18, 20), Enum.Material.SmoothPlastic)
    createPart("PianoKeys", Vector3.new(4.8, 0.4, 0.9),
        CFrame.new(cx - 21, 2.1, cz + 12.7),
        Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic)
    createPart("DrumSetBase", Vector3.new(4.5, 1.8, 4),
        CFrame.new(cx + 18, 1.4, cz + 12),
        Color3.fromRGB(185, 45, 45), Enum.Material.SmoothPlastic)
    createPart("Cymbal1", Vector3.new(2.8, 0.12, 2.8),
        CFrame.new(cx + 18, 3.5, cz + 12),
        Color3.fromRGB(190, 175, 35), Enum.Material.Metal)
    createPart("Cymbal2", Vector3.new(2.2, 0.12, 2.2),
        CFrame.new(cx + 21, 4.0, cz + 13.5),
        Color3.fromRGB(190, 175, 35), Enum.Material.Metal)
    createPart("FallenMusicStand", Vector3.new(2.2, 0.12, 1.6),
        CFrame.new(cx + 4, 0.7, cz - 2) * CFrame.Angles(math.rad(-80), math.rad(20), 0),
        Color3.fromRGB(35, 35, 38), Enum.Material.Metal)
end

local function addArtRoomProps(center)
    local cx, cz = center.X, center.Z
    for i = 0, 3 do
        createPart("EaselPost", Vector3.new(0.3, 4.5, 0.3),
            CFrame.new(cx - 14 + i * 10, 3, cz - 5),
            Color3.fromRGB(110, 70, 30), Enum.Material.Wood)
        createPart("EaselCanvas", Vector3.new(3.2, 4, 0.12),
            CFrame.new(cx - 14 + i * 10, 4.5, cz - 5),
            Color3.fromRGB(245, 238, 220), Enum.Material.SmoothPlastic)
    end
    createPart("ArtSupplyTable", Vector3.new(14, 0.4, 3),
        CFrame.new(cx - 8, 1.7, cz + 13),
        Color3.fromRGB(108, 72, 44), Enum.Material.Wood)
    createPart("PaintSet", Vector3.new(8, 0.5, 1.8),
        CFrame.new(cx - 8, 2.1, cz + 13),
        Color3.fromRGB(195, 115, 75), Enum.Material.SmoothPlastic)
    local splash1 = createPart("PaintSplashR", Vector3.new(3.5, 0.06, 2.8),
        CFrame.new(cx + 6, 0.88, cz - 7),
        Color3.fromRGB(220, 70, 70), Enum.Material.Neon)
    splash1.CanCollide = false
    local splash2 = createPart("PaintSplashB", Vector3.new(2.8, 0.06, 3),
        CFrame.new(cx - 10, 0.88, cz + 3),
        Color3.fromRGB(65, 115, 220), Enum.Material.Neon)
    splash2.CanCollide = false
    createPart("LargePainting", Vector3.new(11, 7, 0.18),
        CFrame.new(cx + 14, 6.5, cz + 17.2),
        Color3.fromRGB(180, 120, 155), Enum.Material.SmoothPlastic)
end

local function addBroadcastRoomProps(center)
    local cx, cz = center.X, center.Z
    createPart("BroadcastConsole", Vector3.new(20, 1.0, 3.5),
        CFrame.new(cx, 1.8, cz + 8),
        Color3.fromRGB(18, 20, 28), Enum.Material.SmoothPlastic)
    local leds = createPart("ConsoleLEDs", Vector3.new(18, 0.22, 2),
        CFrame.new(cx, 2.45, cz + 8),
        Color3.fromRGB(0, 180, 255), Enum.Material.Neon)
    leds.CanCollide = false
    for i = 0, 2 do
        createPart("Monitor", Vector3.new(4, 3, 0.2),
            CFrame.new(cx - 8 + i * 8, 4.2, cz + 12),
            Color3.fromRGB(15, 15, 20), Enum.Material.SmoothPlastic)
        local screenGlow = createPart("MonitorGlow", Vector3.new(3.5, 2.5, 0.16),
            CFrame.new(cx - 8 + i * 8, 4.2, cz + 11.8),
            Color3.fromRGB(60, 160, 255), Enum.Material.Neon)
        screenGlow.CanCollide = false
    end
    createPart("CameraTripod", Vector3.new(0.4, 4, 0.4),
        CFrame.new(cx - 22, 2.5, cz - 3),
        Color3.fromRGB(38, 38, 40), Enum.Material.Metal)
    createPart("CameraBody", Vector3.new(1.6, 1.2, 2.4),
        CFrame.new(cx - 22, 5.1, cz - 3),
        Color3.fromRGB(22, 22, 25), Enum.Material.SmoothPlastic)
    local recLight = createPart("RecordingLight", Vector3.new(0.35, 0.35, 0.35),
        CFrame.new(cx - 22, 5.85, cz - 3),
        Color3.fromRGB(255, 20, 20), Enum.Material.Neon)
    recLight.CanCollide = false
    createPart("TapeBox", Vector3.new(5, 0.6, 3.5),
        CFrame.new(cx + 22, 0.95, cz - 8),
        Color3.fromRGB(40, 40, 48), Enum.Material.SmoothPlastic)
end

local function addHealthRoomProps(center)
    local cx, cz = center.X, center.Z
    for i = 0, 2 do
        createPart("MedBed", Vector3.new(4.5, 0.55, 9),
            CFrame.new(cx - 16 + i * 16, 1.8, cz + 4),
            Color3.fromRGB(242, 242, 248), Enum.Material.SmoothPlastic)
        createPart("MedBedPillow", Vector3.new(3, 0.45, 2),
            CFrame.new(cx - 16 + i * 16, 2.35, cz + 8.2),
            Color3.fromRGB(248, 248, 252), Enum.Material.SmoothPlastic)
        createPart("IVPole", Vector3.new(0.25, 4.5, 0.25),
            CFrame.new(cx - 16 + i * 16 + 2.5, 3, cz + 7),
            Color3.fromRGB(165, 175, 185), Enum.Material.Metal)
        local ivBag = createPart("IVBag", Vector3.new(0.7, 1.1, 0.18),
            CFrame.new(cx - 16 + i * 16 + 2.5, 5.4, cz + 7),
            Color3.fromRGB(215, 238, 255), Enum.Material.Glass)
        ivBag.Transparency = 0.38
    end
    createPart("MedCabinet", Vector3.new(5, 6.5, 1.4),
        CFrame.new(cx - 24, 4.75, cz + 16),
        Color3.fromRGB(228, 234, 240), Enum.Material.SmoothPlastic)
    local cabinetGlass = createPart("CabinetGlass", Vector3.new(4.4, 5.6, 0.16),
        CFrame.new(cx - 24, 4.75, cz + 15.5),
        Color3.fromRGB(180, 228, 255), Enum.Material.Glass)
    cabinetGlass.Transparency = 0.25
    local crossH = createPart("RedCrossH", Vector3.new(5.5, 1.2, 0.15),
        CFrame.new(cx, 8.5, cz + 17.5),
        Color3.fromRGB(220, 35, 35), Enum.Material.Neon)
    crossH.CanCollide = false
    local crossV = createPart("RedCrossV", Vector3.new(1.2, 5.5, 0.15),
        CFrame.new(cx, 8.5, cz + 17.4),
        Color3.fromRGB(220, 35, 35), Enum.Material.Neon)
    crossV.CanCollide = false
    createPart("OverturneWheelchair", Vector3.new(3, 1, 3),
        CFrame.new(cx + 18, 1, cz - 10) * CFrame.Angles(0, math.rad(25), math.rad(-90)),
        Color3.fromRGB(55, 60, 68), Enum.Material.Metal)
end

local function addLargeClassroomBlock(center, labelText, color)
    createPart(labelText .. "Floor", Vector3.new(56, 0.16, 38), CFrame.new(center.X, 0.82, center.Z), color, Enum.Material.Tile)
    addDoorMarker(Vector3.new(center.X, 4, center.Z - 20), 0, labelText, color)
    addBlackboard(Vector3.new(center.X, 4.8, center.Z + 18), 180, labelText)
    for row = 0, 2 do
        for col = 0, 2 do
            addDesk(Vector3.new(center.X - 16 + col * 16, 1.5, center.Z - 8 + row * 8), (row - col) * 8)
        end
    end
end

local function addLandmarkTower(name, position, labelText, color)
    local tower = createPart(name, Vector3.new(7, 34, 7), CFrame.new(position + Vector3.new(0, 17, 0)), color, Enum.Material.Neon)
    tower.CanCollide = false
    addLabelBillboard(tower, labelText, Color3.fromRGB(255, 255, 255))

    local glow = Instance.new("PointLight")
    glow.Name = name .. "Glow"
    glow.Color = color
    glow.Brightness = 2.4
    glow.Range = 70
    glow.Shadows = false
    glow.Parent = tower
end

local function addLampPost(position, color)
    local pole = createPart("CampusLampPost", Vector3.new(0.8, 10, 0.8), CFrame.new(position + Vector3.new(0, 5, 0)), Color3.fromRGB(50, 55, 62), Enum.Material.Metal)
    local lamp = createPart("CampusLampHead", Vector3.new(2.8, 1.2, 2.8), CFrame.new(position + Vector3.new(0, 10.6, 0)), color or Color3.fromRGB(255, 235, 170), Enum.Material.Neon)
    lamp.CanCollide = false

    local light = Instance.new("PointLight")
    light.Name = "CampusLampGlow"
    light.Color = color or Color3.fromRGB(255, 235, 170)
    light.Brightness = 1.8
    light.Range = 32
    light.Shadows = false
    light.Parent = lamp
end

local function addBarricade(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("WarningBarricadeA", Vector3.new(9, 1.2, 0.8), base * CFrame.new(0, 2.4, 0), colors.warning, Enum.Material.Wood)
    createPart("WarningBarricadeB", Vector3.new(9, 1.2, 0.8), base * CFrame.new(0, 0.9, 0), Color3.fromRGB(45, 45, 48), Enum.Material.Wood)
    createPart("WarningBarricadeLegA", Vector3.new(0.7, 3.8, 0.7), base * CFrame.new(-4.2, 1.4, 0), Color3.fromRGB(70, 45, 28), Enum.Material.Wood)
    createPart("WarningBarricadeLegB", Vector3.new(0.7, 3.8, 0.7), base * CFrame.new(4.2, 1.4, 0), Color3.fromRGB(70, 45, 28), Enum.Material.Wood)
end

local function addSupplyCrates(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("SupplyCrateLarge", Vector3.new(5, 4, 5), base, Color3.fromRGB(115, 82, 45), Enum.Material.Wood)
    createPart("SupplyCrateSmallA", Vector3.new(3.5, 3, 3.5), base * CFrame.new(4.8, -0.5, 1.2), Color3.fromRGB(130, 96, 55), Enum.Material.Wood)
    createPart("SupplyCrateSmallB", Vector3.new(3, 2.6, 3), base * CFrame.new(-4.6, -0.7, -1.4), Color3.fromRGB(120, 86, 50), Enum.Material.Wood)
end

local function addBench(position, rotation)
    local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    createPart("HallBenchSeat", Vector3.new(9, 0.6, 2.2), base * CFrame.new(0, 2, 0), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
    createPart("HallBenchBack", Vector3.new(9, 2.6, 0.5), base * CFrame.new(0, 3, 1.2), Color3.fromRGB(90, 65, 42), Enum.Material.Wood)
    createPart("HallBenchLegA", Vector3.new(0.6, 2, 0.6), base * CFrame.new(-3.6, 1, -0.5), Color3.fromRGB(45, 45, 48), Enum.Material.Metal)
    createPart("HallBenchLegB", Vector3.new(0.6, 2, 0.6), base * CFrame.new(3.6, 1, -0.5), Color3.fromRGB(45, 45, 48), Enum.Material.Metal)
end

local function addDistrictProps()
    addLandmarkTower("StartWingLandmark", Vector3.new(-52, 0, 22), "시작 구역", Color3.fromRGB(70, 135, 255))
    addLandmarkTower("NorthWingLandmark", Vector3.new(-185, 0, 120), "북쪽 별관", Color3.fromRGB(150, 95, 255))
    addLandmarkTower("SouthWingLandmark", Vector3.new(135, 0, -145), "남쪽 별관", Color3.fromRGB(255, 150, 70))
    addLandmarkTower("GymLandmark", Vector3.new(-260, 0, -145), "체육관", Color3.fromRGB(255, 205, 70))
    addLandmarkTower("ExitLandmark", Vector3.new(305, 0, 0), "대탈출문", Color3.fromRGB(80, 255, 130))

    for _, pos in ipairs({
        Vector3.new(-300, 1, 0), Vector3.new(-230, 1, 80), Vector3.new(-230, 1, -80),
        Vector3.new(-120, 1, 0), Vector3.new(0, 1, 0), Vector3.new(120, 1, 0),
        Vector3.new(250, 1, 85), Vector3.new(250, 1, -85), Vector3.new(305, 1, 28),
        Vector3.new(-185, 1, 120), Vector3.new(-40, 1, 120), Vector3.new(125, 1, 120),
        Vector3.new(-220, 1, -145), Vector3.new(20, 1, -145), Vector3.new(230, 1, -145),
    }) do
        addLampPost(pos)
    end

    for _, info in ipairs({
        { Vector3.new(-132, 1.7, 18), 12 }, { Vector3.new(-76, 1.7, -16), -8 },
        { Vector3.new(72, 1.7, 18), 6 }, { Vector3.new(170, 1.7, -20), -15 },
        { Vector3.new(-215, 1.7, 102), 18 }, { Vector3.new(-112, 1.7, 142), -12 },
        { Vector3.new(168, 1.7, 103), 8 }, { Vector3.new(245, 1.7, 82), -20 },
        { Vector3.new(-295, 1.7, -118), 8 }, { Vector3.new(-210, 1.7, -174), -18 },
        { Vector3.new(84, 1.7, -124), 15 }, { Vector3.new(250, 1.7, -118), -12 },
    }) do
        addBarricade(info[1], info[2])
    end

    for _, info in ipairs({
        { Vector3.new(-155, 2.2, -28), 8 }, { Vector3.new(-18, 2.2, 84), -12 },
        { Vector3.new(68, 2.2, -84), 20 }, { Vector3.new(210, 2.2, 32), -8 },
        { Vector3.new(-280, 2.2, 126), 15 }, { Vector3.new(245, 2.2, 150), -20 },
        { Vector3.new(-116, 2.2, -180), 5 }, { Vector3.new(185, 2.2, -184), -14 },
    }) do
        addSupplyCrates(info[1], info[2])
    end

    for _, info in ipairs({
        { Vector3.new(-18, 1, 12), 0 }, { Vector3.new(72, 1, -12), 180 },
        { Vector3.new(-185, 1, 106), 0 }, { Vector3.new(-95, 1, 106), 0 },
        { Vector3.new(125, 1, 106), 0 }, { Vector3.new(225, 1, 86), 0 },
        { Vector3.new(-165, 1, -168), 180 }, { Vector3.new(118, 1, -158), 180 },
    }) do
        addBench(info[1], info[2])
    end

    for _, pos in ipairs({
        Vector3.new(65, 1, -12), Vector3.new(95, 1, -22), Vector3.new(130, 1, -8),
        Vector3.new(165, 1, -56), Vector3.new(68, 1, -72), Vector3.new(148, 1, -76),
        Vector3.new(-308, 1, 164), Vector3.new(-286, 1, 190), Vector3.new(292, 1, 158),
        Vector3.new(318, 1, 186), Vector3.new(-310, 1, -188), Vector3.new(310, 1, -190),
    }) do
        addTree(pos, 0.9 + (math.abs(pos.X + pos.Z) % 4) * 0.12)
    end
end

local function addNoiseTrap(name, position, size)
    local trap = createPart(name, size, CFrame.new(position), Color3.fromRGB(205, 65, 65), Enum.Material.Glass)
    trap.Transparency = 0.35
    trap.CanCollide = false
    trap.CanTouch = true
    addLabelBillboard(trap, "깨진 유리", Color3.fromRGB(255, 205, 205))

    local debounce = {}
    trap.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or debounce[player] then
            return
        end

        debounce[player] = true
        player:SetAttribute("NoisyUntil", os.clock() + 6)
        fireMessage(player, "Info", GameConfig.Messages.Noise)
        task.delay(2.5, function()
            debounce[player] = nil
        end)
    end)
end

local function buildMap()
    createPart("SchoolFloor", Vector3.new(700, 1, 460), CFrame.new(0, 0, 0), colors.floor, Enum.Material.Concrete)
    createPart("MainCorridorFloor", Vector3.new(640, 0.08, 16), CFrame.new(0, 0.55, 0), colors.corridor, Enum.Material.Slate)
    createPart("NorthCorridorFloor", Vector3.new(520, 0.08, 14), CFrame.new(20, 0.55, 120), Color3.fromRGB(66, 86, 112), Enum.Material.Slate)
    createPart("SouthCorridorFloor", Vector3.new(520, 0.08, 14), CFrame.new(20, 0.55, -145), Color3.fromRGB(66, 86, 112), Enum.Material.Slate)
    createPart("WestConnectorFloor", Vector3.new(14, 0.08, 260), CFrame.new(-230, 0.56, 0), Color3.fromRGB(66, 86, 112), Enum.Material.Slate)
    createPart("EastConnectorFloor", Vector3.new(14, 0.08, 260), CFrame.new(250, 0.56, 0), Color3.fromRGB(66, 86, 112), Enum.Material.Slate)
    local ceiling = createPart("OpenCeilingGuide", Vector3.new(700, 0.2, 460), CFrame.new(0, 15.5, 0), Color3.fromRGB(130, 138, 150), Enum.Material.SmoothPlastic)
    ceiling.Transparency = 0.72
    ceiling.CanCollide = false

    for index = 1, 11 do
        addGuideTile("MainGuideLine" .. index, Vector3.new(-270 + index * 50, 0.72, 0), Vector3.new(28, 0.08, 1.1))
    end
    for index = 1, 8 do
        addGuideTile("NorthGuideLine" .. index, Vector3.new(-210 + index * 55, 0.72, 120), Vector3.new(30, 0.08, 1.1), Color3.fromRGB(140, 210, 255))
        addGuideTile("SouthGuideLine" .. index, Vector3.new(-210 + index * 55, 0.72, -145), Vector3.new(30, 0.08, 1.1), Color3.fromRGB(255, 190, 105))
    end
    addGuideTile("GuideLineExit", Vector3.new(285, 0.72, 0), Vector3.new(44, 0.08, 1.3), Color3.fromRGB(95, 230, 145))

    addWall("NorthOuterWall", Vector3.new(0, 6, 230), Vector3.new(700, 12, 2))
    addWall("SouthOuterWall", Vector3.new(0, 6, -230), Vector3.new(700, 12, 2))
    addWall("WestOuterWall", Vector3.new(-350, 6, 0), Vector3.new(2, 12, 460))
    addWall("EastOuterWallTop", Vector3.new(350, 6, 125), Vector3.new(2, 12, 210))
    addWall("EastOuterWallBottom", Vector3.new(350, 6, -125), Vector3.new(2, 12, 210))

    -- 복도 천장
    createPart("MainCorridorCeiling", Vector3.new(640, 0.4, 16), CFrame.new(0, 12.2, 0), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)
    createPart("NorthCorridorCeiling", Vector3.new(520, 0.4, 14), CFrame.new(20, 12.2, 120), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)
    createPart("SouthCorridorCeiling", Vector3.new(520, 0.4, 14), CFrame.new(20, 12.2, -145), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)
    createPart("WestConnectorCeiling", Vector3.new(14, 0.4, 248), CFrame.new(-230, 12.2, 0), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)
    createPart("EastConnectorCeiling", Vector3.new(14, 0.4, 248), CFrame.new(250, 12.2, 0), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)
    createPart("GymCeiling", Vector3.new(86, 0.4, 58), CFrame.new(-260, 12.2, -145), Color3.fromRGB(195, 198, 205), Enum.Material.SmoothPlastic)

    -- 복도 기둥 (주 복도 양쪽)
    for colI = 0, 5 do
        local colX = -250 + colI * 100
        addCorridorColumn("MainN" .. colI, Vector3.new(colX, 0, 7))
        addCorridorColumn("MainS" .. colI, Vector3.new(colX, 0, -7))
    end
    -- 북쪽 별관 복도 기둥
    for colI = 0, 4 do
        local colX = -200 + colI * 100
        addCorridorColumn("NorthW" .. colI, Vector3.new(colX, 0, 127))
        addCorridorColumn("NorthE" .. colI, Vector3.new(colX, 0, 113))
    end
    -- 남쪽 별관 복도 기둥
    for colI = 0, 4 do
        local colX = -200 + colI * 100
        addCorridorColumn("SouthW" .. colI, Vector3.new(colX, 0, -138))
        addCorridorColumn("SouthE" .. colI, Vector3.new(colX, 0, -152))
    end

    -- 북쪽 외벽 창문
    for winI = 0, 10 do
        addOuterWallWindow("North" .. winI, Vector3.new(-275 + winI * 55, 6.5, 229.3))
    end
    -- 남쪽 외벽 창문
    for winI = 0, 10 do
        addOuterWallWindow("South" .. winI, Vector3.new(-275 + winI * 55, 6.5, -229.3))
    end
    -- 외벽 내측 걸레받이
    local wainColor2 = Color3.fromRGB(148, 136, 122)
    local outerWainN = createPart("OuterWainscotN", Vector3.new(700, 2.8, 0.22), CFrame.new(0, 1.4, 229.1), wainColor2, Enum.Material.SmoothPlastic)
    outerWainN.CanCollide = false
    local outerWainS = createPart("OuterWainscotS", Vector3.new(700, 2.8, 0.22), CFrame.new(0, 1.4, -229.1), wainColor2, Enum.Material.SmoothPlastic)
    outerWainS.CanCollide = false

    addWall("StartRoomNorthLeft", Vector3.new(-57, 6, 12), Vector3.new(12, 12, 2))
    addWall("StartRoomNorthRight", Vector3.new(-35, 6, 12), Vector3.new(12, 12, 2))
    addWall("StartRoomWest", Vector3.new(-63, 6, 25), Vector3.new(2, 12, 28))
    addWall("StartRoomEast", Vector3.new(-29, 6, 25), Vector3.new(2, 12, 28))

    addWall("ClassroomANorth", Vector3.new(-8, 6, 25), Vector3.new(24, 12, 2))
    addWall("ClassroomAWest", Vector3.new(-20, 6, 32), Vector3.new(2, 12, 16))
    addWall("ClassroomAEast", Vector3.new(4, 6, 32), Vector3.new(2, 12, 16))

    addWall("ClassroomBNorth", Vector3.new(28, 6, 25), Vector3.new(24, 12, 2))
    addWall("ClassroomBWest", Vector3.new(16, 6, 32), Vector3.new(2, 12, 16))
    addWall("ClassroomBEast", Vector3.new(40, 6, 32), Vector3.new(2, 12, 16))

    addWall("ClassroomCSouth", Vector3.new(16, 6, -25), Vector3.new(36, 12, 2))
    addWall("ClassroomCWest", Vector3.new(-2, 6, -32), Vector3.new(2, 12, 16))
    addWall("ClassroomCEast", Vector3.new(34, 6, -32), Vector3.new(2, 12, 16))

    addSign("MainHallSign", Vector3.new(-8, 9, -6.4), "부서진 학교", Color3.fromRGB(38, 72, 120))
    addSign("ExitArrowSign", Vector3.new(260, 7.8, 6.4), "대탈출문 ->", Color3.fromRGB(35, 125, 70))
    addSign("GeneratorArrowSign", Vector3.new(210, 7.8, -134), "남쪽 발전기실", Color3.fromRGB(42, 92, 130))
    addSign("NorthWingSign", Vector3.new(-170, 7.8, 113), "북쪽 별관", Color3.fromRGB(82, 55, 145))
    addSign("GymSign", Vector3.new(-250, 7.8, -136), "체육관", Color3.fromRGB(120, 70, 35))
    addTrophyCase(Vector3.new(-42, 4, 6.8), 180)

    addDoorMarker(Vector3.new(-46, 4, 12.9), 0, "시작 교실", Color3.fromRGB(70, 115, 200))
    addDoorMarker(Vector3.new(-8, 4, 24.1), 180, "도서관", Color3.fromRGB(82, 55, 145))
    addDoorMarker(Vector3.new(28, 4, 24.1), 180, "교실 B", Color3.fromRGB(170, 95, 45))
    addDoorMarker(Vector3.new(16, 4, -24.1), 0, "급식실", Color3.fromRGB(170, 65, 55))
    addDoorMarker(Vector3.new(49, 4, -19.8), 0, "발전기실", Color3.fromRGB(45, 120, 165))

    addBlackboard(Vector3.new(-46, 4.7, 12.9), 0, "퓨즈 3개")
    addBlackboard(Vector3.new(28, 4.7, 24.1), 180, "괴물을 피해!")
    addDistrictProps()

    addLargeClassroomBlock(Vector3.new(-185, 0, 135), "과학실", Color3.fromRGB(54, 115, 95))
    addLargeClassroomWalls(Vector3.new(-185, 0, 135))
    addLargeClassroomCeiling(Vector3.new(-185, 0, 135))
    addScienceLabProps(Vector3.new(-185, 0, 135))

    addLargeClassroomBlock(Vector3.new(-95, 0, 135), "음악실", Color3.fromRGB(105, 74, 135))
    addLargeClassroomWalls(Vector3.new(-95, 0, 135))
    addLargeClassroomCeiling(Vector3.new(-95, 0, 135))
    addMusicRoomProps(Vector3.new(-95, 0, 135))

    addLargeClassroomBlock(Vector3.new(125, 0, 135), "미술실", Color3.fromRGB(155, 95, 70))
    addLargeClassroomWalls(Vector3.new(125, 0, 135))
    addLargeClassroomCeiling(Vector3.new(125, 0, 135))
    addArtRoomProps(Vector3.new(125, 0, 135))

    addLargeClassroomBlock(Vector3.new(225, 0, 110), "방송실", Color3.fromRGB(70, 120, 155))
    addLargeClassroomWalls(Vector3.new(225, 0, 110))
    addLargeClassroomCeiling(Vector3.new(225, 0, 110))
    addBroadcastRoomProps(Vector3.new(225, 0, 110))

    addLargeClassroomBlock(Vector3.new(-165, 0, -145), "보건실", Color3.fromRGB(130, 80, 100))
    addLargeClassroomWalls(Vector3.new(-165, 0, -145))
    addLargeClassroomCeiling(Vector3.new(-165, 0, -145))
    addHealthRoomProps(Vector3.new(-165, 0, -145))

    createPart("GymFloor", Vector3.new(86, 0.16, 58), CFrame.new(-260, 0.82, -145), Color3.fromRGB(88, 96, 108), Enum.Material.WoodPlanks)
    addWall("GymSouthWall", Vector3.new(-260, 6, -174), Vector3.new(86, 12, 2))
    addWall("GymEastWall", Vector3.new(-217, 6, -158), Vector3.new(2, 12, 32))
    addWall("GymWestWall", Vector3.new(-303, 6, -158), Vector3.new(2, 12, 32))
    addGymBleacher(Vector3.new(-290, 1, -168), 0)
    createPart("BasketballCourtLine", Vector3.new(62, 0.1, 2), CFrame.new(-260, 1, -145), Color3.fromRGB(255, 235, 130), Enum.Material.Neon)
    createPart("BasketballHoopA", Vector3.new(6, 6, 0.5), CFrame.new(-300, 6, -145), Color3.fromRGB(255, 135, 45), Enum.Material.Neon)
    createPart("BasketballHoopB", Vector3.new(6, 6, 0.5), CFrame.new(-220, 6, -145), Color3.fromRGB(255, 135, 45), Enum.Material.Neon)
    createPart("GymWallCrack", Vector3.new(0.14, 6, 3),
        CFrame.new(-303.1, 6, -164) * CFrame.Angles(0, 0, math.rad(5)),
        Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic).CanCollide = false

    createPart("OutdoorYard", Vector3.new(120, 0.12, 70), CFrame.new(115, 0.9, -35), Color3.fromRGB(70, 135, 70), Enum.Material.Grass)
    addTree(Vector3.new(80, 1, -50), 1.2)
    addTree(Vector3.new(130, 1, -70), 1)
    addTree(Vector3.new(160, 1, -20), 1.1)

    createPart("LibraryZoneFloor", Vector3.new(32, 0.08, 20), CFrame.new(-12, 0.62, 31), Color3.fromRGB(80, 72, 105), Enum.Material.WoodPlanks)
    addShelf(Vector3.new(-16, 4, 31), 0)
    addShelf(Vector3.new(-8, 4, 31), 0)
    addShelf(Vector3.new(0, 4, 31), 0)
    addShelf(Vector3.new(-20, 4, 35), 90)
    addShelf(Vector3.new(3, 4, 35), 90)

    createPart("CafeteriaZoneFloor", Vector3.new(34, 0.08, 20), CFrame.new(24, 0.62, -31), Color3.fromRGB(92, 78, 64), Enum.Material.Tile)
    addCafeteriaTable(Vector3.new(9, 2.2, -31), 0)
    addCafeteriaTable(Vector3.new(22, 2.2, -31), 0)
    addCafeteriaTable(Vector3.new(35, 2.2, -31), 0)
    addVendingMachine(Vector3.new(39, 3.4, -36), 0)

    createPart("GeneratorRoomMarker", Vector3.new(52, 0.1, 36), CFrame.new(230, 0.7, -145), Color3.fromRGB(55, 105, 135), Enum.Material.Metal)
    createPart("BrokenPipeA", Vector3.new(36, 0.7, 0.7), CFrame.new(230, 8.5, -165) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(80, 88, 92), Enum.Material.Metal)
    createPart("BrokenPipeB", Vector3.new(0.7, 0.7, 28), CFrame.new(255, 8.3, -145) * CFrame.Angles(math.rad(4), 0, 0), Color3.fromRGB(80, 88, 92), Enum.Material.Metal)

    addLocker(Vector3.new(-44, 4, -7), 0)
    addLocker(Vector3.new(-37, 4, -7), 0)
    addLocker(Vector3.new(13, 4, 9), 180)
    addLocker(Vector3.new(20, 4, 9), 180)
    addLocker(Vector3.new(44, 4, -8), 0)

    -- 북쪽 별관 복도 사물함 줄 (z=124 = 북쪽 복도 안쪽 벽)
    for i = 1, 6 do
        addLocker(Vector3.new(-220 + (i - 1) * 72, 4, 124), 180)
    end

    -- 남쪽 별관 복도 사물함 줄 (z=-149 = 남쪽 복도 안쪽 벽)
    for i = 1, 5 do
        addLocker(Vector3.new(-185 + (i - 1) * 85, 4, -149), 0)
    end

    -- 쓰러진 사물함 (분위기용)
    createPart("FallenLockerNA", Vector3.new(3, 7, 2.2),
        CFrame.new(-78, 1.5, 119) * CFrame.Angles(0, math.rad(12), math.rad(-88)),
        Color3.fromRGB(35, 70, 95), Enum.Material.Metal)
    createPart("FallenLockerNB", Vector3.new(3, 7, 2.2),
        CFrame.new(68, 1.5, 122) * CFrame.Angles(0, math.rad(-8), math.rad(85)),
        Color3.fromRGB(35, 70, 95), Enum.Material.Metal)
    createPart("FallenLockerSA", Vector3.new(3, 7, 2.2),
        CFrame.new(-55, 1.5, -141) * CFrame.Angles(0, math.rad(5), math.rad(88)),
        Color3.fromRGB(35, 70, 95), Enum.Material.Metal)
    createPart("FallenLockerSB", Vector3.new(3, 7, 2.2),
        CFrame.new(145, 1.5, -138) * CFrame.Angles(0, math.rad(-14), math.rad(-86)),
        Color3.fromRGB(35, 70, 95), Enum.Material.Metal)

    addNoiseTrap("BrokenGlassTrapA", Vector3.new(-18, 0.8, -4), Vector3.new(9, 0.12, 4))
    addNoiseTrap("BrokenGlassTrapB", Vector3.new(24, 0.8, 8), Vector3.new(8, 0.12, 4))
    addNoiseTrap("BrokenGlassTrapC", Vector3.new(44, 0.8, -18), Vector3.new(7, 0.12, 5))
    -- 북쪽 별관 복도 깨진 유리
    addNoiseTrap("BrokenGlassNorthA", Vector3.new(-155, 0.65, 118), Vector3.new(10, 0.1, 5))
    addNoiseTrap("BrokenGlassNorthB", Vector3.new(30, 0.65, 122), Vector3.new(9, 0.1, 4))
    addNoiseTrap("BrokenGlassNorthC", Vector3.new(175, 0.65, 119), Vector3.new(8, 0.1, 5))
    -- 남쪽 별관 복도 깨진 유리
    addNoiseTrap("BrokenGlassSouthA", Vector3.new(-80, 0.65, -142), Vector3.new(9, 0.1, 5))
    addNoiseTrap("BrokenGlassSouthB", Vector3.new(80, 0.65, -141), Vector3.new(10, 0.1, 4))

    -- 별관 복도 추가 장식 (쓰러진 의자, 서류 더미)
    for i = 0, 3 do
        addChair(Vector3.new(-200 + i * 85, 1.2, 116), -45 + i * 30)
    end
    for i = 0, 2 do
        addChair(Vector3.new(-150 + i * 100, 1.2, -138), 15 + i * 40)
    end
    createPart("ScatteredPapersN1", Vector3.new(12, 0.06, 8),
        CFrame.new(-120, 0.72, 120) * CFrame.Angles(0, math.rad(12), 0),
        Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic).CanCollide = false
    createPart("ScatteredPapersN2", Vector3.new(10, 0.06, 6),
        CFrame.new(60, 0.72, 122) * CFrame.Angles(0, math.rad(-8), 0),
        Color3.fromRGB(235, 230, 215), Enum.Material.SmoothPlastic).CanCollide = false
    createPart("ScatteredPapersS1", Vector3.new(11, 0.06, 7),
        CFrame.new(-20, 0.72, -143) * CFrame.Angles(0, math.rad(20), 0),
        Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic).CanCollide = false

    createPart("LowSlideObstacle", Vector3.new(8, 2, 1.2), CFrame.new(0, 1.5, -6), colors.warning, Enum.Material.Wood)
    createPart("LowSlideObstacle2", Vector3.new(7, 2, 1.2), CFrame.new(30, 1.5, 6), colors.warning, Enum.Material.Wood)

    for _, lightInfo in ipairs({
        {"LightStart", Vector3.new(-52, 8.5, 23), 4.4, 38},
        {"LightHallA", Vector3.new(-28, 8.5, 0), 3.8, 36},
        {"LightHallB", Vector3.new(4, 8.5, 0), 3.6, 36},
        {"LightHallC", Vector3.new(36, 8.5, 0), 4.0, 38},
        {"LightExit", Vector3.new(58, 8.5, 0), 5.0, 44, Color3.fromRGB(190, 255, 205)},
        {"LightLibrary", Vector3.new(-8, 8.5, 32), 4.2, 34, Color3.fromRGB(230, 220, 255)},
        {"LightCafeteria", Vector3.new(24, 8.5, -31), 4.2, 34, Color3.fromRGB(255, 230, 190)},
        {"LightGenerator", Vector3.new(50, 8.5, -26), 4.5, 36, Color3.fromRGB(190, 235, 255)},
        {"LightNorthWingA", Vector3.new(-180, 9, 120), 5.2, 60, Color3.fromRGB(230, 220, 255)},
        {"LightNorthWingB", Vector3.new(145, 9, 120), 5.2, 60, Color3.fromRGB(230, 240, 255)},
        {"LightSouthWingA", Vector3.new(-180, 9, -145), 5.2, 60, Color3.fromRGB(255, 225, 190)},
        {"LightSouthWingB", Vector3.new(210, 9, -145), 5.2, 60, Color3.fromRGB(190, 235, 255)},
        {"LightExitLarge", Vector3.new(300, 10, 0), 7.0, 70, Color3.fromRGB(190, 255, 205)},
    }) do
        addLight(lightInfo[1], lightInfo[2], lightInfo[3], lightInfo[4], lightInfo[5])
    end

    addAreaLightPanel("CeilingPanelStart", Vector3.new(-52, 11.2, 22), Vector3.new(8, 0.25, 4))
    addAreaLightPanel("CeilingPanelHallA", Vector3.new(-24, 11.2, 0), Vector3.new(9, 0.25, 4))
    addAreaLightPanel("CeilingPanelHallB", Vector3.new(8, 11.2, 0), Vector3.new(9, 0.25, 4))
    addAreaLightPanel("CeilingPanelHallC", Vector3.new(38, 11.2, 0), Vector3.new(9, 0.25, 4))
    addAreaLightPanel("CeilingPanelLibrary", Vector3.new(-8, 11.2, 32), Vector3.new(9, 0.25, 4), Color3.fromRGB(230, 220, 255))
    addAreaLightPanel("CeilingPanelCafeteria", Vector3.new(24, 11.2, -31), Vector3.new(9, 0.25, 4), Color3.fromRGB(255, 230, 190))
    addAreaLightPanel("CeilingPanelGenerator", Vector3.new(50, 11.2, -26), Vector3.new(9, 0.25, 4), Color3.fromRGB(190, 235, 255))
    addAreaLightPanel("CeilingPanelNorthWing", Vector3.new(-65, 11.2, 120), Vector3.new(230, 0.25, 5), Color3.fromRGB(230, 220, 255))
    addAreaLightPanel("CeilingPanelSouthWing", Vector3.new(10, 11.2, -145), Vector3.new(280, 0.25, 5), Color3.fromRGB(255, 230, 190))
    addAreaLightPanel("CeilingPanelEastWing", Vector3.new(250, 11.2, 0), Vector3.new(5, 0.25, 250), Color3.fromRGB(210, 245, 255))

    addDesk(Vector3.new(-54, 1.5, 28), 8)
    addDesk(Vector3.new(-46, 1.5, 29), -12)
    addDesk(Vector3.new(-56, 1.5, 20), 18)
    addDesk(Vector3.new(-48, 1.5, 20), -8)
    addDesk(Vector3.new(-10, 1.5, 33), 20)
    addDesk(Vector3.new(25, 1.5, 33), -16)
    addDesk(Vector3.new(33, 1.5, 33), 14)
    addDesk(Vector3.new(24, 1.5, 28), 5)
    addDesk(Vector3.new(16, 1.5, -33), 28)
    addChair(Vector3.new(-40, 1.2, 21), 28)
    addChair(Vector3.new(-52, 1.2, 19), -18)
    addChair(Vector3.new(-44, 1.2, 28), 10)
    addChair(Vector3.new(8, 1.2, -30), -45)
    addChair(Vector3.new(34, 1.2, 31), 18)
    addChair(Vector3.new(28, 1.2, 28), -8)

    addCrack(Vector3.new(-63.9, 6, 5), Vector3.new(0.08, 5, 0.35), 0)
    addCrack(Vector3.new(-12, 0.64, -8), Vector3.new(0.2, 0.08, 7), 25)
    addCrack(Vector3.new(20, 0.64, 8), Vector3.new(0.2, 0.08, 6), -35)
    addCrack(Vector3.new(52, 6, 40.1), Vector3.new(8, 0.08, 0.25), 0)
end

local function createSpawnAndExit()
    local spawnLocation = findWorldPart("PlayerSpawn")
    if not (spawnLocation and spawnLocation:IsA("SpawnLocation")) then
        spawnLocation = Instance.new("SpawnLocation")
        spawnLocation.Name = "PlayerSpawn"
        spawnLocation.Size = Vector3.new(8, 1, 8)
        spawnLocation.CFrame = CFrame.new(GameConfig.Spawn.Position)
        spawnLocation.Color = Color3.fromRGB(70, 115, 200)
        spawnLocation.Material = Enum.Material.Neon
        spawnLocation.Parent = worldFolder
        addLabelBillboard(spawnLocation, "시작 교실", Color3.fromRGB(210, 230, 255))
    end
    spawnLocation.Anchored = true
    spawnLocation.Neutral = true
    spawnLocation.AllowTeamChangeOnTouch = false

    local exitPart = getOrCreatePart("EscapeExit", GameConfig.Exit.Size, CFrame.new(GameConfig.Exit.Position), colors.exit, Enum.Material.Neon)
    exitDoorPart = exitPart
    exitPart.CanCollide = false
    exitPart.Transparency = 0.55
    addLabelBillboard(exitPart, "탈출문", Color3.fromRGB(190, 255, 210))

    exitLockPart = getOrCreatePart("ExitLockBarrier", Vector3.new(8, 9, 12), CFrame.new(GameConfig.Exit.Position), colors.locked, Enum.Material.ForceField)
    exitLockPart.CanCollide = true
    exitLockPart.Transparency = 0.35
    addLabelBillboard(exitLockPart, "잠김: 퓨즈 3개 + 발전기", Color3.fromRGB(255, 190, 190))

    local victoryPlatform = getOrCreatePart("VictoryPlatform", Vector3.new(20, 1, 20), CFrame.new(GameConfig.Victory.Position - Vector3.new(0, 2.5, 0)), Color3.fromRGB(70, 170, 105), Enum.Material.Grass)
    addLabelBillboard(victoryPlatform, "탈출 성공 지점", Color3.fromRGB(210, 255, 220))

    local exitDebounce = {}
    exitPart.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or exitDebounce[player] then
            return
        end

        exitDebounce[player] = true
        if not gameState.exitOpen then
            fireMessage(player, "Info", GameConfig.Messages.DoorLocked)
            task.delay(1, function()
                exitDebounce[player] = nil
            end)
            return
        end

        -- 탈출 성공: wonPlayers에 등록하고 승리 위치로 이동
        wonPlayers[player] = true
        player:SetAttribute("HasEscaped", true)
        gameEvent:FireClient(player, "Escaped", GameConfig.Messages.Escaped)

        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            character:PivotTo(CFrame.new(GameConfig.Victory.Position))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        -- 디바운스는 해제하지 않음 → 재진입 불가
    end)

    exitLockPart.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player and not gameState.exitOpen then
            fireMessage(player, "Info", GameConfig.Messages.DoorLocked)
        end
    end)
end

local function unlockExit()
    gameState.generatorPowered = true
    gameState.exitOpen = true

    if exitLockPart then
        exitLockPart.CanCollide = false
        exitLockPart.Transparency = 1
        exitLockPart:Destroy()
        exitLockPart = nil
    end

    if exitDoorPart then
        exitDoorPart.Transparency = 0.12
        exitDoorPart.Color = Color3.fromRGB(80, 255, 150)
    end

    -- 최종 추격 페이즈: 조명을 붉게 바꿔 긴박감 연출
    Lighting.Brightness = 2.2
    Lighting.Ambient = Color3.fromRGB(122, 58, 58)
    Lighting.OutdoorAmbient = Color3.fromRGB(88, 44, 44)
    Lighting.FogColor = Color3.fromRGB(92, 38, 38)
    Lighting.FogEnd = 220

    gameEvent:FireAllClients("Info", GameConfig.Messages.GeneratorReady)
    task.delay(1.5, function()
        gameEvent:FireAllClients("FinalChase", GameConfig.Messages.FinalChase)
    end)
    broadcastProgress()
end

local function createPickupBase(name, position, color, labelText)
    local pickup = getOrCreatePart(name, Vector3.new(3.2, 3.2, 3.2), CFrame.new(position), color, Enum.Material.Neon)
    pickup.Shape = Enum.PartType.Ball
    pickup.CanCollide = false
    pickup.CanTouch = true
    addLabelBillboard(pickup, labelText, Color3.fromRGB(255, 255, 210))

    local light = pickup:FindFirstChild("PickupGlow")
    if not light then
        light = Instance.new("PointLight")
        light.Name = "PickupGlow"
        light.Parent = pickup
    end
    light.Color = color
    light.Brightness = 1.6
    light.Range = 16

    return pickup
end

local function createFuse(index, position)
    local fuse = createPickupBase("Fuse" .. index, position, colors.fuse, "퓨즈")
    local taken = false

    fuse.Touched:Connect(function(hit)
        if taken then
            return
        end

        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        taken = true
        gameState.collectedFuses = math.clamp(gameState.collectedFuses + 1, 0, GameConfig.Objective.RequiredFuses)
        fuse:Destroy()
        fireMessageAndSync(player, "Info", string.format("%s (%d/%d)", GameConfig.Messages.FuseCollected, gameState.collectedFuses, GameConfig.Objective.RequiredFuses))
    end)
end

local function createGenerator()
    local base = CFrame.new(GameConfig.Items.Generator)
    local generator = getOrCreatePart("EmergencyGenerator", Vector3.new(6, 4, 4), base, colors.generator, Enum.Material.Metal)
    local coil = getOrCreatePart("GeneratorCoil", Vector3.new(4.6, 1.1, 1.1), base * CFrame.new(0, 1.5, -2.2), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
    coil.CanCollide = false
    addLabelBillboard(generator, "발전기", Color3.fromRGB(190, 240, 255))

    local light = generator:FindFirstChild("GeneratorGlow")
    if not light then
        light = Instance.new("PointLight")
        light.Name = "GeneratorGlow"
        light.Parent = generator
    end
    light.Color = Color3.fromRGB(90, 210, 255)
    light.Brightness = 1.8
    light.Range = 18

    local debounce = {}
    generator.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or debounce[player] then
            return
        end

        debounce[player] = true
        if gameState.exitOpen then
            fireMessage(player, "Info", "이미 탈출문이 열려 있어요!")
        elseif gameState.collectedFuses >= GameConfig.Objective.RequiredFuses then
            unlockExit()
        else
            fireMessage(player, "Info", string.format("%s (%d/%d)", GameConfig.Messages.NeedMoreFuses, gameState.collectedFuses, GameConfig.Objective.RequiredFuses))
        end

        task.delay(1, function()
            debounce[player] = nil
        end)
    end)
end

local function createFlashlightPickup()
    local pickup = createPickupBase("FlashlightPickup", GameConfig.Items.Flashlight, Color3.fromRGB(220, 235, 255), "손전등")
    pickup.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or player:GetAttribute("HasFlashlight") then
            return
        end

        player:SetAttribute("HasFlashlight", true)
        pickup:Destroy()
        fireMessage(player, "Flashlight", GameConfig.Messages.FlashlightCollected)
    end)
end

local function createBoostPickup()
    local pickup = createPickupBase("BoostDrinkPickup", GameConfig.Items.BoostDrink, colors.boost, "에너지")
    local taken = false

    pickup.Touched:Connect(function(hit)
        if taken then
            return
        end

        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not player or not humanoid then
            return
        end

        taken = true
        pickup:Destroy()
        local token = os.clock()
        player:SetAttribute("BoostToken", token)
        humanoid.WalkSpeed = GameConfig.Player.BoostWalkSpeed
        fireMessage(player, "Info", GameConfig.Messages.BoostCollected)

        task.delay(GameConfig.Player.BoostDuration, function()
            if player:GetAttribute("BoostToken") == token and humanoid.Parent then
                humanoid.WalkSpeed = GameConfig.Player.DefaultWalkSpeed
            end
        end)
    end)
end

local function createShieldPickup()
    local pickup = createPickupBase("ShieldCharmPickup", GameConfig.Items.ShieldCharm, colors.shield, "보호 부적")
    local taken = false

    pickup.Touched:Connect(function(hit)
        if taken then
            return
        end

        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        taken = true
        pickup:Destroy()
        setPlayerAttributeNumber(player, "ShieldCount", 1)
        fireMessage(player, "Info", GameConfig.Messages.ShieldCollected)
    end)
end

local function createGuideNpc()
    local basePosition = Vector3.new(-56, 3, 17)
    local existingBody = findWorldPart("GuideBody")
    if existingBody then
        addLabelBillboard(existingBody, "로비", Color3.fromRGB(210, 230, 255))

        local hintZone = getOrCreatePart("GuideHintZone", Vector3.new(8, 6, 8), CFrame.new(basePosition), Color3.fromRGB(90, 140, 255), Enum.Material.ForceField)
        hintZone.Transparency = 1
        hintZone.CanCollide = false

        local debounce = {}
        hintZone.Touched:Connect(function(hit)
            local character = hit:FindFirstAncestorOfClass("Model")
            local player = character and Players:GetPlayerFromCharacter(character)
            if player and not debounce[player] then
                debounce[player] = true
                fireMessage(player, "Info", GameConfig.Messages.Guide)
                task.delay(6, function()
                    debounce[player] = nil
                end)
            end
        end)
        return
    end

    local npc = Instance.new("Model")
    npc.Name = "GuideRobby"
    npc.Parent = worldFolder

    local body = createPart("GuideBody", Vector3.new(3, 4.2, 2.4), CFrame.new(basePosition), Color3.fromRGB(80, 125, 215), Enum.Material.SmoothPlastic, npc)
    body.Shape = Enum.PartType.Ball
    body.CanCollide = false
    npc.PrimaryPart = body

    local eyeA = createPart("GuideEyeA", Vector3.new(0.55, 0.55, 0.2), CFrame.new(basePosition + Vector3.new(-0.55, 0.65, -1.18)), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, npc)
    eyeA.Shape = Enum.PartType.Ball
    eyeA.CanCollide = false
    local eyeB = createPart("GuideEyeB", Vector3.new(0.55, 0.55, 0.2), CFrame.new(basePosition + Vector3.new(0.55, 0.65, -1.18)), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, npc)
    eyeB.Shape = Enum.PartType.Ball
    eyeB.CanCollide = false
    local mouth = createPart("GuideSmile", Vector3.new(1.1, 0.18, 0.12), CFrame.new(basePosition + Vector3.new(0, -0.35, -1.28)), Color3.fromRGB(25, 25, 35), Enum.Material.SmoothPlastic, npc)
    mouth.CanCollide = false

    addLabelBillboard(body, "로비", Color3.fromRGB(210, 230, 255))

    local hintZone = createPart("GuideHintZone", Vector3.new(8, 6, 8), CFrame.new(basePosition), Color3.fromRGB(90, 140, 255), Enum.Material.ForceField)
    hintZone.Transparency = 1
    hintZone.CanCollide = false

    local debounce = {}
    hintZone.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player and not debounce[player] then
            debounce[player] = true
            fireMessage(player, "Info", GameConfig.Messages.Guide)
            task.delay(6, function()
                debounce[player] = nil
            end)
        end
    end)
end

local function createObjectivesAndItems()
    for index, position in ipairs(GameConfig.Items.Fuses) do
        createFuse(index, position)
    end

    createGenerator()
    createFlashlightPickup()
    createBoostPickup()
    createShieldPickup()
    createGuideNpc()
    broadcastProgress()
end

local function createMonster()
    local monster = Instance.new("Model")
    monster.Name = "EyeMonster"
    monster.Parent = worldFolder
    monsterModel = monster

    local hitbox = createPart("MonsterHitbox", Vector3.new(5, 7, 5), CFrame.new(GameConfig.Monster.SpawnPosition), colors.monster, Enum.Material.SmoothPlastic, monster)
    hitbox.Transparency = 1
    hitbox.CanCollide = false
    hitbox.CanTouch = true
    monster.PrimaryPart = hitbox

    local body = createPart("MonsterBody", Vector3.new(4.5, 5.2, 3.4), CFrame.new(GameConfig.Monster.SpawnPosition), colors.monster, Enum.Material.SmoothPlastic, monster)
    body.Shape = Enum.PartType.Ball
    body.CanCollide = false

    local eyeLeft = createPart("LeftEye", Vector3.new(0.9, 0.9, 0.28), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(-0.85, 1.1, -1.7)), Color3.fromRGB(250, 250, 235), Enum.Material.SmoothPlastic, monster)
    eyeLeft.Shape = Enum.PartType.Ball
    eyeLeft.CanCollide = false

    local eyeRight = createPart("RightEye", Vector3.new(0.9, 0.9, 0.28), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(0.85, 1.1, -1.7)), Color3.fromRGB(250, 250, 235), Enum.Material.SmoothPlastic, monster)
    eyeRight.Shape = Enum.PartType.Ball
    eyeRight.CanCollide = false

    local pupilLeft = createPart("LeftPupil", Vector3.new(0.3, 0.3, 0.12), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(-0.85, 1.1, -1.92)), Color3.fromRGB(20, 20, 25), Enum.Material.SmoothPlastic, monster)
    pupilLeft.Shape = Enum.PartType.Ball
    pupilLeft.CanCollide = false

    local pupilRight = createPart("RightPupil", Vector3.new(0.3, 0.3, 0.12), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(0.85, 1.1, -1.92)), Color3.fromRGB(20, 20, 25), Enum.Material.SmoothPlastic, monster)
    pupilRight.Shape = Enum.PartType.Ball
    pupilRight.CanCollide = false

    local mouth = createPart("TornMouth", Vector3.new(1.8, 0.42, 0.18), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(0, -0.3, -1.92)), Color3.fromRGB(25, 18, 18), Enum.Material.SmoothPlastic, monster)
    mouth.CanCollide = false

    local hornLeft = createPart("LeftHorn", Vector3.new(0.55, 1.3, 0.55), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(-1.45, 2.75, 0)), Color3.fromRGB(128, 45, 35), Enum.Material.SmoothPlastic, monster)
    hornLeft.CanCollide = false
    local hornRight = createPart("RightHorn", Vector3.new(0.55, 1.3, 0.55), CFrame.new(GameConfig.Monster.SpawnPosition + Vector3.new(1.45, 2.75, 0)), Color3.fromRGB(128, 45, 35), Enum.Material.SmoothPlastic, monster)
    hornRight.CanCollide = false

    local alertLight = Instance.new("PointLight")
    alertLight.Name = "AlertGlow"
    alertLight.Color = Color3.fromRGB(255, 80, 50)
    alertLight.Brightness = 0.6
    alertLight.Range = 14
    alertLight.Shadows = true
    alertLight.Parent = hitbox

    return monster
end

local function createGhost()
    local ghost = Instance.new("Model")
    ghost.Name = "LibraryGhost"
    ghost.Parent = worldFolder
    ghostModel = ghost

    local base = GameConfig.Ghost.SpawnPosition
    local root = createPart("GhostRoot", Vector3.new(4, 6, 4), CFrame.new(base), colors.ghost, Enum.Material.ForceField, ghost)
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    ghost.PrimaryPart = root

    local body = createPart("GhostBody", Vector3.new(4.6, 5.4, 2.4), CFrame.new(base + Vector3.new(0, -0.6, 0)), colors.ghost, Enum.Material.ForceField, ghost)
    body.Shape = Enum.PartType.Ball
    body.Transparency = 0.15
    body.CanCollide = false

    local head = createPart("GhostHead", Vector3.new(3.2, 3.2, 3.2), CFrame.new(base + Vector3.new(0, 2.4, 0)), Color3.fromRGB(225, 250, 255), Enum.Material.ForceField, ghost)
    head.Shape = Enum.PartType.Ball
    head.Transparency = 0.05
    head.CanCollide = false

    local hairBack = createPart("GhostHairBack", Vector3.new(3.8, 3.8, 0.55), CFrame.new(base + Vector3.new(0, 1.6, 1.15)), Color3.fromRGB(22, 28, 42), Enum.Material.SmoothPlastic, ghost)
    hairBack.Transparency = 0.18
    hairBack.CanCollide = false

    for index, x in ipairs({ -1.35, -0.65, 0, 0.65, 1.35 }) do
        local strand = createPart("GhostHairStrand" .. index, Vector3.new(0.45, 3.6 + index * 0.18, 0.35), CFrame.new(base + Vector3.new(x, 0.4 - (index % 2) * 0.25, -1.42)), Color3.fromRGB(18, 22, 34), Enum.Material.SmoothPlastic, ghost)
        strand.Transparency = 0.12
        strand.CanCollide = false
    end

    local eyeLeft = createPart("GhostEyeLeft", Vector3.new(0.38, 0.62, 0.16), CFrame.new(base + Vector3.new(-0.62, 2.55, -1.55)), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, ghost)
    eyeLeft.CanCollide = false
    local eyeRight = createPart("GhostEyeRight", Vector3.new(0.38, 0.62, 0.16), CFrame.new(base + Vector3.new(0.62, 2.55, -1.55)), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, ghost)
    eyeRight.CanCollide = false
    local tearLeft = createPart("GhostTearLeft", Vector3.new(0.16, 1.2, 0.1), CFrame.new(base + Vector3.new(-0.58, 1.75, -1.62)), colors.ghostBlue, Enum.Material.Neon, ghost)
    tearLeft.Transparency = 0.2
    tearLeft.CanCollide = false
    local tearRight = createPart("GhostTearRight", Vector3.new(0.16, 1.2, 0.1), CFrame.new(base + Vector3.new(0.58, 1.75, -1.62)), colors.ghostBlue, Enum.Material.Neon, ghost)
    tearRight.Transparency = 0.2
    tearRight.CanCollide = false

    for index, x in ipairs({ -1.8, -0.9, 0, 0.9, 1.8 }) do
        local tail = createPart("GhostTornDress" .. index, Vector3.new(0.7, 2.2, 0.45), CFrame.new(base + Vector3.new(x, -3.3 - (index % 2) * 0.35, 0)), colors.ghost, Enum.Material.ForceField, ghost)
        tail.Transparency = 0.48
        tail.CanCollide = false
    end

    -- 가까이 있을 때 주변을 밝히는 메인 글로우
    local glow = Instance.new("PointLight")
    glow.Name = "GhostColdGlow"
    glow.Color = Color3.fromRGB(170, 235, 255)
    glow.Brightness = 5.0
    glow.Range = 48
    glow.Shadows = true
    glow.Parent = root

    -- 멀리서도 위치를 알 수 있는 원거리 비컨 빛
    local beacon = Instance.new("PointLight")
    beacon.Name = "GhostBeacon"
    beacon.Color = Color3.fromRGB(120, 210, 255)
    beacon.Brightness = 1.8
    beacon.Range = 80
    beacon.Shadows = false
    beacon.Parent = head

    local mist = Instance.new("ParticleEmitter")
    mist.Name = "GhostMist"
    mist.Color = ColorSequence.new(Color3.fromRGB(205, 245, 255), Color3.fromRGB(90, 170, 255))
    mist.LightEmission = 0.88
    mist.Rate = 32
    mist.Lifetime = NumberRange.new(2.0, 4.0)
    mist.Speed = NumberRange.new(0.5, 1.8)
    mist.SpreadAngle = Vector2.new(40, 90)
    mist.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.20),
        NumberSequenceKeypoint.new(0.55, 0.60),
        NumberSequenceKeypoint.new(1, 1),
    })
    mist.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.0),
        NumberSequenceKeypoint.new(1, 5.5),
    })
    mist.Parent = root

    addLabelBillboard(root, "도서관 귀신", Color3.fromRGB(160, 240, 255))

    return ghost
end

local function startGhostBrain(ghost)
    local waypointIndex = 1
    local scareCooldowns = {}
    local bornAt = os.clock()
    local sharedPath = { waypoints = {}, wpIndex = 1 }
    local lastPathAt = 0

    RunService.Heartbeat:Connect(function(deltaTime)
        if not ghost.Parent or not ghost.PrimaryPart then
            return
        end

        local root = ghost.PrimaryPart
        local pos = root.Position
        local destination = GameConfig.Ghost.Waypoints[waypointIndex]
        local baseY = GameConfig.Ghost.MoveY
        local floatingY = baseY + math.sin((os.clock() - bornAt) * 2.4) * 0.75
        local flatDistance = (Vector3.new(destination.X, baseY, destination.Z) - Vector3.new(pos.X, baseY, pos.Z)).Magnitude

        if flatDistance < 2 then
            waypointIndex = waypointIndex % #GameConfig.Ghost.Waypoints + 1
            sharedPath.waypoints = {}
            sharedPath.wpIndex = 1
            destination = GameConfig.Ghost.Waypoints[waypointIndex]
        end

        if #sharedPath.waypoints == 0 or sharedPath.wpIndex > #sharedPath.waypoints or os.clock() - lastPathAt > 1.5 then
            lastPathAt = os.clock()
            local path = PathfindingService:CreatePath({
                AgentRadius = 2.5,
                AgentHeight = 6.5,
                AgentCanJump = false,
                AgentCanClimb = false,
            })

            local ok = pcall(function()
                path:ComputeAsync(Vector3.new(pos.X, baseY, pos.Z), Vector3.new(destination.X, baseY, destination.Z))
            end)

            if ok and path.Status == Enum.PathStatus.Success then
                local wps = path:GetWaypoints()
                if #wps > 1 then
                    sharedPath.waypoints = wps
                    sharedPath.wpIndex = 2
                end
            end
        end

        local waypoint = sharedPath.waypoints[sharedPath.wpIndex]
        if waypoint then
            local target = Vector3.new(waypoint.Position.X, floatingY, waypoint.Position.Z)
            local currentFlat = Vector3.new(pos.X, floatingY, pos.Z)
            local offset = target - currentFlat
            if offset.Magnitude < 1.6 then
                sharedPath.wpIndex += 1
            elseif offset.Magnitude >= 0.1 then
                local step = math.min(GameConfig.Ghost.FloatSpeed * deltaTime, offset.Magnitude)
                local nextPos = currentFlat + offset.Unit * step
                if not hasClearMovementSegment(pos, nextPos, ghost) then
                    sharedPath.waypoints = {}
                    sharedPath.wpIndex = 1
                    return
                end
                ghost:PivotTo(CFrame.lookAt(nextPos, Vector3.new(target.X, nextPos.Y, target.Z)))
            end
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if not wonPlayers[player] then
                local character = player.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                if rootPart
                    and (rootPart.Position - ghost.PrimaryPart.Position).Magnitude <= GameConfig.Ghost.ScareRange
                    and hasClearLineOfSight(ghost.PrimaryPart.Position, rootPart)
                then
                    local lastScare = scareCooldowns[player] or 0
                    if os.clock() - lastScare >= GameConfig.Ghost.ScareCooldown then
                        scareCooldowns[player] = os.clock()
                        player:SetAttribute("NoisyUntil", os.clock() + 3)
                        fireMessage(player, "Info", GameConfig.Messages.GhostNear)
                    end
                end
            end
        end
    end)
end

local function teleportToSpawn(player)
    if wonPlayers[player] then return end

    local character = player.Character
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        character:PivotTo(CFrame.new(GameConfig.Spawn.Position + Vector3.new(0, 3, 0)))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function getNearestPlayer(position, currentTarget)
    local bestPlayer = nil
    local bestDistance = math.huge
    local range = currentTarget and GameConfig.Monster.LoseRange or GameConfig.Monster.DetectionRange

    for _, player in ipairs(Players:GetPlayers()) do
        if wonPlayers[player] then continue end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 and not isPlayerHidden(player) then
            local distance = (root.Position - position).Magnitude
            local isNoisy = (player:GetAttribute("NoisyUntil") or 0) > os.clock()
            local effectiveRange = range
            if isNoisy then
                effectiveRange = math.max(effectiveRange, 72)
            end

            local canDetect = isNoisy or hasClearLineOfSight(position + Vector3.new(0, 2, 0), root)
            if canDetect and distance < effectiveRange and distance < bestDistance then
                bestPlayer = player
                bestDistance = distance
            end
        end
    end

    return bestPlayer, bestDistance
end

-- 손전등이 괴물 방향을 비추고 있는지 서버에서 판정
local function isFlashlightBlinding(monsterPosition)
    for _, player in ipairs(Players:GetPlayers()) do
        if wonPlayers[player] then continue end
        if not player:GetAttribute("HasFlashlight") or not player:GetAttribute("FlashlightActive") then continue end

        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not head or not root then continue end

        local toMonster = monsterPosition - head.Position
        local dist = toMonster.Magnitude
        if dist > 45 then continue end  -- 손전등 유효 사거리

        local dot = root.CFrame.LookVector:Dot(toMonster.Unit)
        if dot > 0.68 and hasClearLineOfSight(head.Position, monsterModel and monsterModel.PrimaryPart, { character }) then
            return true, player
        end
        end
    end
    return false, nil
end

local function startMonsterBrain(monster)
    local patrolIndex = 1
    local sharedPath = { waypoints = {}, wpIndex = 1 }
    local targetPlayer = nil
    local catchCooldowns = {}
    local isChasing = false
    local flashlightNotified = {}

    local function catchPlayer(player)
        if wonPlayers[player] then return end

        local now = os.clock()
        if catchCooldowns[player] and now - catchCooldowns[player] < GameConfig.Monster.CatchCooldown then
            return
        end

        catchCooldowns[player] = now
        if isPlayerHidden(player) then
            fireMessage(player, "Info", GameConfig.Messages.Hidden)
            return
        end

        local shieldCount = player:GetAttribute("ShieldCount") or 0
        if shieldCount > 0 then
            setPlayerAttributeNumber(player, "ShieldCount", shieldCount - 1)
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and monster.PrimaryPart then
                local away = root.Position - monster.PrimaryPart.Position
                if away.Magnitude < 0.1 then
                    away = Vector3.new(1, 0, 0)
                end
                character:PivotTo(CFrame.new(root.Position + away.Unit * 14 + Vector3.new(0, 1, 0)))
                root.AssemblyLinearVelocity = away.Unit * 35
            end
            fireMessage(player, "Info", GameConfig.Messages.ShieldUsed)
            return
        end

        teleportToSpawn(player)
        gameEvent:FireClient(player, "Caught", GameConfig.Messages.Caught)
    end

    monster.PrimaryPart.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player then
            local targetRoot = character:FindFirstChild("HumanoidRootPart")
            if targetRoot and monster.PrimaryPart and hasClearLineOfSight(monster.PrimaryPart.Position, targetRoot) then
                catchPlayer(player)
            end
        end
    end)

    -- 경로 계산 루프: yield가 필요하므로 별도 태스크에서 실행
    task.spawn(function()
        while monster.Parent do
            local root = monster.PrimaryPart
            if root then
                local from = root.Position
                local to

                if isChasing and targetPlayer then
                    local char = targetPlayer.Character
                    local playerRoot = char and char:FindFirstChild("HumanoidRootPart")
                    if playerRoot then
                        to = playerRoot.Position
                    end
                end

                if not to then
                    to = GameConfig.Monster.Waypoints[patrolIndex]
                end

                local path = PathfindingService:CreatePath({
                    AgentRadius = 2.5,
                    AgentHeight = 6.5,
                    AgentCanJump = false,
                    AgentCanClimb = false,
                })

                local ok = pcall(function()
                    path:ComputeAsync(from, to)
                end)

                if ok and path.Status == Enum.PathStatus.Success then
                    local wps = path:GetWaypoints()
                    if #wps > 1 then
                        sharedPath.waypoints = wps
                        sharedPath.wpIndex = 2
                    end
                end
            end

            task.wait(isChasing and GameConfig.Monster.PathRecomputeChaseInterval or GameConfig.Monster.PathRecomputePatrolInterval)
        end
    end)

    -- 이동 루프: 매 프레임 실행
    RunService.Heartbeat:Connect(function(dt)
        if not monster.Parent or not monster.PrimaryPart then return end

        local pos = monster.PrimaryPart.Position
        local nearPlayer, dist = getNearestPlayer(pos, targetPlayer)

        -- 상태 전환 시 경로 초기화
        if nearPlayer ~= targetPlayer then
            targetPlayer = nearPlayer
            isChasing = nearPlayer ~= nil
            sharedPath.waypoints = {}
            sharedPath.wpIndex = 1
        end

        -- 추격 범위 내 잡기 시도
        if isChasing and dist <= GameConfig.Monster.CatchRange and targetPlayer and targetPlayer.Character then
            local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and hasClearLineOfSight(pos + Vector3.new(0, 2, 0), targetRoot) then
                catchPlayer(targetPlayer)
            end
        end

        -- 손전등 눈부심 판정
        local blinded, blindingPlayer = isFlashlightBlinding(pos)
        local speed
        if blinded then
            speed = GameConfig.Monster.FlashlightSlowSpeed
            if blindingPlayer and not flashlightNotified[blindingPlayer] then
                flashlightNotified[blindingPlayer] = true
                fireMessage(blindingPlayer, "Info", GameConfig.Messages.FlashlightBlock)
                task.delay(3, function()
                    flashlightNotified[blindingPlayer] = nil
                end)
            end
        elseif isChasing then
            speed = GameConfig.Monster.ChaseSpeed + (gameState.exitOpen and GameConfig.Monster.FinalChaseBonusChaseSpeed or 0)
        else
            speed = GameConfig.Monster.PatrolSpeed + (gameState.exitOpen and GameConfig.Monster.FinalChaseBonusPatrolSpeed or 0)
        end

        -- 경보등 밝기: 추격 중 더 밝게
        local alertLight = monster.PrimaryPart:FindFirstChild("AlertGlow")
        if alertLight then
            alertLight.Brightness = isChasing and 2.4 or 0.6
        end

        -- 경로 추적
        local waypoints = sharedPath.waypoints
        local wpIndex = sharedPath.wpIndex

        if #waypoints == 0 or wpIndex > #waypoints then
            -- Pathfinding이 준비되지 않았거나 실패했으면 직선 이동하지 않는다.
            -- PivotTo 직선 이동은 벽을 통과할 수 있으므로, 유효한 경로가 있을 때만 움직인다.
            return
        end

        local wpPos = waypoints[wpIndex].Position
        local Y = GameConfig.Monster.MoveY
        local flat = Vector3.new(wpPos.X, Y, wpPos.Z)
        local currentFlat = Vector3.new(pos.X, Y, pos.Z)
        local offset = flat - currentFlat

        if offset.Magnitude < 2 then
            sharedPath.wpIndex = wpIndex + 1

            -- 마지막 순찰 웨이포인트 도착 시 다음으로
            if not isChasing and sharedPath.wpIndex > #waypoints then
                patrolIndex = patrolIndex % #GameConfig.Monster.Waypoints + 1
                sharedPath.waypoints = {}
                sharedPath.wpIndex = 1
            end
            return
        end

        local step = math.min(speed * dt, offset.Magnitude)
        local nextPos = currentFlat + offset.Unit * step
        nextPos = Vector3.new(nextPos.X, Y, nextPos.Z)
        if not hasClearMovementSegment(pos, nextPos, monster) then
            sharedPath.waypoints = {}
            sharedPath.wpIndex = 1
            return
        end
        monster:PivotTo(CFrame.lookAt(nextPos, Vector3.new(flat.X, nextPos.Y, flat.Z)))
    end)
end

createSpawnAndExit()
createObjectivesAndItems()
local monster = createMonster()
startMonsterBrain(monster)
local ghost = createGhost()
startGhostBrain(ghost)

task.spawn(function()
    task.wait(GameConfig.Rain.InitialClearDuration)
    while true do
        setRainActive(true)
        while rainState.active do
            local delaySeconds = math.random(GameConfig.Rain.LightningMinDelay, GameConfig.Rain.LightningMaxDelay)
            task.wait(math.min(delaySeconds, math.max(0, rainState.endsAt - os.clock())))
            if rainState.active and os.clock() < rainState.endsAt then
                triggerLightning()
            end
            if os.clock() >= rainState.endsAt then
                break
            end
        end
        setRainActive(false)
        task.wait(GameConfig.Rain.ClearDuration)
    end
end)

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("HasFlashlight", false)
    player:SetAttribute("FlashlightActive", false)
    player:SetAttribute("ShieldCount", 0)
    player:SetAttribute("IsHidden", false)
    player:SetAttribute("HasEscaped", false)
    sendRainState(player)

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = GameConfig.Player.DefaultWalkSpeed
        end
        gameEvent:FireClient(player, "Objective", GameConfig.Messages.Objective)
        broadcastProgress()
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    wonPlayers[player] = nil
end)
