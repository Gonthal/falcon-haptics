import dearpygui.dearpygui as dpg
import queue

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
    with dpg.child_window(parent=parent_window, width=-1, height=105):
        dpg.add_text("Falcon configuration")

        dpg.add_button(label="Dummy command", width=-1, callback=send_dummy_command, user_data=command_queue)