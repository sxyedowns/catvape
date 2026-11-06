if table.find({"Solara", "Xeno"}, ({identifyexecutor()})[1]) then
    return false
end
local Run = function(Func: () -> ())
    xpcall(Func, function(Message)
        warn(`[catvape] {Message}\n{debug.traceback(nil, 2)}`)
        if shared.vape then
            shared.vape:CreateNotification("Vape", `A module failed to load : {Message}`, 15, "alert")
        end
    end)

    shared.vape.YieldBuild()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local Players: Players = cloneref(game:GetService("Players"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local TeleportService: TeleportService = cloneref(game:GetService("TeleportService"))

local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local SessionInfo = vape.Libraries.sessioninfo
local bedwars = {}

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
    local function DumpRemote(Remotes: {string}): string
        local Index: number? = table.find(Remotes, "Client")
        return Index and Remotes[Index + 1] or ""
    end

    local KnitInit, Knit
    repeat
        KnitInit, Knit = pcall(function()
            return debug.getupvalue(require(LocalPlayer.PlayerScripts.TS.knit).setup, 9)
        end)
        if KnitInit then
            break
        end
        task.wait()
    until KnitInit
    if not debug.getupvalue(Knit.Start, 1) then
        repeat
            task.wait()
        until debug.getupvalue(Knit.Start, 1)
    end
    local Flamework = require(ReplicatedStorage["rbxts_include"]["node_modules"]["@flamework"].core.out).Flamework
    local Client = require(ReplicatedStorage.TS.remotes).default.Client

    bedwars = setmetatable({
        Client = Client,
        CrateItemMeta = debug.getupvalue(Flamework.resolveDependency("client/controllers/global/reward-crate/crate-controller@CrateController").onStart, 3),
        EmoteDisplayMeta = require(ReplicatedStorage.TS.locker.emote["emote-display-meta"]).EmoteDisplayMeta,
        EmoteMeta = require(ReplicatedStorage.TS.locker.emote["emote-meta"]).EmoteMeta,
        EmoteType = require(ReplicatedStorage.TS.locker.emote["emote-type"]).EmoteType,
        Flamework = Flamework,
        GameAnimationUtil = require(ReplicatedStorage.TS.animation["animation-util"]).GameAnimationUtil,
        GamePlayerUtil = require(ReplicatedStorage.TS.player["player-util"]).GamePlayerUtil,
        AchievementUtil = require(ReplicatedStorage.TS.achievement["achievement-util"]).AchievementUtil,
        ModerationApp = require(LocalPlayer.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
        MilestoneRewards = require(ReplicatedStorage.TS.milestones.milestones).MilestoneRewards,
        QueueMeta = require(ReplicatedStorage.TS.game["queue-meta"]).QueueMeta,
        Store = require(LocalPlayer.PlayerScripts.TS.ui.store).ClientStore
    }, {
        __index = function(self, Index: string)
            rawset(self, Index, Knit.Controllers[Index])
            return rawget(self, Index)
        end
    })

    local Kills = SessionInfo:AddItem("Kills")
    local Beds = SessionInfo:AddItem("Beds")
    local Wins = SessionInfo:AddItem("Wins")
    local Games = SessionInfo:AddItem("Games")

    vape:Clean(function()
        table.clear(bedwars)
    end)
end)

for Name: string, v: any in vape.Modules do
    if v.Category == "Combat" then
        vape:Remove(Name)
    end
end

Run(function()
	local Sprint
	local Old: (...any) -> ...any
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = bedwars.SprintController.stopSprinting
	            bedwars.SprintController.stopSprinting = function(...)
	                local Call = Old(...)
	                bedwars.SprintController:startSprinting()
	                return Call
	            end
	
	            Sprint:Clean(Entity.Events.LocalAdded:Connect(function()
	                bedwars.SprintController:stopSprinting()
	            end))
	
	            bedwars.SprintController:stopSprinting()
	        else
	            bedwars.SprintController.stopSprinting = Old
	            bedwars.SprintController:stopSprinting()
	        end
	    end,
	    Tooltip = "Sets your sprinting to true."
	})
end)

