import dearpygui.dearpygui as dpg
import queue
import math

# Dictionary to enumerate the different command ids there are
EFFECT_IDS = {
    "None":      0,
    "Rock":      1,
    "Sandpaper": 2,
    "Oil":       3,
    "Spring":    4,
    "Water":     5
}

# Colors for each effect: (R, G, B, Alpha)
# Alpha ~50-100 makes it semi-transparent
EFFECT_COLORS = {
    0: (200, 200, 200, 20),   # None: Ghostly white
    1: (100, 100, 100, 150),  # Rock: Solid Grey
    2: (180, 130, 70, 120),   # Sandpaper: Sandy Orange
    3: (20, 20, 20, 200),     # Oil: Dark/Black
    4: (50, 200, 50, 100),    # Spring: Bouncy Green
    5: (50, 100, 255, 80)     # Water: Fluid Blue
}

# Global state to track the currently selected effect for visualization
current_effect_id = 0

# --- Helper: 3D math ---
def project_point(x, y, z, canvas_width, canvas_height):
    """
    Projects a 3D point (x, y, z) onto a 2D screen (screen_x, screen_y).
    Uses a simple weak perspective projection.
    """
    # Camera / View settings
    #scale = 1000.0   # Pixels per unit (zoom)
    #cam_dist = 40.0 # Distance of camera from origin

    scale_tag = "cube_scale_slider"
    cam_dist_tag = "cube_cam_dist_slider"

    if not dpg.does_item_exist(scale_tag):
        return
    if not dpg.does_item_exist(cam_dist_tag):
        return
    
    scale = dpg.get_value(scale_tag)
    cam_dist = dpg.get_value(cam_dist_tag)

    # Perspective division
    factor = scale / (cam_dist + z)

    # Project and offset to canvas center
    screen_x = x * factor + (canvas_width / 2)
    screen_y = -y * factor + (canvas_height / 2) # Flip y for screen coords
    return [screen_x, screen_y]

def draw_cube_faces(drawlist, size, color, draw_front=True):
    """
    Draws either the front or back faces of a cube.
    size: half-width of the cube (radius)
    """
    # Cube vertices (x, y, z)
    # Fron face (z = +size)
    v0 = [-size, -size, size]
    v1 = [size, -size, size]
    v2 = [size, size, size]
    v3 = [-size, size, size]

    # Back face (z = -size)
    v4 = [-size, -size, -size]
    v5 = [ size, -size, -size]
    v6 = [ size,  size, -size]
    v7 = [-size,  size, -size]

    canvas_w = dpg.get_item_width(drawlist)
    canvas_h = dpg.get_item_height(drawlist)

    # Project all vertices
    p = [project_point(*v, canvas_w, canvas_h) for v in [v0, v1, v2, v3, v4, v5, v6, v7]]

    # Define faces by vertex indices (counter-clockwise)
    # Front, Right, Top, Left, Bottom, Back
    faces = [
        ([0, 1, 2, 3], True),   # Front
        ([1, 5, 6, 2], True),   # Right
        ([3, 2, 6, 7], True),   # Top
        ([4, 0, 3, 7], True),   # Left
        ([4, 5, 1, 0], True),   # Bottom
        ([5, 4, 7, 6], False)   # Back
    ]

    for indices, is_front in faces:
        if is_front != draw_front:
            continue

        pts = [p[i] for i in indices]
        dpg.draw_quad(pts[0], pts[1], pts[2], pts[3], color=(255, 255, 255, 100), fill=color, thickness=1, parent=drawlist)

# --- Callbacks ---

def send_effect_command(sender, app_data, user_data: queue.Queue) -> None:
    """
    Callback for the radio button.
    app_data contains the string label of the selected radio button
    """
    global current_effect_id
    cmd_queue = user_data
    
    # Get the integer ID from EFFECT_IDS dictionary
    selected_effect_name = app_data
    effect_id = EFFECT_IDS.get(selected_effect_name, 0)
    current_effect_id = effect_id # Update global state for visualizer

    print(f"Queuein effect change: {selected_effect_name} (ID: {effect_id})")

    # Construct the command
    command_to_send = {
        "type": effect_id,
        "payload": [0.0, 0.0, 0.0]  # Empty payload, we just care about the effect id
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

def update_visualizer(x_pos:float, y_pos:float, z_pos: float) -> None:
    """
    Main render loop for the haptics visualizer.
    Draws: Back Cube Faces -> Cursor -> Front Cube Faces
    """
    canvas = "visualizer_canvas"
    if not dpg.does_item_exist(canvas):
        return
    
    # Clear previous frame
    dpg.delete_item(canvas, children_only=True)

    # Setup
    cube_size = 4.0 # Visual size of the cube (should match the Falcon workspace)
    color = EFFECT_COLORS.get(current_effect_id, (255, 255, 255, 50))
    w = dpg.get_item_width(canvas)
    h = dpg.get_item_height(canvas)

    # Draw back faces (Background)
    draw_cube_faces(canvas, cube_size, color, draw_front=False)

    # Draw cursor (the circle)
    # We project the Falcon's actual 3D position to 2D screen space
    cursor_screen = project_point(x_pos, y_pos, z_pos, w, h)

    # Scale radius by Z for depth effect (closer = larger)
    # Base radius 10, grows as Z increases
    radius = 10 + (z_pos * 2.0)
    radius = max(2.0, min(radius, 50.0)) # Clamp size

    # Color cursor yellow to stand out against the cube
    dpg.draw_circle(center=cursor_screen, radius=radius, color=(255, 255, 0, 255), fill=(255, 255, 0, 200), parent=canvas)

    # Draw front faces (foreground)
    # Since these have and alpha < 255, we will see the cursor inside them
    draw_cube_faces(canvas, cube_size, color, draw_front=True)

    # Helper text
    dpg.draw_text(pos=[10, 10], text=f"Effect: {current_effect_id}", size=15, color=(150, 150, 150, 255), parent=canvas)

def create_effects_widget(parent_window, command_queue) -> None:
    """Creates the DearPyGUI widget for effect settings."""

    with dpg.group(horizontal=True, tag="haptics_widget"):
        # Left side: Effect Selection
        with dpg.child_window(parent="parent_window", width=130, height=230):
            dpg.add_text("Select an effect")
            # Radio button for mutually exclusive selection
            dpg.add_radio_button(
                items=list(EFFECT_IDS.keys()), # ["No Effect", "Rock", ...]
                default_value="None",
                callback=send_effect_command,
                user_data=command_queue,
                tag="effects_radio_button",
                horizontal=False # Set to True if you want them side-by-side
            )

            dpg.add_slider_float(tag="cube_scale_slider", width=-1, min_value=300.0, max_value=1000.0, default_value=300.0)
            dpg.add_slider_float(tag="cube_cam_dist_slider", width=-1, min_value=10.0, max_value=60.0, default_value=40.0)


        # Right side: 3D cube visualizer
        with dpg.child_window(width=350, height=350):
            dpg.add_text("Haptic workspace")

            # Create a drawiwng canvas
            dpg.add_drawlist(width=340, height=340, tag="visualizer_canvas")
    

    #dpg.add_separator()

    #dpg.add_button(label="Dummy command", width=425, callback=send_dummy_command, user_data=command_queue)
    #with dpg.child_window(parent=parent_window, width=-1, height=105):