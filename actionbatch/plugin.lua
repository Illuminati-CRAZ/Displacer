SV_INCREMENT = .125
--debug = "hi"

function draw()
    imgui.Begin("Displacer")
    action_queue = {}

    state.IsWindowHovered = imgui.IsWindowHovered()

    local displacement = state.GetValue("displacement") or 0

    --imgui.Text(debug)
    imgui.Text(#state.SelectedHitObjects .. " hit objects selected")

    _, displacement = imgui.InputInt("Displacement", displacement)
    tooltip("Distance to displace selected hit objects by\n1 unit = 1 ms at 1x SV")

    if imgui.Button("Displace") then displace(displacement) end
    if imgui.Button("Clean SVs") then cleanSV() end
    tooltip("Removes redundant SVs")

    state.SetValue("displacement", displacement)

    if #action_queue > 0 then actions.PerformBatch(action_queue) end
    imgui.End()
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