Run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Utility:CreateModule({
	    Name = "AutoGamble",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoGamble:Clean(bedwars.Client:GetNamespace("RewardCrate"):Get("CrateOpened"):Connect(function(Data)
	                if Data.openingPlayer == LocalPlayer then
	                    local ItemMeta = bedwars.CrateItemMeta[Data.reward.itemType] or {displayName = Data.reward.itemType or "unknown"}
	                    SendNotification("AutoGamble", `Won {ItemMeta.displayName}`, 5)
	                end
	            end))
	
	            repeat
	                if not bedwars.CrateAltarController.activeCrates[1] then
	                    for _, v: any in bedwars.Store:getState().Consumable.inventory do
	                        if v.consumable:find("crate") then
	                            bedwars.CrateAltarController:pickCrate(v.consumable, 1)
	                            task.wait(1.2)
	                            if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
	                                bedwars.Client:GetNamespace("RewardCrate"):Get("OpenRewardCrate"):SendToServer({
	                                    crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
	                                })
	                            end
	                            break
	                        end
	                    end
	                end
	                task.wait(1)
	            until not AutoGamble.Enabled
	        end
	    end,
	    Tooltip = "Automatically opens lucky crates, piston inspired!"
	})
end)

Run(function()
	local AutoQueue
	local QueueType
	local Delay
	local Leave
	
	local Categories = {}
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = "AutoQueue",
	    Function = function(Callback: boolean)
	        if Callback then
	            local ReadySince: number?
	            local NextAction: number = 0
	            repeat
	                local PartyData = bedwars.Store:getState().Party
	                local Selected: string? = Categories[QueueType.Value]
	                if PartyData.leader.userId ~= LocalPlayer.UserId then
	                    ReadySince = nil
	                    if Leave.Enabled and os.clock() >= NextAction then
	                        ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveParty:FireServer()
	                        NextAction = os.clock() + 1
	                    end
	                elseif PartyData.queueState ~= 0 then
	                    ReadySince = nil
	                    if Selected and PartyData.queueState == 2 and PartyData.queueData and PartyData.queueData.queueType ~= Selected and os.clock() >= NextAction then
	                        ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveQueue:FireServer()
	                        NextAction = os.clock() + 1
	                    end
	                elseif Selected then
	                    ReadySince = ReadySince or os.clock()
	                    if os.clock() - ReadySince >= Delay.Value and os.clock() >= NextAction then
	                        bedwars.QueueController:joinQueue(Selected)
	                        NextAction = os.clock() + 5
	                    end
	                end
	                task.wait(0.1)
	            until not AutoQueue.Enabled
	        else
	            ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveQueue:FireServer()
	        end
	    end,
	    Tooltip = "Joins the queue for the selected mode from the lobby, and joins again whenever you are out of a queue"
	})
	
	local List: {string} = {}
	for Queue: string, v: any in bedwars.QueueMeta do
	    if not v.disabled and v.title and not Categories[v.title] then
	        Categories[v.title] = Queue
	        table.insert(List, v.title)
	    end
	end
	table.sort(List)
	QueueType = AutoQueue:CreateDropdown({
	    Name = "Queue Type",
	    List = List,
	    Default = "Duels (2v2)"
	})
	Delay = AutoQueue:CreateSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 10,
	    Decimal = 10,
	    Default = 0,
	    Suffix = function(Value: number)
	        return Value == 1 and "second" or "seconds"
	    end,
	    Tooltip = "How long to wait once you are free to queue before joining. Failed joins are retried every 5 seconds"
	})
	Leave = AutoQueue:CreateToggle({
	    Name = "Leave Party",
	    Default = true
	})
end)

