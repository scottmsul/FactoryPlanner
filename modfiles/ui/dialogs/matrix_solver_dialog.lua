matrix_solver_dialog = {}

local function get_item(item_id)
    local split_string = split_string(item_id, "_")
    local item_type_id = split_string[1]
    local item_id = split_string[2]
    return global.all_items.types[item_type_id].items[item_id]
end

-- item_variable_type is either "eliminated" or "free"
local function get_item_button(item_id, item_variable_type, linear_dependence_data)
    local style=nil
    if linear_dependence_data.linearly_dependent_items[item_id] then
        style = "fp_button_icon_large_red"
    elseif linear_dependence_data.potential_free_items[item_id] then
        style = "fp_button_icon_large_green"
    elseif item_variable_type=="free" or item_variable_type=="eliminated" then
        style = "fp_button_icon_large_recipe" -- recipe just makes it look like a button
    else
        style = "fp_button_icon_large_blank"
    end
    local item = get_item(item_id)
    return {
        type="sprite-button",
        name="fp_sprite-button_matrix_solver_item_"..item_variable_type.."_"..item_id,
        sprite=item.sprite,
        tooltip=item.localised_name,
        style=style
    }
end

local function update_dialog_submit_button(modal_data)
    local message = nil

    local num_rows = #modal_data.ingredients + #modal_data.products + #modal_data.byproducts + #modal_data.eliminated_items + #modal_data.free_items
    local num_cols = #modal_data.recipes + #modal_data.ingredients + #modal_data.byproducts + #modal_data.free_items
    if num_rows ~= num_cols then
        -- TODO: move to config
        message = "Number of rows must match number of columns"
    elseif ((next(modal_data.linear_dependence_data.linearly_dependent_recipes) ~= nil)
                or (next(modal_data.linear_dependence_data.linearly_dependent_items) ~= nil)) then
        message = "Columns must be linearly independent"
    end

    modal_dialog.set_submit_button_state(modal_data.ui_elements, (message == nil), message)
end

local function refresh_matrix_solver_items(player, modal_data, matrix_frame)
    local ui_state = get_ui_state(player)
    local subfactory = ui_state.context.subfactory
    local linear_dependence_data = matrix_solver.get_linear_dependence_data(player, subfactory, modal_data)

    -- save this for the condition instructions
    modal_data.linear_dependence_data = linear_dependence_data

    local recipe_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_recipes"]
    local recipes = modal_data.recipes
    recipe_buttons.clear()
    for i, recipe_id in ipairs(recipes) do
        local recipe = global.all_recipes.recipes[recipe_id]
        local sprite = recipe.sprite
        local tooltip = recipe.localised_name
        local button_style
        if linear_dependence_data.linearly_dependent_recipes[recipe_id] then button_style="fp_button_icon_large_red" else button_style="fp_button_icon_large_blank" end
        recipe_buttons.add{type="sprite-button", name="fp_sprite-button_matrix_solver_recipe_"..recipe_id.."_"..i,
            sprite=sprite, tooltip=tooltip, style=button_style, enabled=false}
    end

    local ingredient_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_ingredients"]
    local ingredients = modal_data.ingredients
    ingredient_buttons.clear()
    for _, item_id in ipairs(ingredients) do
        ingredient_buttons.add(get_item_button(item_id, "ingredient", linear_dependence_data))
    end

    local product_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_products"]
    local products = modal_data.products
    product_buttons.clear()
    for _, item_id in ipairs(products) do
        product_buttons.add(get_item_button(item_id, "product", linear_dependence_data))
    end

    local byproduct_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_byproducts"]
    local byproducts = modal_data.byproducts
    byproduct_buttons.clear()
    for _, item_id in ipairs(byproducts) do
        byproduct_buttons.add(get_item_button(item_id, "byproduct", linear_dependence_data))
    end

    local free_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_free_items"]
    local free_items = modal_data.free_items
    free_buttons.clear()
    for _, item_id in ipairs(free_items) do
        free_buttons.add(get_item_button(item_id, "free", linear_dependence_data))
    end

    local eliminated_buttons = matrix_frame["flow_matrix_solver_items"]["flow_matrix_solver_eliminated_items"]
    local eliminated_items = modal_data.eliminated_items
    eliminated_buttons.clear()
    for _, item_id in ipairs(eliminated_items) do
        eliminated_buttons.add(get_item_button(item_id, "eliminated", linear_dependence_data))
    end

    local num_rows = #ingredients + #products + #byproducts + #eliminated_items + #free_items
    matrix_frame["flow_matrix_solver_items"]["label_num_rows"].caption = {"", {"fp.matrix_solver_total_rows"}, ": ", num_rows}
    local num_cols = #recipes + #ingredients + #byproducts + #free_items
    matrix_frame["flow_matrix_solver_items"]["label_num_cols"].caption = {"", {"fp.matrix_solver_total_cols"}, ": ", num_cols}

    update_dialog_submit_button(modal_data)
