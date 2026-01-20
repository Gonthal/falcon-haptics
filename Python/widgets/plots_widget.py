import dearpygui.dearpygui as dpg
import time
import collections
import csv
import datetime

# --- Data storage ---
# Moving window data for the live plots (fast, fixed size)
MAX_SAMPLES = 1000
plot_t = collections.deque(maxlen=MAX_SAMPLES)
plot_x = collections.deque(maxlen=MAX_SAMPLES)
plot_y = collections.deque(maxlen=MAX_SAMPLES)
plot_z = collections.deque(maxlen=MAX_SAMPLES)

# Full history data for export (grows indefinitely)
full_history = {
    "t": [],
    "x": [],
    "y": [],
    "z": []
}

# State variables
start_time = None
t_plot = 0

def export_data_callback():
    """Saves the full history to a CSV file."""
    if not full_history["t"]:
        print("No data to export.")
        return
    
    # Generate a unique filename based on timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"falcon_data{timestamp}.csv"

    try:
        with open(filename, mode='w', newline='') as file:
            writer = csv.writer(file)
            # Write header
            writer.writerow(["Time_s", "Pos_X_cm", "Pos_Y_cm", "Pos_Z_cm"])

            # Write data rows
            # zip combines the lists into rows: (t[0], x[0], y[0], z[0]), etc.
            rows = zip(
                full_history["t"],
                full_history["x"],
                full_history["y"],
                full_history["z"]                
            )
            writer.writerows(rows)

        print(f"Succesfully exported data to {filename}")
    except Exception as e:
        print(f"Failed to export data: {e}")

def update_plot_data(new_x: float, new_y: float, new_z: float):
    """
    Called every frame by the main loop to push new sensor data.
    """

    global start_time
    # Initialize start time on first data point
    if start_time is None:
        start_time = time.time()

    current_t = time.time() - start_time

    # Update moving window (for GUI)
    plot_t.append(current_t)
    plot_x.append(new_x)
    plot_y.append(new_y)
    plot_z.append(new_z)

    # Update full history (for export)
    full_history["t"].append(current_t)
    full_history["x"].append(new_x)
    full_history["y"].append(new_y)
    full_history["z"].append(new_z)

    # Update the DPG series, all 3 series
    # Note: Lists are created from deques because DPG requires list/array types
    dpg.configure_item("series_tag_x", x=list(plot_t), y=list(plot_x))
    dpg.configure_item("series_tag_y", x=list(plot_t), y=list(plot_y))
    dpg.configure_item("series_tag_z", x=list(plot_t), y=list(plot_z))

    dpg.set_axis_limits("axis_t_z", current_t - 10, current_t)
    dpg.set_axis_limits("axis_t_y", current_t - 10, current_t)
    dpg.set_axis_limits("axis_t_x", current_t - 10, current_t)

    # Optional: Auto-fit axes periodically or on every frame if needed
    # dpg.fit_axis_data("x_axis_t")
    # (Leaving auto-fit off is usually smoother for moving windows, 
    #  let DPG handle the auto-scroll if "Auto-fit" is checked in the GUI menu)

def create_plot_widget(parent_window) -> None:
    """Creates the vertical stack of plots."""
    # Button to trigger CSV export
    dpg.add_button(label="Export to CSV", callback=export_data_callback, parent=parent_window)
    dpg.add_separator(parent=parent_window)

    # We use a subplots container to stack them nicely,
    # OR just add 3 separate plot widgets.
    # Using 3 separate widgets allows individual control easier for now

    # --- Z axis plot (Top) ---
    with dpg.plot(label="Z Axis", height=170, width=-1, parent=parent_window):
        dpg.add_plot_legend()
        # X-axis (hidden label to save space, since they align)
        dpg.add_plot_axis(dpg.mvXAxis, label="", tag="axis_t_z")
        dpg.set_axis_limits(dpg.last_item(), -10, 0)
        with dpg.plot_axis(dpg.mvYAxis, label="Z (cm)"):
            dpg.set_axis_limits(dpg.last_item(), -7, 3)
            dpg.add_line_series([], [], label="Z Pos", tag="series_tag_z")

            # --- Y Axis Plot (Middle) ---
    with dpg.plot(label="Y Axis", height=170, width=-1, parent=parent_window):
        dpg.add_plot_legend()
        dpg.add_plot_axis(dpg.mvXAxis, label="", tag="axis_t_y")
        dpg.set_axis_limits(dpg.last_item(), -10, 0)
        with dpg.plot_axis(dpg.mvYAxis, label="Y (cm)"):
            dpg.set_axis_limits(dpg.last_item(), -5, 5)
            # Set color to something different, e.g., Green
            dpg.add_line_series([], [], label="Y Pos", tag="series_tag_y")
            # To change color, you'd use a theme, but default is fine for now

            # --- X Axis Plot (Bottom) ---
    with dpg.plot(label="X Axis", height=180, width=-1, parent=parent_window):
        dpg.add_plot_legend()
        # Bottom plot gets the X-axis label
        dpg.add_plot_axis(dpg.mvXAxis, label="Time (s)", tag="axis_t_x")
        dpg.set_axis_limits(dpg.last_item(), -10, 0)
        with dpg.plot_axis(dpg.mvYAxis, label="X (cm)"):
            dpg.set_axis_limits(dpg.last_item(), -5, 5)
            dpg.add_line_series([], [], label="X Pos", tag="series_tag_x")