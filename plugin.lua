SV_INCREMENT = .125
USE_TIME = false
--debug = "hi"

function draw()
    imgui.Begin("Displacer")
    action_queue = {}

    state.IsWindowHovered = imgui.IsWindowHovered()

    local displacement = state.GetValue("displacement") or 0

    --imgui.Text(debug)
    imgui.Text(#state.SelectedHitObjects .. " hit objects selected")

    if USE_TIME then
        if imgui.Button("Current") then displacement = state.SongTime end
        imgui.SameLine()
    end
    _, displacement = imgui.InputInt(getDisplacementText(), displacement)
    tooltip("Distance to displace selected hit objects by\n1 unit = 1 ms at 1x SV")

    if imgui.Button("Displace") then 
        if USE_TIME then
            local origin = GetPositionFromTime(state.SelectedHitObjects[1].StartTime)
            local dest = GetPositionFromTime(displacement) --displacement is time when USE_TIME == true
            displace((dest - origin) / 100)
        else
            displace(displacement)
        end
    end
    
    imgui.SameLine()
    _, USE_TIME = imgui.Checkbox("Displace to given time?", USE_TIME)
    
    if imgui.Button("Clean SVs") then cleanSV() end
    tooltip("Removes redundant SVs")

    state.SetValue("displacement", displacement)

    if #action_queue > 0 then actions.PerformBatch(action_queue) end
    imgui.End()
end

function getDisplacementText()
    return USE_TIME and "Time" or "Displacement"
end

function queue(type, arg1, arg2, arg3, arg4)
    arg1 = arg1 or nil
    arg2 = arg2 or nil
    arg3 = arg3 or nil
    arg4 = arg4 or nil

    local action = utils.CreateEditorAction(type, arg1, arg2, arg3, arg4)
    table.insert(action_queue, action)
end

function displace(displacement)
    for _, note in pairs(state.SelectedHitObjects) do
        local time = note.StartTime
        increaseSV(time - SV_INCREMENT, displacement / SV_INCREMENT)
        increaseSV(time, -1 * displacement / SV_INCREMENT)
        increaseSV(time + SV_INCREMENT, 0)
    end
end

function increaseSV(time, multiplier)
    local sv
    if #map.ScrollVelocities > 0 then
        if time < map.ScrollVelocities[1].StartTime then sv = utils.CreateScrollVelocity(-1e309, 1)
        else sv = map.GetScrollVelocityAt(time) end
    else
        sv = utils.CreateScrollVelocity(-1e309, 1)
    end

    if sv.StartTime == time then
        queue(action_type.ChangeScrollVelocityMultiplierBatch, {sv}, sv.Multiplier + multiplier)
    else
        local newsv = utils.CreateScrollVelocity(time, sv.Multiplier + multiplier)
        queue(action_type.AddScrollVelocity, newsv)
    end
end

function cleanSV()
    local svs = map.ScrollVelocities
    local redundants = {}
    local prevmult = 1

    for _, sv in pairs(svs) do
        if sv.Multiplier == prevmult then
            table.insert(redundants, sv)
        end
        prevmult = sv.Multiplier
    end

    queue(action_type.RemoveScrollVelocityBatch, redundants)
end

function tooltip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

function GetPositionFromTime(time)
    --[[
        if using this function multiple times in one frame,
        it may be faster to set ScrollVelocities = map.ScrollVelocities in draw()
        and then set local svs = ScrollVelocities inside this function
    ]]
    local svs = map.ScrollVelocities

    if #svs == 0 or time < svs[1].StartTime then
        return math.floor(time * 100)
    end

    local position = math.floor(svs[1].StartTime * 100)

    local i = 2

    while i <= #svs do
        if time < svs[i].StartTime then
            break
        else
            position = position + math.floor((svs[i].StartTime - svs[i - 1].StartTime) * svs[i - 1].Multiplier * 100)
        end

        i = i + 1
    end

    i = i - 1

    position = position + math.floor((time - svs[i].StartTime) * svs[i].Multiplier * 100)
    return position
end