Run(function()
	local ClaimRewards
	local CratesOnly
	local Notify
	
	ClaimRewards = vape.Categories.Utility:CreateModule({
	    Name = "ClaimRewards",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Level: number = bedwars.Store:getState().Bedwars.playerLevel or 0
	                local Claimed = bedwars.MilestonesController.milestoneRewardsClaimed
	                if not Claimed then
	                    local State = bedwars.Store:getState().Bedwars
	                    Claimed = State and State.milestoneRewardsClaimed or {}
	                end
	
	                for _, v: any in bedwars.MilestoneRewards do
	                    if v.levelRequirement <= Level and not table.find(Claimed, v.id) and (not CratesOnly.Enabled or v.instantClaim) then
	                        if bedwars.Client:Get("ClaimMilestoneReward"):CallServer(v.id) then
	                            table.insert(Claimed, v.id)
	                            if Notify.Enabled then
	                                SendNotification("ClaimRewards", `Claimed {v.description or v.id}`, 5)
	                            end
	                        end
	                        task.wait(1)
	                        if not ClaimRewards.Enabled then
	                            break
	                        end
	                    end
	                end
	
	                task.wait(5)
	            until not ClaimRewards.Enabled
	        end
	    end,
	    Tooltip = "Automatically claims every level milestone reward as soon as you unlock it"
	})
	
	CratesOnly = ClaimRewards:CreateToggle({
	    Name = "Crates only",
	    Tooltip = "Only claims the instant rewards like the lucky and diamond crates, leaves kits and cosmetics alone"
	})
	Notify = ClaimRewards:CreateToggle({
	    Name = "Notify",
	    Default = true,
	    Tooltip = "Tells you what got claimed"
	})
end)

Run(function()
	local DeviceSpoofer
	local Device
	local OldDevice, Old
	
	DeviceSpoofer = vape.Categories.Utility:CreateModule({
	    Name = "DeviceSpoofer",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldDevice, Old = bedwars.UserInputController:getUserInputType(), bedwars.UserInputController.getUserInputType
	            bedwars.UserInputController.getUserInputType = function()
	                return Device.Value:upper()
	            end
	            bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = Device.Value:upper()})
	        else
	            bedwars.UserInputController.getUserInputType = Old
	            bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = OldDevice})
	            Old = nil
	        end
	    end,
	    Tooltip = "Spoofs the device you show up as to the server",
	    ExtraText = function()
	        return Device.Value
	    end
	})
	
	Device = DeviceSpoofer:CreateDropdown({
	    Name = "Device",
	    List = {"Mobile", "PC", "Gamepad"},
	    Function = function(Val: string)
	        if DeviceSpoofer.Enabled then
	            bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = Val:upper()})
	        end
	    end
	})
end)

Run(function()
	local OriginalLevels: {[any]: number} = {}
	
	vape.Categories.Utility:CreateModule({
	    Name = "LevelBypass",
	    Function = function(Callback: boolean)
	        if Callback then
	            for _, Metadata: any in bedwars.QueueMeta do
	                if type(Metadata.playerLevelReq) == "number" and Metadata.playerLevelReq > 0 then
	                    OriginalLevels[Metadata] = Metadata.playerLevelReq
	                    Metadata.playerLevelReq = 0
	                end
	            end
	        else
	            for Metadata: any, Level: number in OriginalLevels do
	                if Metadata.playerLevelReq == 0 then
	                    Metadata.playerLevelReq = Level
	                end
	            end
	            table.clear(OriginalLevels)
	        end
	    end,
	    Tooltip = "Removes local level locks on lobby queues. Reopen the play menu after toggling. Server level restrictions still apply"
	})
end)

