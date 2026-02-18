--[[
    FIX IT UP - REALISTIC HUMAN PLAYER SCRIPT
    Spielt wie ein echter Mensch - KEINE TELEPORTS!
    
    Features:
    - FÄHRT zu Locations (kein Teleport)
    - Klickt Teile manuell an
    - Zieht Teile realistisch
    - Sucht Autos im Junkyard
    - Wartet realistisch zwischen Aktionen
    
    Deutscher Support - Made for realistic gameplay
]]

-- ========================================
-- EINSTELLUNGEN / SETTINGS
-- ========================================
getgenv().RealisticSettings = getgenv().RealisticSettings or {
    -- Hauptfunktionen
    AutoFarmEnabled = false,
    
    -- Fahr-Einstellungen
    DriveSpeed = 50, -- Geschwindigkeit beim Fahren (50 = normal)
    UseRoads = true, -- Versucht Straßen zu benutzen
    
    -- Zeitverzögerungen (in Sekunden)
    WaitAfterBuy = 3, -- Wartet nach Kauf
    WaitAfterRepair = 1, -- Wartet nach jeder Reparatur
    WaitAfterPaint = 4, -- Wartet nach Lackierung
    WaitBeforeSell = 2, -- Wartet vor Verkauf
    
    -- Sucheinstellungen
    MaxCarPrice = 50000, -- Maximaler Preis für Auto
    PreferRare = false, -- Bevorzugt seltene Autos
    
    -- Reparatur-Einstellungen
    CleanParts = true, -- Reinigt Teile
    ReplaceSparks = true, -- Ersetzt Zündkerzen
    ReplaceInjectors = true, -- Ersetzt Injektoren
    
    -- Sicherheit
    RandomDelays = true, -- Fügt zufällige Verzögerungen hinzu
    LookAround = true, -- Bewegt Kamera wie echter Spieler
}

local Settings = getgenv().RealisticSettings

-- ========================================
-- SERVICES & VARIABLEN
-- ========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local CurrentCar = nil
local CurrentSeat = nil
local TotalProfit = 0
local CarsFixed = 0
local IsProcessing = false

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

local function Notify(text)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Fix It Up Realistisch",
        Text = text,
        Duration = 3,
    })
end

local function RandomWait(min, max)
    if Settings.RandomDelays then
        local time = math.random(min * 100, max * 100) / 100
        task.wait(time)
    else
        task.wait(min)
    end
end

local function MoveCameraToLook(target)
    if not Settings.LookAround then return end
    
    local Camera = workspace.CurrentCamera
    if Camera and target then
        local lookCFrame = CFrame.new(Camera.CFrame.Position, target)
        
        local tween = TweenService:Create(
            Camera,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingStyle.Out),
            {CFrame = lookCFrame}
        )
        tween:Play()
        task.wait(0.5)
    end
end

-- ========================================
-- AUTO FINDEN / FIND CARS
-- ========================================

