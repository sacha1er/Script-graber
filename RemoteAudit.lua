
-- RemoteAudit.server.lua
-- Diagnostic des RemoteEvent du jeu
-- A placer dans ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WINDOW_SECONDS = 10
local MAX_CALLS_PER_WINDOW = 40

local stats = {}
local monitored = {}

local function describe(value, depth)
    depth = depth or 0

    if depth > 2 then
        return "<profondeur maximale>"
    end

    local kind = typeof(value)

    if kind == "string" then
        return string.format("%q", string.sub(value, 1, 200))
    elseif kind == "number" or kind == "boolean" or kind == "nil" then
        return tostring(value)
    elseif kind == "Instance" then
        return value:GetFullName()
    elseif kind == "Vector3" or kind == "CFrame" then
        return tostring(value)
    elseif kind == "table" then
        local result = {}
        local count = 0

        for key, item in pairs(value) do
            count += 1
            if count > 20 then
                table.insert(result, "...")
                break
            end

            table.insert(result,
                "[" .. tostring(key) .. "]=" ..
                describe(item, depth + 1)
            )
        end

        return "{" .. table.concat(result, ", ") .. "}"
    end

    return "<" .. kind .. ">"
end

local function monitor(remote)
    if not remote:IsA("RemoteEvent") then
        return
    end

    if monitored[remote] then
        return
    end

    monitored[remote] = true

    remote.OnServerEvent:Connect(function(player, ...)
        local now = os.clock()
        local key = tostring(player.UserId)
            .. ":" .. remote:GetFullName()

        local entry = stats[key]

        if not entry or now - entry.started >= WINDOW_SECONDS then
            entry = {
                started = now,
                calls = 0,
                warned = false
            }
            stats[key] = entry
        end

        entry.calls += 1

        print(string.format(
            "[REMOTE AUDIT] Joueur=%s | Remote=%s | Appel=%d",
            player.Name,
            remote:GetFullName(),
            entry.calls
        ))

        local args = {...}
        for index, value in ipairs(args) do
            print(string.format(
                "  Argument %d: %s",
                index,
                describe(value)
            ))
        end

        if entry.calls > MAX_CALLS_PER_WINDOW
            and not entry.warned then
            entry.warned = true
            warn(string.format(
                "[REMOTE AUDIT] FREQUENCE ELEVEE : %s via %s",
                player.Name,
                remote:GetFullName()
            ))
        end
    end)
end

for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
    monitor(object)
end

ReplicatedStorage.DescendantAdded:Connect(monitor)

Players.PlayerRemoving:Connect(function(player)
    local prefix = tostring(player.UserId) .. ":"

    for key in pairs(stats) do
        if string.sub(key, 1, #prefix) == prefix then
            stats[key] = nil
        end
    end
end)

print("[REMOTE AUDIT] Surveillance activée.")
