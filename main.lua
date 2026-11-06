local License = ... or {}

-- Bypass Developer Mode
shared.vapedeveloper = true
shared.VapeDeveloper = true
shared.maincat = nil 
License.Key = "BYPASSED"

local Directory = "catprivate"

-- ==========================================
-- CONFIGURE YOUR GITHUB REPO HERE
-- ==========================================
local GithubUser = "YOUR_USERNAME"
local GithubRepo = "YOUR_REPO_NAME"
local GithubBranch = "main"
local GithubBase = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GithubUser, GithubRepo, GithubBranch)
-- ==========================================

if not game:IsLoaded() then game.Loaded:Wait() end
if shared.vapeloading and coroutine.status(shared.vapeloading) ~= "dead" then return end
shared.vapeloading = coroutine.running()
if shared.vape then shared.vape:Uninject() end

-- Create local folders for caching
for _, Folder in {Directory, `{Directory}/games`, `{Directory}/profiles`, `{Directory}/assets`, `{Directory}/libraries`, `{Directory}/guis`} do
    if not isfolder(Folder) then makefolder(Folder) end
end

local vape, RunPremium
local loadstring = function(...)
    local Chunk, Error = loadstring(...)
    if Error and vape then vape:CreateNotification("Vape", `Failed to load : {Error}`, 30, "alert") end
    return Chunk
end

local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(FilePath)
    local Success, Contents = pcall(readfile, FilePath)
    return Success and Contents ~= nil and Contents ~= ""
end
local cloneref = cloneref or function(Reference) return Reference end
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))

-- DOWNLOAD FROM GITHUB INSTEAD OF API
local function DownloadFile(FilePath: string, Reader)
    local FileName = FilePath:gsub(`^{Directory}/`, "")
    local Url = GithubBase .. FileName
    
    -- Check if cached locally first to save bandwidth and speed up loading
    if isfile(FilePath) then
        local cached = readfile(FilePath)
        if cached and cached ~= "" then
            return cached
        end
    end
    
    -- Fetch from GitHub
    local Success, Response = pcall(function()
        return game:HttpGet(Url, true)
    end)
    
    if Success and Response and not Response:find("404: Not Found") then
        if writefile then pcall(writefile, FilePath, Response) end
        return Response
    else
        warn(`[CatVape] Failed to download {FileName} from GitHub.`)
        return ""
    end
end

local function FinishLoading()
    vape.Init = nil
    vape:Load()
    shared.vapeloading = nil

    local TeleportedServers: boolean?
    vape:Clean(Players.LocalPlayer.OnTeleport:Connect(function()
        if (not TeleportedServers) and (not shared.VapeIndependent) then
            TeleportedServers = true
            local TeleportScript = `shared.vapereload = true; shared.VapeDeveloper = true; loadstring(game:HttpGet('{GithubBase}main.lua', true), 'main')({HttpService:JSONEncode(License)})`
            vape:Save()
            queue_on_teleport(TeleportScript)
        end
    end))

    if not shared.vapereload then
        vape:CreateNotification("Finished Loading", "GitHub Bypass Loaded", 5)
    end
end

if not isfile(`{Directory}/profiles/gui.txt`) then writefile(`{Directory}/profiles/gui.txt`, "new") end
local Gui = "new"

if not isfolder(`{Directory}/assets/{Gui}`) then makefolder(`{Directory}/assets/{Gui}`) end

vape, RunPremium = loadstring(DownloadFile(`{Directory}/guis/{Gui}.lua`), "gui")(License)
shared.vape = vape
shared.vapesmooth = false
_G.vape = vape
getgenv().used_init = true

if not shared.VapeIndependent then
    loadstring(DownloadFile(`{Directory}/games/universal.lua`), "universal")(License)
    
    if isfile(`{Directory}/games/{game.PlaceId}.lua`) then
        loadstring(readfile(`{Directory}/games/{game.PlaceId}.lua`), tostring(game.PlaceId))(License)
    end
    
    loadstring(DownloadFile(`{Directory}/libraries/main.lua`), "main")(License)
    FinishLoading()
else
    vape.Init = FinishLoading
    return vape
end