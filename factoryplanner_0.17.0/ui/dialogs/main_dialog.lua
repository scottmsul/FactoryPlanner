require("mod-gui")
require("ui.util")
require("ui.listeners")
require("modal_dialog")
require("preferences_dialog")
require("ui.elements.actionbar")
require("ui.elements.subfactory_bar")
require("ui.elements.error_bar")
require("ui.elements.subfactory_pane")
require("ui.elements.production_pane")


-- Create the always-present GUI button to open the main dialog + devmode setup
function player_gui_init(player)
    local frame_flow = mod_gui.get_button_flow(player)
    if not frame_flow["fp_button_toggle_interface"] then
        frame_flow.add
        {
            type = "button",
            name = "fp_button_toggle_interface",
            caption = "FP",
            tooltip = {"tooltip.open_main_dialog"},
            style = mod_gui.button_style
        }
    end

    -- Incorporates the mod setting for the visibility of the toggle-main-dialog-button
    toggle_button_interface(player)
    -- Calculates the main dialog size incorporating the relevant user settings
    ui_util.recalculate_main_dialog_dimensions(player)
end

-- Destroys all GUI's so they are loaded anew the next time they are shown
-- (Doesn't consider new preserved GUI's, but whatever)
function player_gui_reset(player)
    local center = player.gui.center
    local guis = {
        mod_gui.get_button_flow(player),
        center["fp_main_dialog"],
        center["fp_frame_modal_dialog"],
        center["fp_frame_modal_dialog_recipe_picker"]
    }
    for _, gui in pairs(guis) do 
        if gui ~= nil and gui.valid then gui.destroy() end
    end
end


-- Toggles the visibility of the toggle-main-dialog-button
function toggle_button_interface(player)
    local enable = settings.get_player_settings(player)["fp_display_gui_button"].value
    mod_gui.get_button_flow(player)["fp_button_toggle_interface"].visible = enable
end


-- Toggles the main dialog open and closed
function toggle_main_dialog(player)
    local center = player.gui.center
    -- Won't toggle if a modal dialog is open
    if global.players[player.index].modal_dialog_type == nil then
        local main_dialog = center["fp_main_dialog"]
        if main_dialog == nil then
            create_main_dialog(player)
            center["fp_main_dialog"].visible = true  -- Strangely isn't set right away
        else
            -- Only refresh it when you make it visible
            if not main_dialog.visible then refresh_main_dialog(player) end
            main_dialog.visible = (not main_dialog.visible)
        end
    end
end

-- Refreshes all variable GUI-panes (refresh-hierarchy, subfactory_bar refreshes everything below it)
-- Also refreshes the dimensions by reloading the dialog, if the flag is set
function refresh_main_dialog(player, refresh_dimensions)
    local main_dialog = player.gui.center["fp_main_dialog"]
    if refresh_dimensions then
        ui_util.recalculate_main_dialog_dimensions(player)
        if main_dialog ~= nil then
            local visible = main_dialog.visible
            main_dialog.destroy()
            toggle_main_dialog(player)
            player.gui.center["fp_main_dialog"].visible = visible
        end
    else
        if main_dialog ~= nil then
            refresh_actionbar(player)
            refresh_subfactory_bar(player, true)
        end
    end
end

-- Constructs the main dialog
function create_main_dialog(player)
    local main_dialog_dimensions = global.players[player.index].main_dialog_dimensions
    local main_dialog = player.gui.center.add{type="frame", name="fp_main_dialog", direction="vertical"}
    main_dialog.style.minimal_width = main_dialog_dimensions.width
    main_dialog.style.minimal_height = main_dialog_dimensions.height

    add_titlebar_to(main_dialog)
    add_actionbar_to(main_dialog)
    add_subfactory_bar_to(main_dialog)
    add_error_bar_to(main_dialog)
    add_subfactory_pane_to(main_dialog)
    add_production_pane_to(main_dialog)
end


-- Queues the caption of the general hint to be displayed on the next refresh
function queue_hint_message(player, message)
    global.players[player.index].queued_hint_message = message
end

-- Refreshes the general hint that is displayed next to the main dialog title
function refresh_hint_message(player)
    local player_table = global.players[player.index]
    local label_hint = player.gui.center["fp_main_dialog"]["flow_titlebar"]["label_titlebar_hint"]
    label_hint.caption = player_table.queued_hint_message
    player_table.queued_hint_message = ""
end


-- Creates the titlebar including name and exit-button
function add_titlebar_to(main_dialog)
    local titlebar = main_dialog.add{type="flow", name="flow_titlebar", direction="horizontal"}
    
    -- Title
    local label_title = titlebar.add{type="label", name="label_titlebar_name", caption=" Factory Planner"}
    label_title.style.font = "fp-font-bold-26p"

    -- Hint
    local label_hint = titlebar.add{type="label", name="label_titlebar_hint", 
      caption=global.players[main_dialog.player_index].queued_hint_message}
    label_hint.style.font = "fp-font-16p"
    ui_util.set_label_color(label_hint, "red")
    label_hint.style.top_margin = 8
    label_hint.style.left_margin = 14

    -- Spacer
    local flow_spacer = titlebar.add{type="flow", name="flow_titlebar_spacer", direction="horizontal"}
    flow_spacer.style.horizontally_stretchable = true

    -- Buttonbar
    local flow_buttonbar = titlebar.add{type="flow", name="flow_titlebar_buttonbar", direction="horizontal"}
    flow_buttonbar.style.top_margin = 4

    flow_buttonbar.add{type="button", name="fp_button_titlebar_preferences", caption={"label.preferences"},
      style="fp_button_titlebar"}

    local button_exit = flow_buttonbar.add{type="button", name="fp_button_titlebar_exit", caption="X",
      style="fp_button_titlebar"}
    button_exit.style.font = "fp-font-bold-16p"
    button_exit.style.width = 34
    button_exit.style.left_margin = 4
end