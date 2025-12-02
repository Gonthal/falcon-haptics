import dearpygui.dearpygui as dpg
import time
import collections

t_data = collections.deque(maxlen=100) # Limit to 100 data points
x_data = collections.deque(maxlen=100)

def update_plot_data(new_x: float):
    # New data points
    sample = 1
    t0 = time.time()
    frequency = 1.0
    
    while True:
        # Get new data sample.
        new_time = time.time() - t0
        t_data.append(new_time)
        x_data.append(new_x)

        # Set the series x and y to the last 100 samples
        dpg.set_value("falcon_pos_series", list(t_data), list(x_data))
        dpg.fit_axis_data("t_axis")
        dpg.fit_axis_data("pos_axis")

        time.sleep(0.01)
        sample=sample + 1

    t_data.append(new_time)
    x_data.append(new_x)

    # Update the plot series
    dpg.configure_item("falcon_pos_series", x=list(t_data), y=list(x_data))

    # Schedule the next update
    dpg.set_frame_callback(dpg.get_frame_count() + 1, update_plot_data)

def create_plot_widget(parent_window) -> None:
    """Creates the DearPyGUI for plotting the Falcon's position"""

    #with dpg.group(tag="plot_widget"):
    with dpg.plot(label="Falcon Position v. Time", height=-1, width=-1):
        #dpg.add_plot_legend()
        # REQUIRED: create t and pos axes, set to auto scale.
        t_axis = dpg.add_plot_axis(dpg.mvXAxis, label="Time (s)", tag="t_axis")
        y_axis = dpg.add_plot_axis(dpg.mvYAxis, label="Position (cm)", tag="pos_axis")
        dpg.add_line_series(x=list(t_data), y=list(x_data), label="x", parent="pos_axis", tag="falcon_pos_series")