Run(function()
	local MatchDodge
	local Mode
	local Timeout = {}
	local Skill = {}
	local RankCheck = {}
	local Amount = {}
	local AmountWhitelist = {}
	
	MatchDodge = vape.Categories.Utility:CreateModule({
	    Name = "AutoMatchDodge",
	    Function = function(Callback: boolean)
	        writefile(`{vape.Directory}/profiles/matchdodge.txt`, tostring(Callback))
	        getgenv().matchDodgeActive = Callback
	    end,
	    Tooltip = "Puts you in a loading state for as long as you want. These settings carry over into the match"
	})
	
	Mode = MatchDodge:CreateDropdown({
	    Name = "Mode",
	    List = {"Auto", "Manual"},
	    Function = function(Value: string)
	        if Skill.Object then
	            Skill.Object.Visible = Value == "Auto"
	        end
	
	        if RankCheck.Object then
	            RankCheck.Object.Visible = Value == "Auto"
	        end
	
	        if Amount.Object then
	            Amount.Object.Visible = Value == "Auto"
	        end
	
	        if Timeout.Object then
	            Timeout.Object.Visible = Value == "Auto"
	        end
	    end,
	    Default = "Auto"
	})
	Timeout = MatchDodge:CreateSlider({
	    Name = "Load timeout",
	    Tooltip = "Loads into the game after interval",
	    Min = 1,
	    Max = 90,
	    Default = 45,
	    Suffix = function(Value: number)
	        return Value <= 1 and "sec" or "secs"
	    end,
	    Darker = true
	})
	Skill = MatchDodge:CreateToggle({
	    Name = "Skill check",
	    Default = true,
	    Darker = true,
	    Tooltip = "Checks if you're \"better\" than the opponents you're facing (this is not 100% accurate)"
	})
	RankCheck = MatchDodge:CreateToggle({
	    Name = "Rank check",
	    Default = true,
	    Darker = true,
	    Tooltip = "Only dodges in ranked queues, any other match just loads"
	})
	Amount = MatchDodge:CreateToggle({
	    Name = "Player check",
	    Function = function(Callback: boolean)
	        if AmountWhitelist.Object then
	            AmountWhitelist.Object.Visible = Callback
	        end
	    end,
	    Darker = true,
	    Tooltip = "Checks if you have lesser the player you\'re going up against"
	})
	AmountWhitelist = MatchDodge:CreateTextList({
	    Name = "Players Whitelist",
	    Darker = true,
	    Tooltip = "People that will 100% be on your team if they\'re in the server",
	    Visible = false
	})
	if MatchDodge.Share then
	    MatchDodge:Share("matchdodge")
	end
end)

Run(function()
	local MatchHistory
	
	MatchHistory = vape.Categories.Utility:CreateModule({
	    Name = "ViewMatchHistory",
	    Function = function(Callback: boolean)
	        if Callback then
	            bedwars.Flamework.resolveDependency("@easy-games/game-core:client/controllers/app-controller@AppController"):openApp({
	                appId = "MatchHistoryApp",
	                app = bedwars.ModerationApp
	            }, {
	                player = LocalPlayer,
	                matchHistory = {}
	            })
	            MatchHistory:Toggle()
	        end
	    end
	})
end)

