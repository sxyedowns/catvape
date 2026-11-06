local License = ... or {Key = "_key"}
local vape = shared.vape
local Run = function(Callback)
    Callback()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local TamperHints = {"TAMPER", "INTEGRITY", "HOOK", "MODIFIED", "FORGED", "SIGNATURE", "BLACKLIST", "BANNED", "ABUSE", "CRACKED", "LEAK", "SIGNED"}

local function IsTamperError(Text: string): boolean
    local Upper: string = Text:upper()

    for _, v: string in TamperHints do
        if Upper:find(v, 1, true) then
            return true
        end
    end

    return false
end

local function FailAuth(Text: string)
    vape:CreateNotification("Cat", `Authentication error: {Text}`, 20, "alert")
    cloneref(game:GetService("Players")).LocalPlayer:Kick(`tampering detected: {Text}`)
end

if shared.VapeDeveloper and isfile(`{vape.Directory}/libraries/auth.lua`) then
    local Callback: ((...any) -> ())?, Error: string? = loadstring(readfile(`{vape.Directory}/libraries/auth.lua`), "premium")
    if not Callback then
        task.spawn(error, Error)
    else
        task.spawn(Callback, {key = License.Key})
    end
else
    local Response: HttpRequest = request({
        Url = "https://api.catvape.dev/login",
        Method = "POST",
        Body = `\{"key":"{License.Key}"\}`
    })

    if Response.StatusCode == 200 and Response.Body:find("return ") then
        local Callback: ((...any) -> ())?, Error: string? = loadstring(Response.Body, "premium")
        if not Callback then
            task.spawn(error, Error)
        else
            task.spawn(Callback)
        end
    elseif Response.StatusCode == 400 then
        local Decoded: {errors: {string}}? = HttpService:JSONDecode(Response.Body)
        if Decoded and typeof(Decoded) == "table" then
            for _, v: any in Decoded.errors[1] do
                if v == "HWID_MISMATCH" then
                    vape:CreateNotification("Cat", "HWID MISMATCH, Go to the script panel to reset hwid", 25, "alert")
                elseif IsTamperError(v) then
                    FailAuth(v)
                elseif not v:find("using a key") then
                    vape:CreateNotification("Cat", `Authentication error: {v}`, 20, "alert")
                end
            end
        end
    elseif Response.StatusCode == 404 then
        local Decoded = HttpService:JSONDecode(Response.Body)
        if typeof(Decoded) == "table" and Decoded.response then
            if Decoded.response.name == "HWID_MISMATCH" then
                getgenv().catrole = ""
                vape:CreateNotification("Cat", "HWID MISMATCH, Go to the script panel to reset hwid", 25, "alert")
            elseif IsTamperError(Decoded.response.name) or IsTamperError(Decoded.response.message) then
                FailAuth(Decoded.response.message)
            else
                vape:CreateNotification(Decoded.response.name, Decoded.response.message, 20, "alert")
            end
        end
    end
end