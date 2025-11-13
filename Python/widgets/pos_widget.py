import dearpygui.dearpygui as dpg
from typing import Tuple

def create_position_widget(parent_window) -> None:
    """Creates the DearPyGUI widgets for displaying position data."""
    with dpg.group(parent=parent_window, horizontal=True):
        with dpg.child_window(width=-1, height=105):
            dpg.add_text("Position")
            # X Position display
            with dpg.group(horizontal=True):
                dpg.add_text("X:")
                # Read-only text input for X position
                # dpg.add_input_text(tag="pos_x_text", default_value="0.00", width=100, enabled=False)
                # Slider for visual representation
                dpg.add_slider_float(tag="pos_x_slider", width=-1, min_value=-6.0, max_value=6.0, enabled=False)

            with dpg.group(horizontal=True):
                dpg.add_text("Y:")
                #dpg.add_input_text(tag="pos_y_text", default_value="0.00", width=100, enabled=False)
                dpg.add_slider_float(tag="pos_y_slider", width=-1, min_value=-6.0, max_value=6.0, enabled=False)

            with dpg.group(horizontal=True):
                dpg.add_text("Z:")
                #dpg.add_input_text(tag="pos_z_text", default_value="0.00", width=100, enabled=False)
                dpg.add_slider_float(tag="pos_z_slider", width=-1, min_value=-6.0, max_value=6.0, enabled=False)

def update_pos_display(x: float, y:float, z:float) -> None:
    """Update the position display fields in the GUI."""
    if dpg.does_item_exist("pos_x_slider"):
        #dpg.set_value("pos_x_text", f"{x:.2f}")
        #dpg.set_value("pos_y_text", f"{y:.2f}")
        #dpg.set_value("pos_z_text", f"{z:.2f}")

        dpg.set_value("pos_x_slider", x)
        dpg.set_value("pos_y_slider", y)
        dpg.set_value("pos_z_slider", z)
    else:
        print("Position text does not exist")
    