Run(function()
	local NickHider
	local Replacement
	local ChatTags
	local Level
	local HideOthers
	local Swapped: {[Instance]: string} = setmetatable({}, {__mode = "k"})
	local Watched: {[Instance]: RBXScriptConnection} = setmetatable({}, {__mode = "k"})
	local Patterns: {string} = {}
	local Plain: {string} = {}
	local Shortest: number = math.huge
	local TextClasses: {[string]: boolean} = {TextLabel = true, TextButton = true, TextBox = true}
	local FakeName: string = "hidden"
	local Writing: Instance?
	local OldUsername, OldDisplayName, OldClanTag, OldLevel
	
	local Refreshing: boolean = false
	
	local function QueueRefresh()
	    if Refreshing or not NickHider or not NickHider.Enabled then
	        return
	    end
	    Refreshing = true
	
	    task.delay(0.35, function()
	        Refreshing = false
	        if NickHider.Enabled then
	            NickHider:Toggle()
	            NickHider:Toggle()
	        end
	    end)
	end
	
	local function ShouldHidePlayer(Player: Player?)
	    return Player and (Player.UserId == LocalPlayer.UserId or HideOthers.Enabled)
	end
	
	local function AddPlayerNames(Player: Player)
	    for _, v: string in {Player.Name, Player.DisplayName} do
	        if v ~= "" then
	            local LowerName: string = v:lower()
	            if not table.find(Plain, LowerName) then
	                table.insert(Plain, LowerName)
	                Shortest = math.min(Shortest, #LowerName)
	            end
	        end
	        for _, Variant: string in {v, v:lower(), v:upper()} do
	            local Pattern: string = (Variant:gsub("%W", "%%%0"))
	            if Variant ~= "" and not table.find(Patterns, Pattern) then
	                table.insert(Patterns, Pattern)
	            end
	        end
	    end
	end
	
	local function IsLocal(GamePlayer): boolean
	    local Player: Player? = GamePlayer:getPlayer()
	    return Player ~= nil and Player.UserId == LocalPlayer.UserId
	end
	
	local function GetGamePlayerClass()
	    local GamePlayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(LocalPlayer)
	    local Meta = GamePlayer and getmetatable(GamePlayer)
	    return Meta and Meta.__index
	end
	
	local function HasPlayerName(Object: Instance)
	    local Ancestor: Instance? = Object.Parent
	    for _ = 1, 3 do
	        if not Ancestor then
	            return nil
	        end
	        local Label = Ancestor:FindFirstChild("PlayerName", true)
	        if Label then
	            return Label
	        end
	        Ancestor = Ancestor.Parent
	    end
	    return nil
	end
	
	local function HideLevelObject(Object: Instance)
	    if not (Level.Enabled or HideOthers.Enabled) or not TextClasses[Object.ClassName] then
	        return
	    end
	    if not Object.Name:lower():find("level", 1, true) then
	        return
	    end
	    local PlayerName = HasPlayerName(Object)
	    if not PlayerName or (not HideOthers.Enabled and not PlayerName.Text:find(FakeName, 1, true)) then
	        return
	    end
	
	    local function Apply()
	        if Writing == Object or not Object.Parent then
	            return
	        end
	        local Text = Object.Text
	        if type(Text) ~= "string" or Text == "" then
	            return
	        end
	
	        Swapped[Object] = Swapped[Object] or Text
	        Writing = Object
	        Object.Text = ""
	        Writing = nil
	    end
	
	    Apply()
	    if not Watched[Object] then
	        Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(Apply)
	    end
	end
	
	local function HideLevelSiblings(Object: Instance?)
	    if not Object then
	        return
	    end
	    for _, v: Instance in Object:GetDescendants() do
	        HideLevelObject(v)
	    end
	end
	
	local function ReplaceText(Object: Instance)
	    if Writing == Object then
	        return
	    end
	
	    local Text = Object.Text
	    if type(Text) ~= "string" or #Text < Shortest then
	        return
	    end
	
	    local Hit: boolean = false
	    for _, v: string in Plain do
	        if Text:find(v, 1, true) then
	            Hit = true
	            break
	        end
	    end
	    if not Hit then
	        local LowerText: string = Text:lower()
	        for _, v: string in Plain do
	            if LowerText:find(v, 1, true) then
	                Hit = true
	                break
	            end
	        end
	    end
	    if not Hit then
	        return
	    end
	
	    local NewText: string = Text
	    for _, v: string in Patterns do
	        if NewText:find(v) then
	            NewText = NewText:gsub(v, FakeName)
	        end
	    end
	    if NewText == Text then
	        return
	    end
	
	    Swapped[Object] = Text
	    Object:SetAttribute("NickHiderOriginalText", Text)
	    Writing = Object
	    Object.Text = NewText
	    Writing = nil
	    HideLevelSiblings(Object.Parent)
	
	    if not Watched[Object] then
	        Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(function()
	            ReplaceText(Object)
	        end)
	    end
	end
	
	local function HideObject(Object: Instance)
	    if TextClasses[Object.ClassName] then
	        ReplaceText(Object)
	    end
	end
	
	local function Watch(Root: Instance?)
	    if not Root then
	        return
	    end
	
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	    NickHider:Clean(Root.DescendantAdded:Connect(function(Object: Instance)
	        if NickHider.Enabled then
	            HideObject(Object)
	            HideLevelObject(Object)
	        end
	    end))
	
	    local Clock: number = os.clock()
	    for _, v: Instance in Root:GetDescendants() do
	        HideObject(v)
	        HideLevelObject(v)
	
	        if os.clock() - Clock > 0.002 then
	            task.wait()
	            if not NickHider.Enabled then
	                return
	            end
	            Clock = os.clock()
	
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	        end
	    end
	end
	
	NickHider = vape.Categories.Utility:CreateModule({
	    Name = "NickHider",
	    ConfigName = "NameHider",
	    Function = function(Callback: boolean)
	        if Callback then
	            table.clear(Patterns)
	            table.clear(Plain)
	            Shortest = math.huge
	            for _, v: Player in Players:GetPlayers() do
	                if v == LocalPlayer or HideOthers.Enabled then
	                    AddPlayerNames(v)
	                end
	            end
	
	            FakeName = Replacement.Value ~= "" and Replacement.Value or "hidden"
	            for _, v: string in Patterns do
	                if FakeName:find(v) then
	                    FakeName = "hidden"
	                    break
	                end
	            end
	
	            local GamePlayer = GetGamePlayerClass()
	            if GamePlayer and not OldUsername then
	                OldUsername, OldDisplayName = GamePlayer.getUsername, GamePlayer.getDisplayName
	                OldClanTag, OldLevel = GamePlayer.getClanTag, GamePlayer.getLevel
	                GamePlayer.getUsername = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    return ShouldHidePlayer(Player) and FakeName or OldUsername(self, ...)
	                end
	                GamePlayer.getDisplayName = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    return ShouldHidePlayer(Player) and FakeName or OldDisplayName(self, ...)
	                end
	                GamePlayer.getClanTag = function(self, ...)
	                    return IsLocal(self) and ChatTags.Enabled and "" or OldClanTag(self, ...)
	                end
	                GamePlayer.getLevel = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    if Player and (HideOthers.Enabled or (Player.UserId == LocalPlayer.UserId and Level.Enabled)) then
	                        return -1
	                    end
	                    return OldLevel(self, ...)
	                end
	            end
	
	            for _, v: Instance? in {LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui, gethui and gethui() or nil, LocalPlayer.Character} do
	                Watch(v)
	            end
	
	            NickHider:Clean(LocalPlayer.CharacterAdded:Connect(function(Character: Model)
	                if NickHider.Enabled then
	                    Watch(Character)
	                end
	            end))
	            NickHider:Clean(Players.PlayerAdded:Connect(function()
	                if HideOthers.Enabled then
	                    QueueRefresh()
	                end
	            end))
	            NickHider:Clean(Players.PlayerRemoving:Connect(function()
	                if HideOthers.Enabled then
	                    QueueRefresh()
	                end
	            end))
	        else
	            local GamePlayer = GetGamePlayerClass()
	            if OldUsername and GamePlayer then
	                GamePlayer.getUsername, GamePlayer.getDisplayName = OldUsername, OldDisplayName
	                GamePlayer.getClanTag, GamePlayer.getLevel = OldClanTag, OldLevel
	                OldUsername, OldDisplayName, OldClanTag, OldLevel = nil, nil, nil, nil
	            end
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            for _, v: RBXScriptConnection in Watched do
	                v:Disconnect()
	            end
	            table.clear(Watched)
	
	            for Object: Instance, v: string in Swapped do
	                if Object.Parent then
	                    Writing = Object
	                    Object.Text = v
	                    Object:SetAttribute("NickHiderOriginalText", nil)
	                end
	            end
	            Writing = nil
	            table.clear(Swapped)
	        end
	    end,
	    Tooltip = "Replaces your username and display name everywhere it shows up on your screen",
	    ExtraText = function()
	        return Replacement.Value ~= "" and Replacement.Value or "hidden"
	    end
	})
	
	Replacement = NickHider:CreateTextBox({
	    Name = "Name",
	    Function = QueueRefresh,
	    Default = "hidden"
	})
	HideOthers = NickHider:CreateToggle({
	    Name = "Hide others",
	    Function = QueueRefresh,
	    Tooltip = "Hides every player's username and level"
	})
	ChatTags = NickHider:CreateToggle({
	    Name = "Hide chat tags",
	    Tooltip = "Hides your clan tag wherever it renders"
	})
	Level = NickHider:CreateToggle({
	    Name = "Hide level",
	    Function = QueueRefresh,
	    Tooltip = "Hides your level wherever it renders"
	})
end)

Run(function()
	local RegionLock
	local Regions
	
	RegionLock = vape.Categories.Utility:CreateModule({
	    Name = "RegionLock",
	    Function = function(Callback: boolean)
	        writefile(`{vape.Directory}/profiles/regionlock.txt`, tostring(Callback))
	    end,
	    Tooltip = "Dodges matches on servers outside your selected regions. These settings carry over into the match"
	})
	
	Regions = RegionLock:CreateTextList({
	    Name = "Regions",
	    Placeholder = "NA / EU / AS / OCEANIA",
	    Default = {"NA", "EU", "AS", "OCEANIA"},
	    Function = function()
	        if not Regions then
	            return
	        end
	                    
	        for i: number, v: string in Regions.List do
	            Regions.List[i] = v:gsub("%s+", ""):upper()
	        end
	
	        for i: number, v: string in Regions.ListEnabled do
	            Regions.ListEnabled[i] = v:gsub("%s+", ""):upper()
	        end
	    end,
	    Tooltip = "Turn off the regions you do not want. The server region is read from its data-center code: SG-03 counts as AS (ASIA too), AU and NZ as OCEANIA (AUS and OCE too), US-CA as NA. Leaving every region on accepts anything"
	})
	if RegionLock.Share then
	    RegionLock:Share("regionlock")
	end
end)

Run(function()
	local Registry: any = {Loaded = {}, Loading = {}, Failures = {}, Chunks = false, Reading = false}
	local Services = {}
	for _, Name: string in {"Players", "ReplicatedStorage", "RunService", "UserInputService", "ContextActionService", "TweenService", "HttpService", "Lighting", "Workspace", "CollectionService", "MaterialService", "SoundService", "StarterGui", "GuiService", "TextService", "ContentProvider", "AssetService", "CaptureService", "Debris", "CoreGui", "ProximityPromptService", "PhysicsService", "TextChatService", "TeleportService"} do
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
	    Version = 1, vape = vape, Kind = "Lobby", Lobby = true, PlaceId = game.PlaceId, Place = vape.Place, Directory = vape.Directory,
	    Require = require, Debug = debug, Notify = SendNotification, Registry = Registry, Services = Services,
	    Bedwars = bedwars, Store = nil, VapeEvents = nil, Entity = Entity
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
	    pcall(Core.Store.RecoverOrphans, {Yield = function()
	        Services.RunService.Heartbeat:Wait()
	    end})
	    for _, Name: string in {"replayviewer", "replayrig", "replayworld"} do
	        Services.RunService.Heartbeat:Wait()
	        Registry.Get(Name)
	    end
	end)
end)

