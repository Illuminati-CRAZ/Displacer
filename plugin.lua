SV_INCREMENT = .125
USE_TIME = false
--debug = "hi"

function draw()
    imgui.Begin("Displacer")

    state.IsWindowHovered = imgui.IsWindowHovered()
    
    resetQueue()
    resetCache()

    local displacement = state.GetValue("displacement") or 0

    --imgui.Text(debug)
    imgui.Text(#state.SelectedHitObjects .. " hit objects selected")

    if USE_TIME then
        if imgui.Button("Current") then displacement = state.SongTime end
        imgui.SameLine()
    end
    _, displacement = imgui.InputFloat(getDisplacementText(), displacement, 1)
    tooltip("Distance to displace selected hit objects by\n1 unit = 1 ms at 1x SV")
    
    _, SV_INCREMENT = imgui.InputFloat("Increment", SV_INCREMENT, 2^-6)

    if imgui.Button("Displace") then 
        if USE_TIME then
            local origin = getPositionFromTime(state.SelectedHitObjects[1].StartTime)
            local dest = getPositionFromTime(displacement) --displacement is time when USE_TIME == true
            displace((dest - origin) / 100)
        else
            displace(displacement)
        end
    end
    
    imgui.SameLine()
    _, USE_TIME = imgui.Checkbox("Displace to given time?", USE_TIME)
    
    if imgui.Button("Clean SVs") then cleanSV() end
    tooltip("Removes redundant SVs")
    
    performQueue()

    state.SetValue("displacement", displacement)

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

function resetQueue()
    action_queue = {} --list of actions
    add_sv_queue = {} --list of svs
    remove_sv_queue = {} --list of svs
end

function performQueue()
    --create batch actions and add them to queue
    if #remove_sv_queue > 0 then queue(action_type.RemoveScrollVelocityBatch, remove_sv_queue) end
    if #add_sv_queue > 0 then queue(action_type.AddScrollVelocityBatch, add_sv_queue) end
    
    --perform actions in queue
    if #action_queue > 0 then actions.PerformBatch(action_queue) end
end

function mergeSVs(svs)
    --for each sv given, increase map sv if no sv at that time
    for _, sv in pairs(svs) do
        --assumes initial scroll velocity is 1
        local mapsv = map.GetScrollVelocityAt(sv.StartTime) or utils.CreateScrollVelocity(-1e304, 1)
        if mapsv.StartTime ~= sv.StartTime then
            table.insert(add_sv_queue, utils.CreateScrollVelocity(sv.StartTime, mapsv.Multiplier + sv.Multiplier))
        end
    end
    
    --merging starts at first given sv, with map sv's before not changing
    local start = svs[1].StartTime
    
    --merging stops at last sv if last sv has velocity 0, otherwise stops at an sv with time infinity and velocity 0
    local stop
    if svs[#svs].Multiplier == 0 then
        stop = svs[#svs].StartTime
    else
        table.insert(svs, utils.CreateScrollVelocity(1e304, 0))
        stop = 1e304
    end

    local i = 1 --for keeping track of the relevant given sv
    
    --for each map sv within [start, stop), change according to relevant given sv
    for _, mapsv in pairs(map.ScrollVelocities) do
        if start <= mapsv.StartTime and mapsv.StartTime < stop then
            --make sure current map sv is between relevant given sv and next given sv
            while mapsv.StartTime >= svs[i+1].StartTime do
                i = i + 1
            end
            
            --in extreme cases with a bunch of different svs
            --removing then adding should be more efficient than directly changing
            --https://discord.com/channels/354206121386573824/810908988160999465/815724948256456704
            table.insert(remove_sv_queue, mapsv)
            table.insert(add_sv_queue, utils.CreateScrollVelocity(mapsv.StartTime, mapsv.Multiplier + svs[i].Multiplier))
        end
    end
end

function sv(time, multiplier) return utils.CreateScrollVelocity(time, multiplier) end

function displace(displacement)
    local svs = {}
    
    for _, time in pairs(getUniqueTimesFromNotes(state.SelectedHitObjects)) do
        table.insert(svs, sv(time - SV_INCREMENT, displacement / SV_INCREMENT))
        table.insert(svs, sv(time, -1 * displacement / SV_INCREMENT))
        table.insert(svs, sv(time + SV_INCREMENT, 0))
    end
    
    mergeSVs(svs)
end

function getUniqueTimesFromNotes(notes)
    local times = {}
    
    local lasttime = -1e304
    for _, note in pairs(notes) do
        if note.StartTime > lasttime then
            table.insert(times, note.StartTime)
            lasttime = note.StartTime
        end
    end
    
    return times
end

function cleanSV()
    local svs = map.ScrollVelocities
    local prevmult = 1
    local prevtime = -1e304

    for i, sv in pairs(svs) do
        if sv.Multiplier == prevmult then
            table.insert(remove_sv_queue, sv)
        elseif sv.StartTime == prevtime then
            table.insert(remove_sv_queue, svs[i - 1])
        end
        
        prevmult = sv.Multiplier
        prevtime = sv.StartTime
    end
end

function tooltip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

function resetCache()
    position_cache = {}
end

function getPositionFromTime(time, svs)
    --for some reason, after adding svs to the map,
    --if there are enough svs, the svs will take too long to be sorted by the game
    --and as a result, position would be calculated incorrectly
    --this can be prevented by supplying a custom sorted list of svs
    local svs = svs or map.ScrollVelocities
    
    if #svs == 0 or time < svs[1].StartTime then
        return math.floor(time * 100)
    end
    
    local i = getScrollVelocityIndexAt(time, svs)
    local position = getPositionFromScrollVelocityIndex(i, svs)
    position = position + math.floor((time - svs[i].StartTime) * svs[i].Multiplier * 100)
    return position
end

function getPositionFromScrollVelocityIndex(i, svs)
    if i < 1 then return end
    
    local position = position_cache[i]
    if i == 1 then position = math.floor(svs[1].StartTime * 100) end
    
    if not position then
        svs = svs or map.ScrollVelocities
        position = getPositionFromScrollVelocityIndex(i - 1, svs) + 
                 math.floor((svs[i].StartTime - svs[i - 1].StartTime) * svs[i - 1].Multiplier * 100)
        position_cache[i] = position
    end

    return position
end

function getScrollVelocityIndexAt(time, svs)
    svs = svs or map.ScrollVelocities
    table.insert(svs, sv(1e304, 1))
    
    i = 1
    while svs[i].StartTime <= time do
        i = i + 1
    end
    
    return i - 1
end