end

local function handle_matrix_solver_free_item_press(player, item_id)
    local modal_data = data_util.get("modal_data", player)
    matrix_solver.remove(modal_data.free_items, item_id)
    matrix_solver.insert(modal_data.eliminated_items, item_id)
    local ui_elements = modal_data.ui_elements
    local matrix_frame = ui_elements.matrix_frame
    refresh_matrix_solver_items(player, modal_data, ui_elements.matrix_frame)
end

local function handle_matrix_solver_eliminated_item_press(player, item_id)
    local modal_data = data_util.get("modal_data", player)
    matrix_solver.remove(modal_data.eliminated_items, item_id)
    matrix_solver.insert(modal_data.free_items, item_id)
    local ui_elements = modal_data.ui_elements
    local matrix_frame = ui_elements.matrix_frame
    refresh_matrix_solver_items(player, modal_data, ui_elements.matrix_frame)
end

-- ** TOP LEVEL **
matrix_solver_dialog.dialog_settings = (function(_) return {
    caption="fp.matrix_solver_title",
    create_content_frame = true,
    force_auto_center = true
} end)

-- todo: add buttons
matrix_solver_dialog.gui_events = {
    on_gui_click = {
        {
            pattern = "^fp_sprite%-button_matrix_solver_item_free_%d+_%d+$",
            timeout = 20, --not sure what this does, recipe_dialog has it
            handler = (function(player, element, _)
                local split_string = split_string(element.name, "_")
                local item_id = split_string[7].."_"..split_string[8]
                handle_matrix_solver_free_item_press(player, item_id)
            end)
        },
        {
            pattern = "^fp_sprite%-button_matrix_solver_item_eliminated_%d+_%d+$",
            timeout = 20, --not sure what this does, recipe_dialog has it
            handler = (function(player, element, _)
                local split_string = split_string(element.name, "_")
                local item_id = split_string[7].."_"..split_string[8]
                handle_matrix_solver_eliminated_item_press(player, item_id)
            end)
        }
    }
}

function matrix_solver_dialog.open(player, modal_data)
    -- local flow = flow_modal_dialog["flow_matrix_solver_items"]
    local ui_elements = modal_data.ui_elements
    
    -- literally copied from modules_dialog, no idea what I'm doing
    local function add_bordered_frame()
        local frame = ui_elements.content_frame.add{type="frame", style="fp_frame_bordered_stretch"}
        frame.style.padding = 8
        return frame
    end
    
    local matrix_frame = add_bordered_frame()
    ui_elements.matrix_frame = matrix_frame

    flow = matrix_frame.add{type="flow", name="flow_matrix_solver_items", direction="vertical"}
    flow.style.bottom_margin=12

    flow.add{type="label", name="label_recipes", caption={"fp.matrix_solver_recipes"}}
    flow.add{type="flow", name="flow_matrix_solver_recipes", direction="horizontal"}

    flow.add{type="label", name="label_ingredients", caption={"fp.matrix_solver_ingredients"}}
    flow.add{type="flow", name="flow_matrix_solver_ingredients", direction="horizontal"}

    flow.add{type="label", name="label_products", caption={"fp.matrix_solver_products"}}
    flow.add{type="flow", name="flow_matrix_solver_products", direction="horizontal"}

    flow.add{type="label", name="label_byproducts", caption={"fp.matrix_solver_byproducts"}}
    flow.add{type="flow", name="flow_matrix_solver_byproducts", direction="horizontal"}

    flow.add{type="label", name="label_eliminated_items", caption={"fp.matrix_solver_eliminated"}}
    flow.add{type="flow", name="flow_matrix_solver_eliminated_items", direction="horizontal"}

    flow.add{type="label", name="label_free_items", caption={"fp.matrix_solver_free"}}
    flow.add{type="flow", name="flow_matrix_solver_free_items", direction="horizontal"}

    flow.add{type="label", name="label_num_rows"}
    flow.add{type="label", name="label_num_cols"}

    refresh_matrix_solver_items(player, modal_data, matrix_frame)
end

function matrix_solver_dialog.close(player, action)
    local modal_data = data_util.get("modal_data", player)
    local subfactory = data_util.get("context", player).subfactory
    if action == "submit" then
        local ui_state = get_ui_state(player)
        local refresh = modal_data["refresh"]

        calculation.run_matrix_solver(player, subfactory, modal_data.free_items, refresh)
    end
end

