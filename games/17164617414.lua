local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local VapeEvents = setmetatable({}, {
    __index = function(self, Index: string)
        self[Index] = Instance.new("BindableEvent")
        return self[Index]
    end
})

local Players: Players = cloneref(game:GetService("Players"))
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
	local Registry: any = {Loaded = {}, Loading = {}, Failures = {}, Chunks = false, Reading = false}
	local Services = {}
	for _, Name: string in {"Players", "ReplicatedStorage", "RunService", "UserInputService", "ContextActionService", "TweenService", "HttpService", "Lighting", "Workspace", "CollectionService", "MaterialService", "SoundService", "StarterGui", "GuiService", "TextService", "ContentProvider", "AssetService", "CaptureService", "Debris", "CoreGui", "ProximityPromptService", "PhysicsService", "TextChatService", "TeleportService", "Teams"} do
	    Services[Name] = cloneref(game:GetService(Name))
	end
	
	local Journal: any = getgenv().CatReplayJournal
	if type(Journal) == "table" and type(Journal.Restore) == "function" then
	    pcall(Journal.Restore)
	end
	for _, Step: string in {"ReplayCamera", "ReplayStep"} do
	    pcall(Services.RunService.UnbindFromRenderStep, Services.RunService, Step)
	end
	
	local Context = {
	    Version = 1, vape = vape, Kind = "Scene", Lobby = false, PlaceId = game.PlaceId, Place = vape.Place, Directory = vape.Directory,
	    Require = require, Debug = debug, Notify = SendNotification, Registry = Registry, Services = Services,
	    Bedwars = nil, Store = nil, VapeEvents = VapeEvents, Entity = Entity
	}
	
	local function ReadChunk(Name: string): (any?, string?)
	    if not Registry.Chunks and Registry.Reading then
	        repeat
	            task.wait()
	        until not Registry.Reading
	    end
	    if not Registry.Chunks then
	        Registry.Reading = true
	        local Success: boolean, Chunks: any, Problem: any = pcall(function()
	            local Path: string = `{vape.Directory}/libraries/replay.lua`
	            if not isfile(Path) then
	                local Downloaded: boolean, Response: any = pcall(function()
	                    return game:HttpGet("https://api.catvape.dev/download/src/libraries/replay.lua", true)
	                end)
	                if not Downloaded or type(Response) ~= "string" or Response == "404: Not Found" then
	                    return nil, "download failed"
	                end
	                writefile(Path, `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n{Response}`)
	            end
	            local Compiled: any, Reason: any = loadstring(readfile(Path), "replay")
	            if not Compiled then
	                return nil, Reason
	            end
	            return Compiled()
	        end)
	        Registry.Reading = false
	        if not Success then
	            return nil, tostring(Chunks)
	        end
	        if type(Chunks) ~= "table" then
	            return nil, tostring(Problem or "compile error")
	        end
	        Registry.Chunks = Chunks
	    end
	    local Chunk: any = Registry.Chunks[Name]
	    if type(Chunk) ~= "function" then
	        return nil, `{Name} is not in the replay bundle`
	    end
	    return Chunk
	end
	
	Registry.Get = function(Name: string): any?
	    local Known: any = Registry.Loaded[Name]
	    if Known ~= nil then
	        return Known or nil
	    end
	    local Owner: any = Registry.Loading[Name]
	    if Owner then
	        if Owner == coroutine.running() then
	            return nil
	        end
	        repeat
	            task.wait()
	        until not Registry.Loading[Name]
	        return Registry.Loaded[Name] or nil
	    end
	    Registry.Loading[Name] = coroutine.running()
	    local Chunk: any, Problem: string? = ReadChunk(Name)
	    local Success: boolean, Result: any = false, Problem
	    if Chunk then
	        Success, Result = pcall(Chunk, Context)
	    end
	    Registry.Loading[Name] = nil
	    Registry.Loaded[Name] = Success and Result or false
	    if not Success then
	        Registry.Failures[Name] = tostring(Result)
	    end
	    return Success and Result or nil
	end
	
	Registry.Reset = function(Name: string)
	    if Registry.Loaded[Name] == false then
	        Registry.Loaded[Name] = nil
	        Registry.Failures[Name] = nil
	    end
	end
	
	local function OpenReplay()
	    task.spawn(function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	        local Viewer: any? = nil
	        for _, Name: string in {"replaycore", "replayenv", "replayui", "replayviewer"} do
	            Registry.Reset(Name)
	            Viewer = Registry.Get(Name)
	            if not Viewer then
	                break
	            end
	            Services.RunService.Heartbeat:Wait()
	        end
	        if Viewer then
	            pcall(Viewer.Toggle)
	        else
	            SendNotification("Replay", `The replay viewer could not be loaded: {tostring(Registry.Failures.replayviewer or Registry.Failures.replayui or Registry.Failures.replayenv or Registry.Failures.replaycore)}`, 8, "alert")
	        end
	    end)
	end
	
	if getgenv().ReplayTest then
	    local State: any = getgenv().ReplayState or {}
	    getgenv().ReplayState = State
	    State.Drive = State.Drive or {}
	    State.Drive.OpenMenu = OpenReplay
	    State.Drive.Registry = Registry
	end
	
	pcall(function()
	    vape.Settings.GUI:CreateBind({Name = "Replay menu", Tooltip = "Opens the replay menu", Function = function(IsDown: boolean)
	        if IsDown then
	            OpenReplay()
	        end
	    end})
	end)
	
	vape:Clean(function()
	    local Viewer: any = Registry.Loaded.replayviewer
	    if Viewer then
	        pcall(Viewer.Destroy)
	    end
	    local Env: any = Registry.Loaded.replayenv
	    if Env then
	        pcall(Env.Session.Shutdown)
	    end
	    local Recorder: any = Registry.Loaded.replayrec
	    if Recorder then
	        pcall(Recorder.Destroy)
	    end
	end)
	
	task.spawn(function()
	    repeat
	        task.wait(0.1)
	    until vape.Loaded or vape.Loaded == nil
	    if not vape.Loaded then
	        return
	    end
	    local Core: any = Registry.Get("replaycore")
	    if not Core then
	        return
	    end
	    Core.Store.Ensure()
	    local Settings: any = Core.Store.Settings()
	    for _, Name: string in {"replayenv", "replayui"} do
	        Services.RunService.Heartbeat:Wait()
	        Registry.Get(Name)
	    end
	    local Interface: any = Registry.Loaded.replayui
	    if not (Interface and Interface.Launcher and pcall(Interface.Launcher, OpenReplay)) then
	        pcall(function()
	            vape.Categories.Main:CreateGUIButton({Name = "Replays", Size = UDim2.fromOffset(14, 14), Function = OpenReplay})
	        end)
	    end
	    if Settings.Record ~= false then
	        Services.RunService.Heartbeat:Wait()
	        local Recorder: any = Registry.Get("replayrec")
	        if Recorder then
	            pcall(Recorder.Arm, Settings)
	        end
	    end
	    for _, Name: string in {"replayviewer", "replayrig", "replayworld"} do
	        Services.RunService.Heartbeat:Wait()
	        Registry.Get(Name)
	    end
	end)
end)