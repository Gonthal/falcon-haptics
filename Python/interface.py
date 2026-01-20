import dearpygui.dearpygui as dpg
import asyncio
import threading
import queue
from server_handler import start_server
from widgets.pos_widget import update_pos_display
from widgets.plots_widget import update_plot_data
from widgets.effects_widget import update_visualizer
from tabs.sandbox_tab import create_sandbox_tab
from tabs.application_tab import ApplicationTab

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
        with dpg.tab(label="App"):
            app_tab = ApplicationTab(queue_to_falcon=command_queue)
            app_tab.render()



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

# Start the server in a separate thread.
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
    # DRAIN THE QUEUE
    latest_pos = None

    # Keep getting items until the queue is empty
    while not data_queue.empty():
        try:
            latest_pos = data_queue.get_nowait()
        except queue.Empty:
            break

    # If we got at least one packet, update the GUI with the LATEST one
    if latest_pos:
        x, y, z = latest_pos
        
        update_pos_display(x, y, z)
        update_plot_data(new_x=x, new_y=y, new_z=z)
        update_visualizer(x_pos=x, y_pos=y, z_pos=z)
        app_tab.update_loop(x, y, z)

    # Check if the PyVista window was closed by the user
    if hasattr(app_tab, 'plotter'):
        if app_tab.plotter.render_window is None:
            print("3D Window was closed by user.")
            # Optional: break the loop here for the whole app to close down
            # break

    dpg.render_dearpygui_frame()

print("DearPyGUI render loop finished.")
# AFTER the loop finishes (User closed DPG Window)
if hasattr(app_tab, 'plotter') and not app_tab.plotter.closed:
    app_tab.plotter.close()
dpg.destroy_context()