local function FindCarsInJunkyard()
    local junkyard = Workspace:FindFirstChild("Junkyard") or Workspace:FindFirstChild("JunkyardCars")
    if not junkyard then
        print("[DEBUG] Kein Junkyard gefunden!")
        return {}
    end
    
    local availableCars = {}
    
    for _, car in pairs(junkyard:GetDescendants()) do
        -- Sucht nach Autos (Models mit VehicleSeat)
        if car:IsA("Model") then
            local seat = car:FindFirstChild("VehicleSeat", true)
            local price = car:FindFirstChild("Price") or car:FindFirstChild("Value")
            
            if seat and price then
                table.insert(availableCars, {
                    Car = car,
                    Price = price.Value or 0,
                    Seat = seat,
                    Rarity = car:FindFirstChild("Rarity") and car.Rarity.Value or 1
                })
            end
        end
    end
    
    print("[DEBUG] Gefunden: " .. #availableCars .. " Autos im Junkyard")
    return availableCars
end

local function FindBestCarInJunkyard()
    local cars = FindCarsInJunkyard()
    
    if #cars == 0 then
        return nil
    end
    
    -- Sortiere nach Preis oder Seltenheit
    table.sort(cars, function(a, b)
        if Settings.PreferRare then
            return a.Rarity > b.Rarity
        else
            return a.Price < b.Price
        end
    end)
    
    -- Finde erstes Auto unter Max-Preis
    for _, carData in ipairs(cars) do
        if carData.Price <= Settings.MaxCarPrice then
            print("[DEBUG] Bestes Auto: " .. carData.Car.Name .. " für €" .. carData.Price)
            return carData
        end
    end
    
    return nil
end

-- ========================================
-- FAHREN / DRIVING
-- ========================================

local function GetInCar(vehicleSeat)
    if not vehicleSeat then return false end
    
    print("[DEBUG] Versuche ins Auto zu steigen...")
    
    -- Gehe zum Auto
    local attempts = 0
    while (HumanoidRootPart.Position - vehicleSeat.Position).Magnitude > 10 and attempts < 30 do
        Humanoid:MoveTo(vehicleSeat.Position)
        task.wait(0.5)
        attempts = attempts + 1
    end
    
    if attempts >= 30 then
        print("[DEBUG] Konnte Auto nicht erreichen!")
        return false
    end
    
    -- Setze dich ins Auto
    task.wait(0.5)
    vehicleSeat:Sit(Humanoid)
    task.wait(1)
    
    if Humanoid.Sit then
        print("[DEBUG] Erfolgreich ins Auto gestiegen!")
        CurrentSeat = vehicleSeat
        return true
    end
    
    return false
end

local function DriveTo(targetPosition, speed)
    speed = speed or Settings.DriveSpeed
    
    if not CurrentSeat then
        print("[DEBUG] Nicht im Auto!")
        return false
    end
    
    print("[DEBUG] Fahre zu Ziel...")
    
    local car = CurrentSeat.Parent
    if not car or not car.PrimaryPart then return false end
    
    local driving = true
    local timeout = tick() + 120 -- 2 Minuten Timeout
    
    while driving and tick() < timeout do
        local distance = (car.PrimaryPart.Position - targetPosition).Magnitude
        
        if distance < 20 then
            -- Angekommen!
            CurrentSeat.ThrottleFloat = 0
            CurrentSeat.SteerFloat = 0
            print("[DEBUG] Ziel erreicht!")
            break
        end
        
        -- Berechne Richtung
        local direction = (targetPosition - car.PrimaryPart.Position).Unit
        local carDirection = car.PrimaryPart.CFrame.LookVector
        
        -- Steuere
        local angle = math.acos(direction:Dot(carDirection))
        local cross = carDirection:Cross(direction).Y
        
        -- Gas geben
        CurrentSeat.ThrottleFloat = 1
        
        -- Lenken
        if math.abs(angle) > 0.1 then
            if cross > 0 then
                CurrentSeat.SteerFloat = 1
            else
                CurrentSeat.SteerFloat = -1
            end
        else
            CurrentSeat.SteerFloat = 0
        end
        
        task.wait(0.1)
    end
    
    -- Stoppe Auto
    CurrentSeat.ThrottleFloat = 0
    CurrentSeat.SteerFloat = 0
    task.wait(0.5)
    
    return true
end

local function GetOutOfCar()
    if CurrentSeat then
        print("[DEBUG] Steige aus Auto aus...")
        Humanoid.Jump = true
        task.wait(0.5)
        CurrentSeat = nil
    end
end

-- ========================================
-- KAUFEN / BUYING
-- ========================================

local function WalkToPosition(position)
    print("[DEBUG] Gehe zu Position...")
    
    Humanoid:MoveTo(position)
    
    local timeout = tick() + 30
    while (HumanoidRootPart.Position - position).Magnitude > 5 and tick() < timeout do
        task.wait(0.5)
    end
    
    return (HumanoidRootPart.Position - position).Magnitude < 10
end

local function BuyCar(carData)
    if not carData then return false end
    
    local car = carData.Car
    local price = carData.Price
    
    Notify("Kaufe: " .. car.Name .. " für €" .. price)
    print("[DEBUG] Starte Kaufprozess...")
    
    -- Gehe zum Auto
    local buyPosition = car.PrimaryPart and car.PrimaryPart.Position or car:GetModelCFrame().Position
    
    if not WalkToPosition(buyPosition) then
        print("[DEBUG] Konnte Auto nicht erreichen!")
        return false
    end
    
    RandomWait(1, 2)
    
    -- Suche Kaufbutton oder Prompt
    local buyPrompt = car:FindFirstChild("ProximityPrompt", true)
    if buyPrompt then
        print("[DEBUG] Drücke Kaufbutton...")
        fireproximityprompt(buyPrompt)
        task.wait(Settings.WaitAfterBuy)
        return true
    end
    
    -- Alternative: Suche nach RemoteEvent
    local buyEvent = ReplicatedStorage:FindFirstChild("PurchaseCar") or 
                     ReplicatedStorage:FindFirstChild("BuyCar") or
                     ReplicatedStorage:FindFirstChild("PurchaseVehicle")
    
    if buyEvent then
        print("[DEBUG] Sende Kaufanfrage...")
        buyEvent:FireServer(car)
        task.wait(Settings.WaitAfterBuy)
        return true
    end
    
    print("[DEBUG] Keine Kaufmethode gefunden!")
    return false
end

-- ========================================
-- REPARIEREN / REPAIRING
-- ========================================

local function GetOwnedCar()
    -- Suche nach unserem Auto in Garage
    local garage = Workspace:FindFirstChild("Garage") or 
                   Workspace:FindFirstChild("PlayerCars") or
                   Workspace:FindFirstChild("OwnedCars")
    
    if not garage then
        print("[DEBUG] Keine Garage gefunden!")
        return nil
    end
    
    for _, car in pairs(garage:GetChildren()) do
        if car:IsA("Model") then
            local owner = car:FindFirstChild("Owner")
            if owner and owner.Value == Player then
                print("[DEBUG] Eigenes Auto gefunden: " .. car.Name)
                return car
            end
        end
    end
    
    -- Alternative: Suche in Workspace direkt
    for _, car in pairs(Workspace:GetChildren()) do
        if car:IsA("Model") and car:FindFirstChild("Owner") then
            if car.Owner.Value == Player then
                return car
            end
        end
    end
    
    return nil
end

local function ClickPart(part)
    if not part then return false end
    
    print("[DEBUG] Klicke auf Teil: " .. part.Name)
    
    -- Bewege Kamera zum Teil
    MoveCameraToLook(part.Position)
    
    -- Gehe zum Teil
    if (HumanoidRootPart.Position - part.Position).Magnitude > 10 then
        WalkToPosition(part.Position)
    end
    
    RandomWait(0.3, 0.7)
    
    -- Klicke auf Teil (simuliere Mausklick)
    local clickDetector = part:FindFirstChild("ClickDetector")
    if clickDetector then
        fireclickdetector(clickDetector)
        RandomWait(0.2, 0.5)
        return true
    end
    
    -- Alternative: ProximityPrompt
    local prompt = part:FindFirstChild("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
        RandomWait(0.2, 0.5)
        return true
    end
    
    return false
end

local function RepairEnginePart(part)
    print("[DEBUG] Repariere Motorteil: " .. part.Name)
    
    -- 1. Klicke auf Teil
    ClickPart(part)
    RandomWait(0.5, 1)
    
    -- 2. Prüfe ob Teil entfernt werden muss
    if part.Name:find("Spark") or part.Name:find("Injector") then
        print("[DEBUG] Teil muss ersetzt werden")
        
        -- Entferne altes Teil
        local removeEvent = ReplicatedStorage:FindFirstChild("RemovePart")
        if removeEvent then
            removeEvent:FireServer(part)
            RandomWait(0.5, 1)
        end
        
        -- Kaufe neues Teil
        if Settings.ReplaceSparks or Settings.ReplaceInjectors then
            local buyPartEvent = ReplicatedStorage:FindFirstChild("BuyPart")
            if buyPartEvent then
                buyPartEvent:FireServer(part.Name)
                RandomWait(0.5, 1)
            end
        end
        
        return true
    end
    
    -- 3. Reinige Teil
    if Settings.CleanParts then
        print("[DEBUG] Reinige Teil...")
        
        -- Suche Waschmaschine
        local washMachine = Workspace:FindFirstChild("WashingMachine") or
                           Workspace:FindFirstChild("PartWasher")
        
        if washMachine then
            WalkToPosition(washMachine.Position)
            ClickPart(washMachine)
            RandomWait(2, 3)
        end
    end
    
    -- 4. Repariere Teil
    local repairEvent = ReplicatedStorage:FindFirstChild("RepairPart") or
                        ReplicatedStorage:FindFirstChild("FixPart")
    
    if repairEvent then
        print("[DEBUG] Sende Reparatur-Event...")
        repairEvent:FireServer(part)
        RandomWait(Settings.WaitAfterRepair, Settings.WaitAfterRepair + 0.5)
    end
    
    return true
end

local function RepairCar(car)
    if not car then return false end
    
    Notify("Starte Reparatur von " .. car.Name)
    print("[DEBUG] === REPARATUR START ===")
    IsProcessing = true
    
    -- Gehe zum Auto
    local carPosition = car.PrimaryPart and car.PrimaryPart.Position or car:GetModelCFrame().Position
    WalkToPosition(carPosition)
    RandomWait(1, 2)
    
    -- 1. Öffne Motorhaube
    local hood = car:FindFirstChild("Hood") or car:FindFirstChild("Bonnet")
    if hood then
        print("[DEBUG] Öffne Motorhaube...")
        ClickPart(hood)
        RandomWait(1, 2)
    end
    
    -- 2. Finde alle kaputten Teile
    local brokenParts = {}
    
    -- Suche im Motor
    local engine = car:FindFirstChild("Engine")
    if engine then
        for _, part in pairs(engine:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Model") then
                -- Prüfe ob kaputt
                local damaged = part:FindFirstChild("Damaged") or part:FindFirstChild("Broken")
                if damaged and damaged.Value == true then
                    table.insert(brokenParts, part)
                end
                
                -- Oder: Condition unter 100%
                local condition = part:FindFirstChild("Condition")
                if condition and condition.Value < 100 then
                    table.insert(brokenParts, part)
                end
            end
        end
    end
    
    -- Suche am ganzen Auto
    for _, part in pairs(car:GetDescendants()) do
        if part:IsA("BasePart") then
            local damaged = part:FindFirstChild("Damaged")
            if damaged and damaged.Value == true then
                if not table.find(brokenParts, part) then
                    table.insert(brokenParts, part)
                end
            end
        end
    end
    
    print("[DEBUG] Gefunden: " .. #brokenParts .. " kaputte Teile")
    Notify("Repariere " .. #brokenParts .. " Teile...")
    
    -- 3. Repariere alle Teile
    for i, part in ipairs(brokenParts) do
        print("[DEBUG] [" .. i .. "/" .. #brokenParts .. "] Repariere: " .. part.Name)
        RepairEnginePart(part)
        
        if i % 5 == 0 then
            Notify(string.format("Fortschritt: %d/%d", i, #brokenParts))
        end
    end
    
    -- 4. Schließe Motorhaube
    if hood then
        print("[DEBUG] Schließe Motorhaube...")
        ClickPart(hood)
        RandomWait(0.5, 1)
    end
    
    IsProcessing = false
    print("[DEBUG] === REPARATUR FERTIG ===")
    Notify("Reparatur abgeschlossen!")
    return true
end

-- ========================================
-- LACKIEREN / PAINTING
-- ========================================

local function PaintCar(car)
    if not car then return false end
    
    Notify("Fahre zur Lackiererei...")
    print("[DEBUG] Starte Lackierung...")
    
    -- Steige ins Auto
    local seat = car:FindFirstChild("VehicleSeat", true)
    if not seat then
        print("[DEBUG] Kein Sitz gefunden!")
        return false
    end
    
    GetInCar(seat)
    RandomWait(1, 2)
    
    -- Fahre zur Lackiererei
    local paintShop = Workspace:FindFirstChild("PaintShop") or
                      Workspace:FindFirstChild("SprayShop")
    
    if paintShop then
        local paintPosition = paintShop:FindFirstChild("PaintZone") or paintShop.PrimaryPart
        if paintPosition then
            DriveTo(paintPosition.Position, 40)
        end
    end
    
    GetOutOfCar()
    RandomWait(1, 2)
    
    -- Lackiere Auto
    local paintEvent = ReplicatedStorage:FindFirstChild("PaintCar") or
                       ReplicatedStorage:FindFirstChild("PaintVehicle")
    
    if paintEvent then
        local colors = {"Metallic Black", "Metallic Red", "Metallic Blue", "Metallic Silver"}
        local randomColor = colors[math.random(1, #colors)]
        
        print("[DEBUG] Lackiere Auto: " .. randomColor)
        paintEvent:FireServer(car, randomColor)
        task.wait(Settings.WaitAfterPaint)
        Notify("Lackierung fertig!")
        return true
    end
    
    return false
end

-- ========================================
-- VERKAUFEN / SELLING
-- ========================================

local function SellCar(car)
    if not car then return false end
    
    Notify("Fahre zum Verkaufsstand...")
    print("[DEBUG] Starte Verkaufsprozess...")
    
    -- Steige ins Auto
    local seat = car:FindFirstChild("VehicleSeat", true)
    if seat then
        GetInCar(seat)
        RandomWait(1, 2)
        
        -- Fahre zu Auktionshaus/Verkaufsstand
        local auctionHouse = Workspace:FindFirstChild("AuctionHouse") or
                            Workspace:FindFirstChild("SellZone") or
                            Workspace:FindFirstChild("Dealership")
        
        if auctionHouse then
            local sellPosition = auctionHouse:FindFirstChild("SellPoint") or auctionHouse.PrimaryPart
            if sellPosition then
                DriveTo(sellPosition.Position, 40)
            end
        end
        
        GetOutOfCar()
    end
    
    RandomWait(Settings.WaitBeforeSell, Settings.WaitBeforeSell + 1)
    
    -- Verkaufe Auto
    local sellEvent = ReplicatedStorage:FindFirstChild("SellCar") or
                      ReplicatedStorage:FindFirstChild("SellVehicle")
    
    if sellEvent then
        print("[DEBUG] Verkaufe Auto...")
        
        local value = car:FindFirstChild("Value") or car:FindFirstChild("Price")
        local soldFor = value and value.Value or 0
        
        sellEvent:FireServer(car)
        
        CarsFixed = CarsFixed + 1
        TotalProfit = TotalProfit + soldFor
        
        Notify(string.format("Verkauft für €%d! Total: €%d", soldFor, TotalProfit))
        task.wait(2)
        return true
    end
    
    return false
end

-- ========================================
-- HAUPT-LOOP / MAIN LOOP
-- ========================================

local function MainLoop()
    while Settings.AutoFarmEnabled do
        if IsProcessing then
            task.wait(1)
            continue
        end
        
        Notify("Suche neues Auto...")
        print("[DEBUG] === NEUER DURCHLAUF ===")
        
        -- 1. Fahre zum Junkyard
        print("[DEBUG] Gehe zum Junkyard...")
        local junkyard = Workspace:FindFirstChild("Junkyard")
        if junkyard then
            WalkToPosition(junkyard.Position)
        end
        RandomWait(2, 3)
        
        -- 2. Finde und kaufe Auto
        local carData = FindBestCarInJunkyard()
        
        if not carData then
            Notify("Keine Autos gefunden! Warte...")
            task.wait(15)
            continue
        end
        
        local success = BuyCar(carData)
        
        if not success then
            Notify("Kauf fehlgeschlagen!")
            task.wait(5)
            continue
        end
        
        RandomWait(2, 3)
        
        -- 3. Hole gekauftes Auto
        CurrentCar = GetOwnedCar()
        
        if not CurrentCar then
            Notify("Auto nicht gefunden!")
            task.wait(5)
            continue
        end
        
        -- 4. Fahre Auto zur Garage
        print("[DEBUG] Fahre zur Garage...")
        local seat = CurrentCar:FindFirstChild("VehicleSeat", true)
        if seat then
            GetInCar(seat)
            RandomWait(1, 2)
            
            local garage = Workspace:FindFirstChild("Garage") or Workspace:FindFirstChild("Workshop")
            if garage then
                DriveTo(garage.Position, 50)
            end
            
            GetOutOfCar()
        end
        
        RandomWait(2, 3)
        
        -- 5. Repariere Auto
        RepairCar(CurrentCar)
        RandomWait(2, 3)
        
        -- 6. Lackiere Auto (optional)
        if Settings.AutoPaint then
            PaintCar(CurrentCar)
            RandomWait(2, 3)
        end
        
        -- 7. Verkaufe Auto
        SellCar(CurrentCar)
        
        CurrentCar = nil
        
        print("[DEBUG] === DURCHLAUF BEENDET ===")
        RandomWait(3, 5)
    end
end

-- ========================================
-- GUI
-- ========================================

local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FixItUpRealistic"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = Player.PlayerGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 350, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame
    
    -- Titel
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Title.Text = "🔧 FIX IT UP REALISTISCH"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 18
    Title.Font = Enum.Font.SourceSansBold
    Title.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    -- Status Text
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 60)
    Status.Position = UDim2.new(0, 10, 0, 60)
    Status.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Status.Text = "Status: Bereit"
    Status.TextColor3 = Color3.fromRGB(100, 255, 100)
    Status.TextSize = 16
    Status.Font = Enum.Font.SourceSans
    Status.Parent = MainFrame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 8)
    StatusCorner.Parent = Status
    
    -- Start Button
    local StartBtn = Instance.new("TextButton")
    StartBtn.Size = UDim2.new(1, -20, 0, 50)
    StartBtn.Position = UDim2.new(0, 10, 0, 130)
    StartBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    StartBtn.Text = "▶ START AUTO FARM"
    StartBtn.TextColor3 = Color3.new(1, 1, 1)
    StartBtn.TextSize = 18
    StartBtn.Font = Enum.Font.SourceSansBold
    StartBtn.Parent = MainFrame
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 8)
    BtnCorner.Parent = StartBtn
    
    StartBtn.MouseButton1Click:Connect(function()
        Settings.AutoFarmEnabled = not Settings.AutoFarmEnabled
        
        if Settings.AutoFarmEnabled then
            StartBtn.Text = "⏸ STOP AUTO FARM"
            StartBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
            Status.Text = "Status: Läuft..."
            Status.TextColor3 = Color3.fromRGB(255, 200, 50)
            task.spawn(MainLoop)
        else
            StartBtn.Text = "▶ START AUTO FARM"
            StartBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            Status.Text = "Status: Gestoppt"
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    
    -- Stats
    local Stats = Instance.new("TextLabel")
    Stats.Size = UDim2.new(1, -20, 0, 120)
    Stats.Position = UDim2.new(0, 10, 0, 190)
    Stats.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Stats.Text = "═══ STATISTIK ═══\nAutos: 0\nGewinn: €0"
    Stats.TextColor3 = Color3.new(1, 1, 1)
    Stats.TextSize = 16
    Stats.Font = Enum.Font.SourceSans
    Stats.TextYAlignment = Enum.TextYAlignment.Top
    Stats.Parent = MainFrame
    
    local StatsCorner = Instance.new("UICorner")
    StatsCorner.CornerRadius = UDim.new(0, 8)
    StatsCorner.Parent = Stats
    
    -- Info
    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.new(1, -20, 0, 70)
    Info.Position = UDim2.new(0, 10, 0, 320)
    Info.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Info.Text = "🚗 Fährt realistisch\n🔧 Keine Teleports\n✋ Klickt manuell"
    Info.TextColor3 = Color3.fromRGB(150, 150, 150)
    Info.TextSize = 14
    Info.Font = Enum.Font.SourceSans
    Info.Parent = MainFrame
    
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 8)
    InfoCorner.Parent = Info
    
    -- Update Stats
    task.spawn(function()
        while ScreenGui.Parent do
            Stats.Text = string.format(
                "═══ STATISTIK ═══\nAutos repariert: %d\nGesamtgewinn: €%d\nØ Gewinn: €%d",
                CarsFixed,
                TotalProfit,
                CarsFixed > 0 and math.floor(TotalProfit / CarsFixed) or 0
            )
            
            if Settings.AutoFarmEnabled and IsProcessing then
                Status.Text = "Status: Repariert..."
                Status.TextColor3 = Color3.fromRGB(255, 200, 50)
            elseif Settings.AutoFarmEnabled then
                Status.Text = "Status: Sucht Auto..."
                Status.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
            
            task.wait(1)
        end
    end)
    
    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.TextSize = 18
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.Parent = Title
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseButton1Click:Connect(function()
        Settings.AutoFarmEnabled = false
        ScreenGui:Destroy()
    end)
    
    Notify("Script geladen! Drücke START")
end

-- ========================================
-- INITIALISIERUNG
-- ========================================

print("═══════════════════════════════════")
print("FIX IT UP - REALISTISCHER SCRIPT")
print("Made in Germany 🇩🇪")
print("═══════════════════════════════════")
print("Features:")
print("✓ Fährt wie echter Spieler")
print("✓ KEINE Teleports")
print("✓ Klickt Teile manuell")
print("✓ Realistische Wartezeiten")
print("═══════════════════════════════════")

CreateGUI()
Notify("Realistischer Script geladen!")

-- Anti-AFK
task.spawn(function()
    while true do
        for _, connection in pairs(getconnections(Player.Idled)) do
            connection:Disable()
        end
        task.wait(60)
    end
end)
