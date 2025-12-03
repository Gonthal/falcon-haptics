import dearpygui.dearpygui as dpg

from widgets.pos_widget import create_position_widget
from widgets.effects_widget import create_effects_widget
from widgets.plots_widget import create_plot_widget

def create_sandbox_tab(parent_tab_bar, command_queue) -> None:
    """Create the kinematics tab in the GUI."""

    #with dpg.tab_bar(tag="tab_bar"):
    with dpg.tab(label="Falcon Sandbox", tag="tab_sandbox", parent=parent_tab_bar):
        
        with dpg.group(horizontal=True, label="welcome_group"):
            dpg.add_text("Welcome to the Falcon Sandbox!")
        dpg.add_separator()

        with dpg.group(horizontal=True):
            with dpg.child_window(width=500, height=700, tag="kinematics_position_child"):
                dpg.add_text("Kinematics")
                create_position_widget(parent_window="kinematics_position_child")
                create_plot_widget(parent_window="kinematics_position_child")
                
            with dpg.child_window(width=-1, height=300, tag="kinematics_config_child"):
                dpg.add_text("Haptics")
                create_effects_widget(parent_window="kinematics_config_child", command_queue=command_queue)
                #dpg.add_separator()