Run(function()
	local SetEmote
	local Emote
	local Track: AnimationTrack?
	local Billboard: BillboardGui?
	local Moved: RBXScriptConnection?
	
	local List, EmoteTypes = {}, {}
	for EmoteType: any, v: any in bedwars.EmoteMeta do
	    if EmoteType ~= bedwars.EmoteType.NONE and v.name and not EmoteTypes[v.name] then
	        EmoteTypes[v.name] = EmoteType
	        table.insert(List, v.name)
	    end
	end
	table.sort(List)
	
	local function CancelEmote()
	    if Moved then
	        Moved:Disconnect()
	        Moved = nil
	    end
	    if Track then
	        Track:Stop()
	        Track:Destroy()
	        Track = nil
	    end
	    if Billboard then
	        Billboard:Destroy()
	        Billboard = nil
	    end
	
	    local Maid = bedwars.EmoteController and bedwars.EmoteController.emoteAudioMaids and bedwars.EmoteController.emoteAudioMaids[LocalPlayer.UserId]
	    if Maid then
	        Maid:DoCleaning()
	    end
	
	    if Entity.isAlive and LocalPlayer.Character:GetAttribute("PlayingEmote") then
	        LocalPlayer.Character:SetAttribute("PlayingEmote", nil)
	    end
	end
	
	SetEmote = vape.Categories.Utility:CreateModule({
	    Name = "SetEmote",
	    Function = function(Callback: boolean)
	        if Callback then
	            SetEmote:Toggle()
	            if Entity.isAlive then
	                local EmoteType = EmoteTypes[Emote.Value]
	                local Meta = bedwars.EmoteMeta[EmoteType]
	                if Meta then
	                    LocalPlayer.Character:SetAttribute("PlayingEmote", EmoteType)
	                    local PlayBeginSounds = bedwars.EmoteController and (bedwars.EmoteController.createEmoteBeginAudioPlayers or bedwars.EmoteController.playEmoteBeginSounds)
	                    if PlayBeginSounds then
	                        PlayBeginSounds(bedwars.EmoteController, EmoteType, LocalPlayer)
	                    end
	                    local Animation = Meta.animation
	                    if not Animation and Meta.emoteDisplayType then
	                        local Display = bedwars.EmoteDisplayMeta[Meta.emoteDisplayType]
	                        Animation = Display and Display.animation
	                    end
	                    if Animation then
	                        Track = LocalPlayer.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(Animation.type))
	                        Track.Looped = Animation.looped or false
	                        Track:Play(nil, nil, Animation.speed or 1)
	                    end
	                    if not Meta.animation then
	                        local Gui: BillboardGui = Instance.new("BillboardGui")
	                        Billboard = Gui
	                        Gui.Size = UDim2.fromScale(6, 2.5)
	                        Gui.StudsOffset = Vector3.new(0, 2, 0)
	                        Gui.AlwaysOnTop = true
	                        Gui.Adornee = LocalPlayer.Character.Head
	
	                        local Image: ImageLabel = Instance.new("ImageLabel")
	                        Image.AnchorPoint = Vector2.new(0.5, 1)
	                        Image.Position = UDim2.fromScale(0.5, 1)
	                        Image.Size = UDim2.fromScale(0, 0)
	                        Image.Image = Meta.image
	                        Image.BackgroundTransparency = 1
	                        Image.ImageTransparency = 1
	                        Image.ScaleType = Enum.ScaleType.Fit
	                        Image.Parent = Gui
	
	                        Gui.Parent = LocalPlayer.Character.Head
	                        TweenService:Create(Image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
	                            Position = UDim2.fromScale(0.5, 0.5),
	                            Size = UDim2.fromScale(1, 1),
	                            ImageTransparency = 0
	                        }):Play()
	                    end
	                    if Meta.allowMovement then
	                        task.delay(6, CancelEmote)
	                    else
	                        Moved = LocalPlayer.Character.Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(CancelEmote)
	                    end
	                end
	            end
	        end
	    end,
	    Tooltip = "Plays the selected emote on your character, other players can see it too"
	})
	
	Emote = SetEmote:CreateDropdown({
	    Name = "Emote",
	    List = List,
	    Default = "nightmare"
	})
end)