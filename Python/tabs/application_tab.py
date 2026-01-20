import dearpygui.dearpygui as dpg
import math

class ApplicationTab:
    def __init__(self, queue_to_falcon):
        self.queue = queue_to_falcon
        self.sphere_radius = 3.5  # cm (world units)
        self.stiffness = 5        # N/cm
        self.is_active = False
        self.proxy_x = 0.0  # Store proxy for visualization
        self.proxy_y = 0.0
        self.proxy_z = 0.0
        self.model_data = None  # Placeholder for custom 3D model data (e.g., vertices, faces)

    def render(self):
        with dpg.group(horizontal=True):
            # Left: Controls
            with dpg.group(width=200):
                dpg.add_text("Palpation demo")
                dpg.add_checkbox(label="Activate Haptics", tag="btn_hap_active", callback=self.toggle_haptics)
                # Implement sliders: Bind to self.stiffness and self.sphere_radius
                dpg.add_slider_float(label="Stiffness", default_value=self.stiffness, max_value=10.0, callback=self.update_stiffness)
                dpg.add_slider_float(label="Radius (cm)", default_value=self.sphere_radius, max_value=10.0, callback=self.update_radius)

            # Right: 3D visualization (3D scene instead of 2D canvas)
            with dpg.viewport_menu_bar():  # Required for 3D scenes
                pass
            with dpg.add_3d_scene(width=400, height=400, tag="3d_scene") as scene:
                # Camera setup (simple top-down view)
                dpg.set_camera_position(scene, (0, 0, 10))  # Position camera
                dpg.set_camera_target(scene, (0, 0, 0))    # Look at origin
                # Draw the model here every frame
                pass

    def update_stiffness(self, sender, data):
        self.stiffness = data

    def update_radius(self, sender, data):
        self.sphere_radius = data

    def toggle_haptics(self, sender, data):
        self.is_active = data
        cmd = None
        if not self.is_active:
            # Send "Turn OFF" command to Falcon
            cmd = {
                "type": 7,
                "payload": [0.0]
            }
        else:
            # Send model info (e.g., radius, stiffness) for proxy setup
            cmd = {
                "type": 9,  # New command: Send model params (extend Squirrel script to handle)
                "payload": [self.sphere_radius, self.stiffness]  # Add more for custom models
            }
        self.queue.put(cmd)

    def update_loop(self, x, y, z):
        """
        Call this function every frame from your main loop (100Hz).
        current_pos: (x, y, z) from Falcon
        """
        if not self.is_active:
            return
        
        # 1. PROXY ALGORITHM (God-Object for sphere; generalize for custom model)
        dist = math.sqrt(x*x + y*y + z*z)

        # Calculate proxy position (where the 'ghost' cursor should be)
        if dist < self.sphere_radius:
            # The user is INSIDE the sphere -> push them out
            # Proxy stays on surface
            scale_factor = self.sphere_radius / dist
            self.proxy_x = x * scale_factor
            self.proxy_y = y * scale_factor
            self.proxy_z = z * scale_factor

            # 2. TEXTURE / DIAGNOSIS
            # If we are "touching" the sphere, check for a "tumor"
            # (Example: A hard spot at X > 20)
            k_current = self.stiffness
            if x > 2:
                k_current *= 2.0  # Tumor is 2x harder

            # 3. SEND FORCE COMMAND
            # Send proxy position and stiffness; Squirrel computes F = -k * (pos - proxy)
            cmd = {
                "type": 6,
                "payload": [self.proxy_x, self.proxy_y, self.proxy_z, k_current]
            }
            self.queue.put(cmd)

        else:
            # The user is OUTSIDE -> No force
            cmd = {
                "type": 7,
                "payload": [0.0]
            }
            self.queue.put(cmd)
            # Reset proxy to user position for visualization
            self.proxy_x, self.proxy_y, self.proxy_z = x, y, z

        # 4. VISUALIZATION
        self.draw_sphere()

    def draw_sphere(self):
        # Clear and redraw 3D scene
        dpg.delete_item("3d_scene", children_only=True)
        
        # Draw 3D sphere primitive (center at origin, radius in world units)
        dpg.draw_sphere(center=(0, 0, 0), radius=self.sphere_radius, color=(0, 255, 0), parent="3d_scene")
        
        # Draw proxy position (God-Object) as a small sphere
        dpg.draw_sphere(center=(self.proxy_x, self.proxy_y, self.proxy_z), radius=0.1, color=(0, 0, 255), parent="3d_scene")
        
        # Optionally draw user position (faded)
        # dpg.draw_sphere(center=(x, y, z), radius=0.05, color=(255, 0, 0, 128), parent="3d_scene")
        
        # For custom 3D models: If self.model_data is loaded (e.g., list of triangles), draw them here
        # Example: for face in self.model_data: dpg.draw_triangle(face[0], face[1], face[2], parent="3d_scene")
