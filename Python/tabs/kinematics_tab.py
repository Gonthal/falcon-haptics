import dearpygui.dearpygui as dpg

from widgets.pos_widget import create_position_widget

def create_kinematics_tab(parent_tab_bar) -> None:
    """Create the kinematics tab in the GUI."""

    #with dpg.tab_bar(tag="tab_bar"):
    with dpg.tab(label="Falcon Playground", tag="tab_playground", parent=parent_tab_bar):
        
        with dpg.group(horizontal=True, label="welcome_group"):
            dpg.add_text("Welcome to the Falcon Playground!")
        dpg.add_separator()

        with dpg.group(horizontal=True):
            with dpg.child_window(width=300, height=145, tag="kinematics_child"):
                dpg.add_text("Kinematics")
                create_position_widget(parent_window="kinematics_child")
                
            with dpg.child_window(width=200, height=300):
                dpg.add_text("Falcon configuration")
                dpg.add_separator()