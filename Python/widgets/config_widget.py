import dearpygui.dearpygui as dpg
import queue

# 
EFFECT_IDS = {
    "No haptics": 0,
    "Rock": 1,
    "Sandpaper": 2,
    "Oil": 3,
    "Spring": 4,
    "Water": 5
}

def send_effect_command(sender, app_data, user_data: queue.Queue) -> None:
    """
    Callback for the radio button.
    app_data contains the string label of the selected radio button
    """
    cmd_queue = user_data
    
    # Get the integer ID from EFFECT_IDS dictionary
    selected_effect_name = app_data
    effect_id = EFFECT_IDS.get(selected_effect_name, 0)

    print(f"Queuein effect change: {selected_effect_name} (ID: {effect_id})")

    # Construct the command
    command_to_send = {
        "type": effect_id,
        "payload": [float(effect_id), 0.0, 0.0]
    }

    cmd_queue.put(command_to_send)

def send_dummy_command(sender, app_data, user_data: queue.Queue) -> None:
    """
    Callback function for the dummy command button.
    """
    cmd_queue = user_data
    print("Queueing dummy command for client...");
    command_to_send = {
        "type": 7,
        "payload": [5.0, 4.0, 3.0] # Dummy payload
    }
    cmd_queue.put(command_to_send)

def create_config_widget(parent_window, command_queue) -> None:
    """Creates the DearPyGUI widget for configuration settings."""
    dpg.add_text("Haptic effects")

    # Radio button for mutually exclusive selection
    dpg.add_radio_button(
        items=list(EFFECT_IDS.keys()), # ["No Effect", "Bumpy", ...]
        default_value="No haptics",
        callback=send_effect_command,
        user_data=command_queue,
        horizontal=False # Set to True if you want them side-by-side
    )

    dpg.add_separator()

    dpg.add_button(label="Dummy command", width=-1, callback=send_dummy_command, user_data=command_queue)
    #with dpg.child_window(parent=parent_window, width=-1, height=105):