--[[
    ╔═══════════════════════════════════════════╗
    ║    FIX IT UP - REALISTISCHER SCRIPT       ║
    ║    Fährt • 160s Wartezeit • Findet Autos  ║
    ╚═══════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════
-- EINSTELLUNGEN
-- ═══════════════════════════════════════════════════════
local Settings = {
    MaxCarPrice = 999999, -- Maximaler Preis
    WaitTime = 160, -- MUSS 160 Sekunden warten!
    RepairSpeed = "Normal", -- Normal, Fast, Slow
    DriveSpeed = 45, -- Fahrgeschwindigkeit
    AutoPaint = true, -- Automatisch lackieren
    PaintColor = "Really black", -- Lackfarbe
}

-- ═══════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ═══════════════════════════════════════════════════════
-- VARIABLEN
-- ═══════════════════════════════════════════════════════
local CurrentCar = nil
local TotalProfit = 0
local CarsFixed = 0
local Running = false
local CurrentSeat = nil
local StartTime = os.time()

-- ═══════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════

local function Notify(text)
    game.StarterGui:SetCore("SendNotification", {
        Title = "Fix It Up",
        Text = text,
        Duration = 3
    })
end

local function RandomWait(min, max)
    task.wait(math.random(min * 10, max * 10) / 10)
end

local function Log(message)
    print("[FIX IT UP] " .. message)
end

-- ═══════════════════════════════════════════════════════
-- AUTO FINDEN FUNKTIONEN
-- ═══════════════════════════════════════════════════════

local function FindAllCarsInJunkyard()
    Log("Suche nach Autos im Junkyard...")
    
    local cars = {}
    
    -- Methode 1: Suche nach "Junkyard" Ordner
    local junkyard = Workspace:FindFirstChild("Junkyard")
    if junkyard then
        Log("Junkyard Ordner gefunden!")
        for _, item in pairs(junkyard:GetDescendants()) do
            if item:IsA("Model") and item:FindFirstChild("VehicleSeat") then
                local priceTag = item:FindFirstChild("Price") or item:FindFirstChild("Cost")
                if priceTag then
                    table.insert(cars, {
                        Model = item,
                        Price = priceTag.Value,
                        Position = item:GetModelCFrame().Position
                    })
                end
            end
        end
    end
    
    -- Methode 2: Suche in "Cars" Ordner
    local carsFolder = Workspace:FindFirstChild("Cars")
    if carsFolder then
        Log("Cars Ordner gefunden!")
        for _, item in pairs(carsFolder:GetChildren()) do
            if item:IsA("Model") and not item:FindFirstChild("Owned") then
                local seat = item:FindFirstChildOfClass("VehicleSeat") or item:FindFirstChild("Seat", true)
                if seat then
                    table.insert(cars, {
                        Model = item,
                        Price = 0,
                        Position = item:GetModelCFrame().Position
                    })
                end
            end
        end
    end
    
    -- Methode 3: Durchsuche ganzen Workspace nach Autos mit "ForSale" Tag
    for _, item in pairs(Workspace:GetDescendants()) do
        if item:IsA("Model") then
            local forSale = item:FindFirstChild("ForSale")
            if forSale and forSale.Value == true then
                local seat = item:FindFirstChildOfClass("VehicleSeat")
                if seat then
                    local priceTag = item:FindFirstChild("Price")
                    table.insert(cars, {
                        Model = item,
                        Price = priceTag and priceTag.Value or 0,
                        Position = item:GetModelCFrame().Position
                    })
                end
            end
        end
    end
    
    Log("Gefunden: " .. #cars .. " Autos")
    return cars
end

local function GetCheapestCar(carList)
    if #carList == 0 then return nil end
    
    table.sort(carList, function(a, b)
        return a.Price < b.Price
    end)
    
    for _, carData in ipairs(carList) do
        if carData.Price <= Settings.MaxCarPrice then
            Log("Bestes Auto: " .. carData.Model.Name .. " für €" .. carData.Price)
            return carData
        end
    end
    
    return carList[1]
end

-- ═══════════════════════════════════════════════════════
-- MOVEMENT & DRIVING
-- ═══════════════════════════════════════════════════════

local function WalkTo(position)
    Log("Laufe zu Position...")
    
    if not HumanoidRootPart then return false end
    
    local distance = (HumanoidRootPart.Position - position).Magnitude
    
    if distance < 5 then
        return true
    end
    
    Humanoid:MoveTo(position)
    
    local timeout = tick() + 30
    while (HumanoidRootPart.Position - position).Magnitude > 5 and tick() < timeout do
        task.wait(0.5)
    end
    
    return (HumanoidRootPart.Position - position).Magnitude < 10
end

local function SitInCar(vehicleSeat)
    if not vehicleSeat then return false end
    
    Log("Steige ins Auto...")
    
    -- Gehe zum Sitz
    local success = WalkTo(vehicleSeat.Position)
    if not success then
        Log("Kann Auto nicht erreichen!")
        return false
    end
    
    RandomWait(0.5, 1)
    
    -- Setze dich
    vehicleSeat:Sit(Humanoid)
    task.wait(1)
    
    if Humanoid.Sit then
        CurrentSeat = vehicleSeat
        Log("Im Auto!")
        return true
    end
    
    return false
end

local function DriveToPosition(targetPos)
    if not CurrentSeat then
        Log("Nicht im Auto!")
        return false
    end
    
    Log("Fahre zum Ziel...")
    
    local car = CurrentSeat.Parent
    local startTime = tick()
    local maxTime = 60 -- 60 Sekunden max
    
    while CurrentSeat and tick() - startTime < maxTime do
        local carPos = car.PrimaryPart and car.PrimaryPart.Position or car:GetModelCFrame().Position
        local distance = (carPos - targetPos).Magnitude
        
        if distance < 15 then
            Log("Ziel erreicht!")
            -- Stoppe
            CurrentSeat.ThrottleFloat = 0
            CurrentSeat.SteerFloat = 0
            break
        end
        
        -- Berechne Richtung
        local direction = (targetPos - carPos).Unit
        local carLook = car.PrimaryPart.CFrame.LookVector
        
        -- Lenken
        local angle = math.acos(math.clamp(direction:Dot(carLook), -1, 1))
        local cross = carLook:Cross(direction)
        
        if angle > 0.2 then
            CurrentSeat.SteerFloat = cross.Y > 0 and 1 or -1
        else
            CurrentSeat.SteerFloat = 0
        end
        
        -- Gas
        CurrentSeat.ThrottleFloat = 1
        
        task.wait(0.1)
    end
    
    -- Stoppe Auto
    if CurrentSeat then
        CurrentSeat.ThrottleFloat = 0
        CurrentSeat.SteerFloat = 0
    end
    
    return true
end

local function ExitCar()
    if CurrentSeat and Humanoid then
        Log("Steige aus...")
        Humanoid.Jump = true
        task.wait(0.5)
        CurrentSeat = nil
    end
end

-- ═══════════════════════════════════════════════════════
-- KAUF FUNKTIONEN
-- ═══════════════════════════════════════════════════════

local function BuyCarWithRemote(car)
    Log("Versuche Auto zu kaufen...")
    
    -- Suche nach allen möglichen RemoteEvents
    local possibleEvents = {
        "PurchaseCar",
        "BuyCar",
        "PurchaseVehicle",
        "BuyVehicle",
        "Purchase",
        "Buy"
    }
    
    for _, eventName in ipairs(possibleEvents) do
        local event = ReplicatedStorage:FindFirstChild(eventName, true)
        if event and (event:IsA("RemoteEvent") or event:IsA("RemoteFunction")) then
            Log("Gefunden: " .. eventName)
            
            pcall(function()
                if event:IsA("RemoteEvent") then
                    event:FireServer(car)
                else
                    event:InvokeServer(car)
                end
            end)
            
            return true
        end
    end
    
    -- Alternative: Suche nach ClickDetector oder ProximityPrompt
    for _, part in pairs(car:GetDescendants()) do
        local click = part:FindFirstChildOfClass("ClickDetector")
        if click then
            Log("ClickDetector gefunden!")
            fireclickdetector(click)
            return true
        end
        
        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            Log("ProximityPrompt gefunden!")
            fireproximityprompt(prompt)
            return true
        end
    end
    
    return false
end

local function BuyCar(carData)
    if not carData then return false end
    
    local car = carData.Model
    Notify("Kaufe: " .. car.Name)
    
    -- Gehe zum Auto
    local buyPos = carData.Position
    WalkTo(buyPos)
    RandomWait(1, 2)
    
    -- Versuche zu kaufen
    local success = BuyCarWithRemote(car)
    
    if success then
        Log("Kauf erfolgreich!")
        RandomWait(2, 3)
        return true
    else
        Log("Kauf fehlgeschlagen!")
        return false
    end
end

-- ═══════════════════════════════════════════════════════
-- EIGENES AUTO FINDEN
-- ═══════════════════════════════════════════════════════

local function FindMyOwnedCar()
    Log("Suche nach meinem Auto...")
    
    -- Methode 1: Suche nach "Owned" Tag
    for _, car in pairs(Workspace:GetDescendants()) do
        if car:IsA("Model") and car:FindFirstChild("Owner") then
            if car.Owner.Value == Player or car.Owner.Value == Player.Name then
                Log("Eigenes Auto gefunden: " .. car.Name)
                return car
            end
        end
    end
    
    -- Methode 2: Suche in PlayerCars Ordner
    local playerCars = Workspace:FindFirstChild("PlayerCars")
    if playerCars then
        for _, car in pairs(playerCars:GetChildren()) do
            if car:IsA("Model") then
                local owner = car:FindFirstChild("Owner")
                if owner and (owner.Value == Player or owner.Value == Player.Name) then
                    return car
                end
            end
        end
    end
    
    -- Methode 3: Suche nach Auto mit unserem Namen
    for _, car in pairs(Workspace:GetDescendants()) do
        if car:IsA("Model") and car.Name:find(Player.Name) then
            local seat = car:FindFirstChildOfClass("VehicleSeat")
            if seat then
                return car
            end
        end
    end
    
    Log("Kein eigenes Auto gefunden!")
    return nil
end

-- ═══════════════════════════════════════════════════════
-- REPARATUR FUNKTIONEN
-- ═══════════════════════════════════════════════════════

local function FindBrokenParts(car)
    Log("Suche kaputte Teile...")
    
    local brokenParts = {}
    
    for _, part in pairs(car:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Model") then
            -- Prüfe auf "Broken" oder "Damaged" Tag
            local broken = part:FindFirstChild("Broken") or part:FindFirstChild("Damaged")
            if broken and broken.Value == true then
                table.insert(brokenParts, part)
            end
            
            -- Prüfe Condition
            local condition = part:FindFirstChild("Condition") or part:FindFirstChild("Health")
            if condition and condition.Value < 100 then
                table.insert(brokenParts, part)
            end
        end
    end
    
    Log("Gefunden: " .. #brokenParts .. " kaputte Teile")
    return brokenParts
end

local function RepairPart(part)
    Log("Repariere: " .. part.Name)
    
    -- Gehe zum Teil
    if part:IsA("BasePart") then
        WalkTo(part.Position)
    elseif part:IsA("Model") and part.PrimaryPart then
        WalkTo(part.PrimaryPart.Position)
    end
    
    RandomWait(0.3, 0.7)
    
    -- Klicke auf Teil
    local click = part:FindFirstChildOfClass("ClickDetector")
    if click then
        fireclickdetector(click)
    end
    
    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
    end
    
    -- Sende Repair Event
    local repairEvents = {
        "RepairPart",
        "FixPart",
        "Repair",
        "Fix"
    }
    
    for _, eventName in ipairs(repairEvents) do
        local event = ReplicatedStorage:FindFirstChild(eventName, true)
        if event then
            pcall(function()
                if event:IsA("RemoteEvent") then
                    event:FireServer(part)
                else
                    event:InvokeServer(part)
                end
            end)
        end
    end
    
    local waitTime = Settings.RepairSpeed == "Fast" and 0.3 or 
                     Settings.RepairSpeed == "Slow" and 1.5 or 0.7
    task.wait(waitTime)
end

local function RepairCar(car)
    if not car then return false end
    
    Notify("Starte Reparatur...")
    Log("=== REPARATUR START ===")
    
    -- Finde alle kaputten Teile
    local brokenParts = FindBrokenParts(car)
    
    if #brokenParts == 0 then
        Log("Keine kaputten Teile gefunden!")
        return true
    end
    
    Notify("Repariere " .. #brokenParts .. " Teile")
    
    -- Repariere alle Teile
    for i, part in ipairs(brokenParts) do
        RepairPart(part)
        
        if i % 5 == 0 then
            Notify(string.format("Fortschritt: %d/%d", i, #brokenParts))
        end
    end
    
    Log("=== REPARATUR FERTIG ===")
    Notify("Reparatur abgeschlossen!")
    return true
end

-- ═══════════════════════════════════════════════════════
-- LACKIEREN
-- ═══════════════════════════════════════════════════════

local function PaintCar(car)
    if not Settings.AutoPaint then return true end
    if not car then return false end
    
    Log("Lackiere Auto...")
    Notify("Fahre zur Lackiererei...")
    
    -- Finde Paint Shop
    local paintShop = Workspace:FindFirstChild("PaintShop") or
                      Workspace:FindFirstChild("Paint") or
                      Workspace:FindFirstChild("SprayShop")
    
    if paintShop then
        -- Fahre dorthin
        local seat = car:FindFirstChildOfClass("VehicleSeat")
        if seat then
            SitInCar(seat)
            RandomWait(1, 2)
            
            local paintPos = paintShop:GetModelCFrame().Position
            DriveToPosition(paintPos)
            
            ExitCar()
        end
    end
    
    RandomWait(1, 2)
    
    -- Lackiere
    local paintEvents = {"PaintCar", "Paint", "SprayCar", "ColorCar"}
    
    for _, eventName in ipairs(paintEvents) do
        local event = ReplicatedStorage:FindFirstChild(eventName, true)
        if event then
            pcall(function()
                if event:IsA("RemoteEvent") then
                    event:FireServer(car, Settings.PaintColor)
                else
                    event:InvokeServer(car, Settings.PaintColor)
                end
            end)
            break
        end
    end
    
    Log("Lackierung fertig!")
    return true
end

-- ═══════════════════════════════════════════════════════
-- VERKAUF
-- ═══════════════════════════════════════════════════════

local function SellCar(car)
    if not car then return false end
    
    Log("Verkaufe Auto...")
    Notify("Fahre zum Verkauf...")
    
    -- Finde Verkaufsort
    local sellLocation = Workspace:FindFirstChild("SellZone") or
                         Workspace:FindFirstChild("Dealership") or
                         Workspace:FindFirstChild("AuctionHouse")
    
    if sellLocation then
        -- Fahre dorthin
        local seat = car:FindFirstChildOfClass("VehicleSeat")
        if seat then
            SitInCar(seat)
            RandomWait(1, 2)
            
            local sellPos = sellLocation:GetModelCFrame().Position
            DriveToPosition(sellPos)
            
            ExitCar()
        end
    end
    
    RandomWait(1, 2)
    
    -- Verkaufe
    local sellEvents = {"SellCar", "Sell", "SellVehicle"}
    
    for _, eventName in ipairs(sellEvents) do
        local event = ReplicatedStorage:FindFirstChild(eventName, true)
        if event then
            local sold = false
            pcall(function()
                if event:IsA("RemoteEvent") then
                    event:FireServer(car)
                    sold = true
                else
                    event:InvokeServer(car)
                    sold = true
                end
            end)
            
            if sold then
                CarsFixed = CarsFixed + 1
                Notify("Verkauft! Total: " .. CarsFixed .. " Autos")
                return true
            end
        end
    end
    
    Log("Verkauf fehlgeschlagen!")
    return false
end

-- ═══════════════════════════════════════════════════════
-- 160 SEKUNDEN WARTEZEIT MIT COUNTDOWN
-- ═══════════════════════════════════════════════════════

local function WaitWithCountdown(seconds)
    Notify("Warte " .. seconds .. " Sekunden...")
    
    for i = seconds, 0, -1 do
        if not Running then break end
        
        if i % 10 == 0 or i <= 5 then
            Log("Noch " .. i .. " Sekunden...")
        end
        
        task.wait(1)
    end
    
    Notify("Wartezeit vorbei!")
end

-- ═══════════════════════════════════════════════════════
-- HAUPT LOOP
-- ═══════════════════════════════════════════════════════

local function MainLoop()
    while Running do
        Log("=== NEUER DURCHGANG ===")
        Notify("Suche neues Auto...")
        
        -- 1. Finde Autos
        local allCars = FindAllCarsInJunkyard()
        
        if #allCars == 0 then
            Notify("Keine Autos gefunden! Warte 15s...")
            task.wait(15)
            continue
        end
        
        -- 2. Wähle günstigstes Auto
        local selectedCar = GetCheapestCar(allCars)
        
        if not selectedCar then
            Notify("Kein passendes Auto gefunden!")
            task.wait(10)
            continue
        end
        
        -- 3. Kaufe Auto
        local buySuccess = BuyCar(selectedCar)
        
        if not buySuccess then
            Notify("Kauf fehlgeschlagen!")
            task.wait(5)
            continue
        end
        
        RandomWait(2, 4)
        
        -- 4. Finde unser Auto
        CurrentCar = FindMyOwnedCar()
        
        if not CurrentCar then
            Notify("Auto nicht gefunden!")
            task.wait(5)
            continue
        end
        
        -- 5. Fahre zur Garage/Werkstatt
        Log("Fahre zur Werkstatt...")
        local seat = CurrentCar:FindFirstChildOfClass("VehicleSeat")
        if seat then
            SitInCar(seat)
            RandomWait(1, 2)
            
            local garage = Workspace:FindFirstChild("Garage") or 
                          Workspace:FindFirstChild("Workshop") or
                          Workspace:FindFirstChild("RepairZone")
            
            if garage then
                DriveToPosition(garage:GetModelCFrame().Position)
            end
            
            ExitCar()
        end
        
        RandomWait(2, 3)
        
        -- 6. Repariere Auto
        RepairCar(CurrentCar)
        RandomWait(2, 3)
        
        -- 7. Lackiere Auto
        if Settings.AutoPaint then
            PaintCar(CurrentCar)
            RandomWait(2, 3)
        end
        
        -- 8. *** WICHTIG: 160 SEKUNDEN WARTEN! ***
        Log("=== WARTEZEIT: 160 SEKUNDEN ===")
        Notify("⏰ MUSS 160 Sekunden warten!")
        WaitWithCountdown(Settings.WaitTime)
        
        -- 9. Verkaufe Auto
        SellCar(CurrentCar)
        
        CurrentCar = nil
        
        Log("=== DURCHGANG BEENDET ===")
        RandomWait(3, 5)
    end
end

-- ═══════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════

local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FixItUpGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = Player.PlayerGui
    
    -- Main Frame
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 320, 0, 380)
    Frame.Position = UDim2.new(0.5, -160, 0.5, -190)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 15)
    Corner.Parent = Frame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Title.Text = "🔧 FIX IT UP"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 22
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Frame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 15)
    TitleCorner.Parent = Title
    
    -- Status
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 70)
    Status.Position = UDim2.new(0, 10, 0, 60)
    Status.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Status.Text = "Status: Bereit\n160s Wartezeit aktiv ⏰"
    Status.TextColor3 = Color3.fromRGB(100, 200, 100)
    Status.TextSize = 16
    Status.Font = Enum.Font.Gotham
    Status.Parent = Frame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 10)
    StatusCorner.Parent = Status
    
    -- Start Button
    local StartBtn = Instance.new("TextButton")
    StartBtn.Size = UDim2.new(1, -20, 0, 50)
    StartBtn.Position = UDim2.new(0, 10, 0, 140)
    StartBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    StartBtn.Text = "▶ START"
    StartBtn.TextColor3 = Color3.new(1, 1, 1)
    StartBtn.TextSize = 18
    StartBtn.Font = Enum.Font.GothamBold
    StartBtn.Parent = Frame
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 10)
    BtnCorner.Parent = StartBtn
    
    StartBtn.MouseButton1Click:Connect(function()
        Running = not Running
        
        if Running then
            StartBtn.Text = "⏸ STOP"
            StartBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
            Status.Text = "Status: Läuft...\n160s Wartezeit aktiv ⏰"
            Status.TextColor3 = Color3.fromRGB(255, 200, 50)
            task.spawn(MainLoop)
        else
            StartBtn.Text = "▶ START"
            StartBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            Status.Text = "Status: Gestoppt"
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    
    -- Stats
    local Stats = Instance.new("TextLabel")
    Stats.Size = UDim2.new(1, -20, 0, 100)
    Stats.Position = UDim2.new(0, 10, 0, 200)
    Stats.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Stats.Text = "═══ STATISTIK ═══\nAutos: 0\nLaufzeit: 00:00"
    Stats.TextColor3 = Color3.new(1, 1, 1)
    Stats.TextSize = 16
    Stats.Font = Enum.Font.Gotham
    Stats.TextYAlignment = Enum.TextYAlignment.Top
    Stats.Parent = Frame
    
    local StatsCorner = Instance.new("UICorner")
    StatsCorner.CornerRadius = UDim.new(0, 10)
    StatsCorner.Parent = Stats
    
    -- Info
    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.new(1, -20, 0, 60)
    Info.Position = UDim2.new(0, 10, 0, 310)
    Info.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Info.Text = "⏰ 160s Wartezeit\n🚗 Fährt realistisch\n🔧 Keine Teleports"
    Info.TextColor3 = Color3.fromRGB(150, 150, 150)
    Info.TextSize = 14
    Info.Font = Enum.Font.Gotham
    Info.Parent = Frame
    
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 10)
    InfoCorner.Parent = Info
    
    -- Update Stats Loop
    task.spawn(function()
        while ScreenGui.Parent do
            local runtime = os.time() - StartTime
            local hours = math.floor(runtime / 3600)
            local minutes = math.floor((runtime % 3600) / 60)
            
            Stats.Text = string.format(
                "═══ STATISTIK ═══\nAutos repariert: %d\nLaufzeit: %02d:%02d",
                CarsFixed,
                hours,
                minutes
            )
            
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
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = Title
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseButton1Click:Connect(function()
        Running = false
        ScreenGui:Destroy()
    end)
    
    -- Draggable
    local dragging, dragInput, dragStart, startPos
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    Title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════════

task.spawn(function()
    while true do
        for _, connection in pairs(getconnections(Player.Idled)) do
            connection:Disable()
        end
        task.wait(60)
    end
end)

-- ═══════════════════════════════════════════════════════
-- START
-- ═══════════════════════════════════════════════════════

print("════════════════════════════════════")
print("FIX IT UP - REALISTISCHER SCRIPT")
print("✓ 160 Sekunden Wartezeit")
print("✓ Findet Autos automatisch")
print("✓ Fährt realistisch")
print("✓ Keine Teleports")
print("════════════════════════════════════")

CreateGUI()
Notify("Script geladen! ⏰ 160s Wartezeit aktiv")
