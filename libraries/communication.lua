local Players: Players = (cloneref or function(Reference: Instance)
    return Reference
end)(game:GetService("Players"))
local LocalPlayer: Player = Players.LocalPlayer

local Communication = {}
Communication.__index = Communication

function Communication:Encode(Command: string): string
    local Buffer: buffer = buffer.create(48)
    local Seed: number = Random.new():NextInteger(1, 4294967295)
    local Size: number = math.ceil((#Command + 4) / 6) * 6
    local Numbers: {string} = {}

    buffer.writeu32(Buffer, 0, Seed)
    buffer.writestring(Buffer, 4, Command)

    for i: number = 4, Size - 1 do
        Seed = bit32.bxor(Seed, bit32.lshift(Seed, 13))
        Seed = bit32.bxor(Seed, bit32.rshift(Seed, 17))
        Seed = bit32.bxor(Seed, bit32.lshift(Seed, 5))

        buffer.writeu8(Buffer, i, bit32.bxor(buffer.readu8(Buffer, i), Seed % 256))
    end

    for i: number = 0, Size - 1, 6 do
        table.insert(Numbers, string.format("%015d", buffer.readu32(Buffer, i) + buffer.readu16(Buffer, i + 4) * 4294967296))
    end

    return table.concat(Numbers)
end

function Communication:Decode(Numbers: string): string
    local Buffer: buffer = buffer.create(48)
    local Size: number = #Numbers // 15 * 6
    for i: number = 0, #Numbers - 1, 15 do
        local Number: number? = tonumber(Numbers:sub(i + 1, i + 15))
        local Offset: number = i // 15 * 6
        buffer.writeu32(Buffer, Offset, Number % 4294967296)
        buffer.writeu16(Buffer, Offset + 4, Number // 4294967296)
    end

    local Seed: number = buffer.readu32(Buffer, 0)
    for i: number = 4, Size - 1 do
        Seed = bit32.bxor(Seed, bit32.lshift(Seed, 13))
        Seed = bit32.bxor(Seed, bit32.rshift(Seed, 17))
        Seed = bit32.bxor(Seed, bit32.lshift(Seed, 5))

        buffer.writeu8(Buffer, i, bit32.bxor(buffer.readu8(Buffer, i), Seed % 256))
    end

    return (buffer.readstring(Buffer, 4, Size - 4):gsub("\0", ""))
end

function Communication:Connect(Channel: string)
    local Socket = setmetatable({
        Channel = Channel,
        Callbacks = {},
        Connections = {},
        Animators = {}
    }, Communication)
    local Prefix: string = `{Channel}\255`

    local function Added(Player: Player, Character: Model?)
        if not Character then
            Socket.Connections[Player] = Player.CharacterAdded:Connect(function(NewCharacter: Model)
                Added(Player, NewCharacter)
            end)
            Character = Player.Character
            if not Character then
                return
            end
        end

        local Humanoid: Humanoid? = Character:WaitForChild("Humanoid", 10)
        local Animator: Animator? = Humanoid and Humanoid:WaitForChild("Animator", 10)
        if not Animator or Player.Character ~= Character or not Socket.Connections[Player] then
            return
        end

        if Socket.Animators[Player] then
            Socket.Animators[Player]:Disconnect()
        end

        Socket.Animators[Player] = Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
            local AnimationId: string = Track.Animation and Track.Animation.AnimationId or ""
            local Length: number = #AnimationId - 13
            if Length % 15 ~= 0 or Length > 120 or not AnimationId:match("^rbxassetid://%d+$") then
                return
            end

            local Command: string = Socket:Decode(AnimationId:sub(14))
            if Command:sub(1, #Prefix) == Prefix then
                Command = Command:sub(#Prefix + 1)
                for _, v: (string, Player) -> () in Socket.Callbacks do
                    task.spawn(v, Command, Player)
                end
            end
        end)
    end

    Socket.Connections.PlayerAdded = Players.PlayerAdded:Connect(Added)
    Socket.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(Player: Player)
        if Socket.Connections[Player] then
            Socket.Connections[Player]:Disconnect()
            Socket.Connections[Player] = nil
        end

        if Socket.Animators[Player] then
            Socket.Animators[Player]:Disconnect()
            Socket.Animators[Player] = nil
        end
    end)

    for _, v: Player in Players:GetPlayers() do
        task.spawn(Added, v)
    end

    return Socket
end

function Communication:OnReceive(Callback: (string, Player) -> ()): {Disconnect: () -> ()}
    local Connection: {Disconnect: () -> ()} = {}

    function Connection.Disconnect()
        self.Callbacks[Connection] = nil
    end

    self.Callbacks[Connection] = Callback

    return Connection
end

function Communication:Close()
    if self.OnClose then
        self.OnClose()
    end

    for _, v: RBXScriptConnection in self.Connections do
        v:Disconnect()
    end

    for _, v: RBXScriptConnection in self.Animators do
        v:Disconnect()
    end

    table.clear(self.Connections)
    table.clear(self.Animators)
    table.clear(self.Callbacks)
end

function Communication:Fire(Command: string)
    local Character: Model? = LocalPlayer.Character
    local Humanoid: Humanoid? = Character and Character:FindFirstChildOfClass("Humanoid")
    local Animator: Animator? = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        return
    end

    local Animation: Animation = Instance.new("Animation")
    Animation.AnimationId = `rbxassetid://{self:Encode(`{self.Channel}\255{Command}`)}`

    local Track: AnimationTrack = Animator:LoadAnimation(Animation)
    Track:Play()
    Track:Stop()

    task.delay(1, function()
        Track:Destroy()
        Animation:Destroy()
    end)
end

return Communication