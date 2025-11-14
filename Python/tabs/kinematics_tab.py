import dearpygui.dearpygui as dpg
import queue

from widgets.pos_widget import create_position_widget
from widgets.config_widget import create_config_widget

command_queue = queue.Queue()

def create_kinematics_tab(parent_tab_bar) -> None:
    """Create the kinematics tab in the GUI."""

    #with dpg.tab_bar(tag="tab_bar"):
    with dpg.tab(label="Falcon Playground", tag="tab_playground", parent=parent_tab_bar):
        
        with dpg.group(horizontal=True, label="welcome_group"):
            dpg.add_text("Welcome to the Falcon Playground!")
        dpg.add_separator()

        with dpg.group(horizontal=True):
            with dpg.child_window(width=300, height=145, tag="kinematics_position_child"):
                dpg.add_text("Kinematics")
                create_position_widget(parent_window="kinematics_position_child")
                
            with dpg.child_window(width=200, height=300, tag="kinematics_config_child"):
                dpg.add_text("Falcon configuration")
                create_config_widget(parent_window="kinematics_config_child", command_queue=command_queue)
                dpg.add_separator()