import dearpygui.dearpygui as dpg
import asyncio
import threading
import queue
from server_handler import start_server
from widgets.pos_widget import update_pos_display
from widgets.plots_widget import update_plot_data
from widgets.effects_widget import update_visualizer
from tabs.sandbox_tab import create_sandbox_tab

# 1. Create the thread-safe queue that will be shared between the server and GUI
# The server thread will 'put' data into it, and the GUI thread will 'get' data from it.
# Create a separate queue to send commands from the GUI to the server
data_queue = queue.Queue()
command_queue = queue.Queue()

def send_test_command():
    """
    Callback funtion for our new test button.
    """
    print("Queueing command for client...")
    # We can send any data structure. A dictionary is a good choice.
    # Let's use 1 for "CMD_PRINT_STATUS" and a dummy payload.
    command_to_send = {
        "type": 1, # Corresponds to CMD_PRINT_STATUS
        "payload": [1.0, 2.0, 3.0] # Dummy payload for now
    }
    command_queue.put(command_to_send)

# --- GUI Setup ---
dpg.create_context()

with dpg.window(label="erishito puede sher", tag="primary_window", width=1500, height=800):
    # Create a tab bar that will hold all the main tabs
    with dpg.tab_bar(tag="main_tab_bar"):
        # Sandbox tab: kinematics, plots, haptic effects
        create_sandbox_tab(parent_tab_bar="main_tab_bar", command_queue=command_queue)

        # Placeholder tab
        with dpg.tab(label="Settings"):
            dpg.add_text("This is the Settings tab")
            dpg.add_button(label="Send test command to Falcon", callback=send_test_command)



# --- Server and threading setup ---

def run_server_in_thread() -> None:
    """
    This function is the target for our background thread.
    It creates and runs the asyncio event loop for the server.
    """
    print("Starting server thread...")
    try:
        asyncio.run(start_server(data_queue, command_queue))
    except Exception as e:
        print(f"Error in server thread: {e}")

# 2. Start the server in a separate thread.
# By setting 'daemon=True', the thread will automatically shut down
# when the main program (the GUI) exits.
print("Setting up server thread...")
server_thread = threading.Thread(target=run_server_in_thread, daemon=True)
server_thread.start()
print("Server thread started.")

# --- DearPyGUI Main Loop ---
dpg.create_viewport(title='GUI Control Panel', width=1300, height=800)
dpg.setup_dearpygui()
dpg.show_viewport()
dpg.set_primary_window("primary_window", True)

print("Starting DearPyGUI render loop...")
while dpg.is_dearpygui_running():
    # 3. On every frame, check the queue for new data from the server thread
    try:
        # 'get_nowait()' is non-blocking. It gets an item if one is inmediately
        # available, otherwise, it raises a queue.Empty exception
        x, y, z = data_queue.get_nowait()
        # If we successfully got data, update the display
        # This is the ONLY place you should call GUI update functions.
        # Update sliders
        update_pos_display(x, y, z)
        
        # Update the plots with all 3 axes
        update_plot_data(new_x=x, new_y=y, new_z=z)

        mouse_x, mouse_y = dpg.get_drawing_mouse_pos()
        # Update the shape size based on Z
        update_visualizer(x_pos=x, y_pos=y, z_pos=z)

    except queue.Empty:
        # This is the nomal case when no new data has arrived since the last frame
        # We simply do nothing and continue on to rendering
        pass

    dpg.render_dearpygui_frame()

print("DearPyGUI render loop finished.")
dpg.destroy_context()