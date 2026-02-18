
--[[
    FIX IT UP - Simple Auto Farm Script
    Simplified version with essential features only
    
    Features:
    - One-click Auto Farm
    - Auto Repair
    - Auto Sell
    - Simple GUI
    
    Just execute and click "Start Auto Farm"!
]]

-- Quick Settings (edit these if you want)
local MAX_CAR_PRICE = 100000 -- Maximum price to pay for a car
local MINIMUM_PROFIT = 1.3 -- Sell only if 30%+ profit
local AUTO_PAINT = true -- Automatically paint cars before selling

-- Don't edit below this line unless you know what you're doing
local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Running = false
local TotalCars = 0
local TotalProfit = 0

-- Notification function
local function notify(text)
    game.StarterGui:SetCore("SendNotification", {
        Title = "Fix It Up",
        Text = text,
        Duration = 3
    })
end

-- Teleport function
local function teleport(cframe)
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = cframe
    end
end

-- Find cheapest/best car
local function findBestCar()
    local junkyard = Workspace:FindFirstChild("JunkyardCars")
    if not junkyard then return nil end
    
    local bestCar = nil
    local bestValue = math.huge
    
    for _, car in pairs(junkyard:GetChildren()) do
        if car:IsA("Model") and car:FindFirstChild("Price") then
            local price = car.Price.Value
            if price < bestValue and price <= MAX_CAR_PRICE then
                bestValue = price
                bestCar = car
            end
        end
    end
    
    return bestCar
end

-- Buy car function
local function buyCar(car)
    if not car then return false end
    
    notify("Buying: " .. car.Name)
    teleport(car.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
    wait(1)
    
    -- Fire buy event
    local buyEvent = ReplicatedStorage:FindFirstChild("BuyCar")
    if buyEvent then
        buyEvent:FireServer(car)
        wait(2)
        return true
    end
    
    return false
end

-- Repair car function
local function repairCar(car)
    if not car then return false end
    
    notify("Repairing car...")
    
    -- Find all broken parts
    local parts = {}
    for _, part in pairs(car:GetDescendants()) do
        if part:FindFirstChild("Damaged") and part.Damaged.Value then
            table.insert(parts, part)
        end
    end
    
    notify("Repairing " .. #parts .. " parts")
    
    -- Repair each part
    for _, part in ipairs(parts) do
        local repairEvent = ReplicatedStorage:FindFirstChild("RepairPart")
        if repairEvent then
            repairEvent:FireServer(part)
            wait(0.3)
        end
    end
    
    -- Paint if enabled
    if AUTO_PAINT then
        local paintEvent = ReplicatedStorage:FindFirstChild("PaintCar")
        if paintEvent then
            paintEvent:FireServer(car, "Metallic Black")
            wait(1)
        end
    end
    
    return true
end

-- Sell car function
local function sellCar(car)
    if not car then return false end
    
    local value = car:FindFirstChild("Value")
    local purchase = car:FindFirstChild("PurchasePrice")
    
    if value and purchase then
        local profit = value.Value - purchase.Value
        local margin = value.Value / purchase.Value
        
        if margin < MINIMUM_PROFIT then
            notify("Profit too low, skipping")
            return false
        end
        
        notify("Selling for profit: $" .. profit)
        
        local sellEvent = ReplicatedStorage:FindFirstChild("SellCar")
        if sellEvent then
            sellEvent:FireServer(car)
            TotalCars = TotalCars + 1
            TotalProfit = TotalProfit + profit
            wait(2)
            return true
        end
    end
    
    return false
end

-- Main farming loop
local function autoFarm()
    while Running do
        notify("Starting new cycle...")
        
        -- Step 1: Find and buy car
        local car = findBestCar()
        if car then
            buyCar(car)
            wait(2)
        else
            notify("No cars available, waiting...")
            wait(10)
            continue
        end
        
        -- Step 2: Get our car
        local myCar = nil
        local playerCars = Workspace:FindFirstChild("PlayerCars")
        if playerCars then
            for _, v in pairs(playerCars:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == Player then
                    myCar = v
                    break
                end
            end
        end
        
        if not myCar then
            notify("Couldn't find purchased car")
            wait(5)
            continue
        end
        
        -- Step 3: Repair
        repairCar(myCar)
        wait(2)
        
        -- Step 4: Sell
        sellCar(myCar)
        wait(3)
        
        -- Stats
        notify(string.format("Cars: %d | Profit: $%d", TotalCars, TotalProfit))
    end
end

-- Create simple GUI
local function createGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FixItUpSimple"
    gui.ResetOnSpawn = false
    gui.Parent = Player.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 200)
    frame.Position = UDim2.new(0.5, -125, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
    title.Text = "FIX IT UP"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 20
    title.Font = Enum.Font.SourceSansBold
    title.Parent = frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = title
    
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0, 200, 0, 50)
    startBtn.Position = UDim2.new(0.5, -100, 0, 60)
    startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    startBtn.Text = "START AUTO FARM"
    startBtn.TextColor3 = Color3.new(1, 1, 1)
    startBtn.TextSize = 18
    startBtn.Font = Enum.Font.SourceSansBold
    startBtn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = startBtn
    
    local stats = Instance.new("TextLabel")
    stats.Size = UDim2.new(1, -20, 0, 60)
    stats.Position = UDim2.new(0, 10, 0, 130)
    stats.BackgroundTransparency = 1
    stats.Text = "Cars: 0\nProfit: $0"
    stats.TextColor3 = Color3.new(1, 1, 1)
    stats.TextSize = 16
    stats.Font = Enum.Font.SourceSans
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.Parent = frame
    
    startBtn.MouseButton1Click:Connect(function()
        Running = not Running
        
        if Running then
            startBtn.Text = "STOP AUTO FARM"
            startBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            task.spawn(autoFarm)
        else
            startBtn.Text = "START AUTO FARM"
            startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        end
    end)
    
    -- Update stats
    task.spawn(function()
        while gui.Parent do
            stats.Text = string.format("Cars Fixed: %d\nTotal Profit: $%d", TotalCars, TotalProfit)
            wait(1)
        end
    end)
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.Parent = title
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        Running = false
        gui:Destroy()
    end)
end

-- Initialize
createGUI()
notify("Script loaded! Click START to begin")

print("=================================")
print("FIX IT UP - Simple Auto Farm")
print("Script loaded successfully!")
print("=================================")
