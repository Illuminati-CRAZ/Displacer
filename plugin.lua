SV_INCREMENT = .125
--debug = "hi"

function draw()
    imgui.Begin("Displacer")

    state.IsWindowHovered = imgui.IsWindowHovered()
    
    local displacement = state.GetValue("displacement") or 0
    
    --imgui.Text(debug)
    imgui.Text(#state.SelectedHitObjects .. " hit objects selected")
    
    _, displacement = imgui.InputFloat("Displacement", displacement, 1)
    tooltip("Distance to displace selected hit objects by\n1 unit = 1 ms at 1x SV")
    
    if imgui.Button("Displace") then displace(displacement) end
    if imgui.Button("Clean SVs") then cleanSV() end
    tooltip("Removes redundant SVs")
    
    imgui.TextDisabled("Update current plugin.lua file with the one in\nthe actionbatch folder when action batches are\nimplemented")
    imgui.TextDisabled("It'll probably work in that update")
    
    state.SetValue("displacement", displacement)

    imgui.End()
end

function displace(displacement)
    for _, note in pairs(state.SelectedHitObjects) do
        local time = note.StartTime
        increaseSV(time - SV_INCREMENT, displacement / SV_INCREMENT)
        increaseSV(time, -2 * displacement / SV_INCREMENT)
        increaseSV(time + SV_INCREMENT, displacement / SV_INCREMENT)
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

    if time == sv.StartTime then
        actions.RemoveScrollVelocity(sv)
        actions.PlaceScrollVelocity(utils.CreateScrollVelocity(time, sv.Multiplier + multiplier))
    else
        actions.PlaceScrollVelocity(utils.CreateScrollVelocity(time, sv.Multiplier + multiplier))
    end
end

function cleanSV()
    local redundants = {}
    local prevmult = 1
    
    for _, sv in pairs(map.ScrollVelocities) do
        if sv.Multiplier == prevmult then
            table.insert(redundants, sv)
        end
        prevmult = sv.Multiplier
    end
    
    actions.RemoveScrollVelocityBatch(redundants)
end

function tooltip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end
