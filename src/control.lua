local function ternary(condition, trueVal, falseVal)
    if condition then
        return trueVal
    end

    return falseVal
end

local function format_time_interval(total_seconds)
    -- Round up to the nearest whole number
    total_seconds = math.ceil(total_seconds)

    -- Less than 60 seconds: just return seconds
    if total_seconds < 60 then

        local secondsStr = ternary(total_seconds < 10, "0" .. total_seconds, tostring(total_seconds))

        return {"text.cc-time-remaining-ms", "00", secondsStr}

    -- Between 1 minute and 59 minutes 59 seconds
    elseif total_seconds < 3600 then
        
        local minutes = math.floor(total_seconds / 60)
        local seconds = total_seconds % 60
        
        local minutesStr = ternary(minutes < 10, "0" .. minutes, tostring(minutes))
        local secondsStr = ternary(seconds < 10, "0" .. seconds, tostring(seconds))

        return { "text.cc-time-remaining-ms", minutesStr, secondsStr }

    -- More than 59 minutes 59 seconds
    else
        local hours = math.floor(total_seconds / 3600)
        local minutes = math.floor((total_seconds % 3600) / 60)
        local seconds = total_seconds % 60

        local hoursStr = ternary(hours < 10, "0" .. hours, tostring(hours))
        local minutesStr = ternary(minutes < 10, "0" .. minutes, tostring(minutes))
        local secondsStr = ternary(seconds < 10, "0" .. seconds, tostring(seconds))
        
        return { "text.cc-time-remaining-hms", hoursStr, minutesStr, secondsStr }
    end
end

-- Utility function to check if the entity is valid, has a recipe, and is currently crafting
local function is_valid_crafting_entity(entity)
    -- Check if the entity is valid, is of a type that can have recipes, has a recipe, and is currently crafting
    if entity and entity.valid and (entity.type == "assembling-machine" or entity.type == "furnace" or entity.type == "rocket-silo" or entity.type == "chemical-plant") and entity.get_recipe() and entity.is_crafting() then
        return true
    end

    return false
end

-- Check the crafting time of the recipe
local function get_crafting_time(entity)
    local recipe = entity.get_recipe()
    local base_crafting_time = recipe.energy -- Base crafting time from the recipe

    -- Get the machine's effective crafting speed (which already accounts for modules and beacons)
    local crafting_speed = entity.crafting_speed or 1

    -- Calculate the actual crafting time by dividing the base time by the effective crafting speed
    local actual_crafting_time = base_crafting_time / crafting_speed

    return actual_crafting_time
end

-- Function to remove the overlay when no entity is hovered
local function clear_overlay()
    if storage.overlay and storage.overlay.render_id then
        storage.overlay.render_id.destroy()
    end

    storage.overlay = nil
end

local function update_overlay(overlay)
  overlay.render_id.text = format_time_interval(overlay.time_left)
  overlay.render_id.time_to_live = 300
end

-- Function to handle when the player hovers over an entity
local function on_entity_hovered(entity, player)
    if storage.enabled and is_valid_crafting_entity(entity) then
        local total_crafting_time = get_crafting_time(entity)
        local progress = entity.crafting_progress or 0
        local remaining_time = total_crafting_time * (1 - progress)

        if remaining_time > 0 and total_crafting_time >= settings.get_player_settings(player)["cc-minimum-recipe-energy"].value then
           
            if not storage.overlay then
                -- Create a new overlay for this entity
                storage.overlay = {
                    entity = nil,
                    time_left = nil,
                    render_id = nil
                }
            end

            storage.overlay.entity = entity
            storage.overlay.time_left = remaining_time

            if (storage.overlay.render_id and rendering.is_valid(storage.overlay.render_id)) then
                -- Update the overlay
                update_overlay(storage.overlay)
            else
              storage.overlay.render_id = rendering.draw_text{
                    time_to_live = 300,
                    text = format_time_interval(remaining_time),
                    surface = entity.surface,
                    target = entity,
                    target_offset = {0, 2}, -- Adjusted offset for middle-bottom positioning with slight upward shift
                    color = {r=1, g=1, b=1},
                    alignment = "center",
                    vertical_alignment = "bottom",
                    scale = 1.5, -- Increased font size
                    scale_with_zoom = true,
                    players = {player.index},
                    forces = {player.force}-- This will store the rendering ID
                }
            end
        end
    else
        clear_overlay()
    end
end

local function toggle(event)
    local player = game.players[event.player_index]

    -- Toggle the overlay state
    storage.enabled = not storage.enabled

    if not storage.enabled then
        -- Clear any existing overlay
        clear_overlay()
    else
        local hovered_entity = player.selected
        on_entity_hovered(hovered_entity, player)
    end

    player.set_shortcut_toggled('cc-toggle', storage.enabled == true)
end

-- Event handlers for buttons
script.on_event(defines.events.on_gui_click, function(event)
    local player = game.players[event.player_index]
    
    -- Handle Close button
    if event.element.name == "tracked_entities_close_button" then
      player.gui.screen.tracked_entities_window.destroy()
    end
  
    -- Handle Pin button
    if event.element.name == "tracked_entities_pin_button" then
      local window = player.gui.screen.tracked_entities_window
      if window.drag_target then
        -- Unpin the window (make draggable)
        window.drag_target = nil
        player.print("Window unpinned, now draggable!")
      else
        -- Pin the window (disable dragging)
        window.drag_target = window
        player.print("Window pinned, now immovable!")
      end
    end
  end)

-- Event handler for when the player's selected entity changes (hover)
script.on_event(defines.events.on_selected_entity_changed, function(event)
    local player = game.players[event.player_index]
    local hovered_entity = player.selected

    -- Clear any existing overlay
    clear_overlay()

    -- If the player is hovering over an entity, attempt to create an overlay
    if hovered_entity then
        on_entity_hovered(hovered_entity, player)
    end
end)

-- Initialize the storage table for crafting overlays
script.on_init(function()
    storage.enabled = trueeerre
end)


script.on_event(defines.events.on_player_created, function(event)
    game.players[event.player_index].set_shortcut_toggled('cc-toggle', storage.enabled == true)
    --create_tracked_entities_window(game.players[event.player_index])
end)

-- Event handler for keyboard shortcut (toggle overlay on/off)
script.on_event({"cc-toggle", defines.events.on_lua_shortcut}, function(event)
    if (event.input_name or event.prototype_name) == "cc-toggle" then
        toggle(event)
    end
end)

-- Update the countdown overlay every second if it exists
script.on_nth_tick(60, function()
    local overlay = storage.overlay

    if overlay and is_valid_crafting_entity(overlay.entity) then
        -- Calculate the time left
        local progress = overlay.entity.crafting_progress or 0
        overlay.time_left = get_crafting_time(overlay.entity) * (1 - progress)

        -- Update the overlay if time_left is still above zero
        if overlay.time_left > 0 and overlay.render_id and rendering.get_object_by_id(overlay.render_id.id) then
            update_overlay(overlay)
        else
            clear_overlay()
        end
    else
        clear_overlay()
    end
end)