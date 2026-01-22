import dearpygui.dearpygui as dpg
import pyvista as pv
import numpy as np

class ApplicationTab:
    def __init__(self, queue_to_falcon):
        self.queue = queue_to_falcon
        self.stiffness = 1000.0
        self.is_active = False

        # Grid configuration
        self.grid_res = 16 # 16x16x16 resolution
        self.bounds_min = np.array([-0.06, -0.06, -0.06]) # 6cm workspace
        self.bounds_max = np.array([0.06, 0.06, 0.06])
        
        # Variable for deferred loading (Thread Safety)
        self.pending_file_path = None
        
        # --- PYVISTA SETUP ---
        self.plotter = pv.Plotter(window_size=[800, 600], title="Haptic Simulation View")
        
        self.target_mesh = None 
        
        self.cursor_mesh = pv.Sphere(radius=0.005, center=(0, 0, 0)) 
        self.actor_cursor = self.plotter.add_mesh(self.cursor_mesh, color="red")
        
        self.plotter.camera_position = [(0.2, 0.2, 0.2), (0, 0, 0), (0, 1, 0)]
        self.plotter.show_grid()
        self.plotter.show(auto_close=False, interactive_update=True)

    def render(self):
        with dpg.group(horizontal=True):
            with dpg.group(width=250):
                dpg.add_text("Custom Model Loader")
                dpg.add_separator()
                
                dpg.add_button(label="Load .STL / .OBJ", callback=lambda: dpg.show_item("file_dialog_id"))
                
                dpg.add_checkbox(label="Activate Haptics", callback=self.toggle_haptics)
                dpg.add_slider_float(label="Stiffness", default_value=1000.0, min_value=100.0, max_value=5000.0, callback=self.update_stiffness)
                dpg.add_text("Note: Models are auto-scaled\nto 10cm size.")

        with dpg.file_dialog(directory_selector=False, show=False, callback=self.on_file_selected, tag="file_dialog_id", width=600, height=300):
            dpg.add_file_extension(".stl", color=(0, 255, 0, 255))
            dpg.add_file_extension(".obj", color=(0, 255, 0, 255))
            dpg.add_file_extension(".*")

    def on_file_selected(self, sender, app_data):
        # THREAD SAFETY FIX:
        # Don't load the model here. Just save the path.
        # The Main Loop will pick it up on the next frame.
        self.pending_file_path = app_data['file_path_name']

    def process_model(self, path):
        # This function runs safely on the Main Thread
        print(f"Processing {path}...")
        try:
            raw_mesh = pv.read(path)
        except Exception as e:
            print(f"Error reading file: {e}")
            return

        # Scale and center the mesh (fit in 10cm box)
        target_size = 0.10
        raw_mesh.scale(target_size / raw_mesh.length, inplace=True)
        raw_mesh.translate(-np.array(raw_mesh.center), inplace=True)
        self.target_mesh = raw_mesh

        # Update visuals
        self.plotter.clear_actors()
        self.plotter.add_mesh(self.target_mesh, color="green", opacity=0.5)
        self.actor_cursor = self.plotter.add_mesh(self.cursor_mesh, color="red")
        
        # Re-add grid for context
        self.plotter.show_grid()

        # Generate force field (Enabled)
        self.generate_and_send_field()

    def generate_and_send_field(self):
        print("Generating force field... (this takes a second)")

        # Create the grid points
        x = np.linspace(self.bounds_min[0], self.bounds_max[0], self.grid_res)
        y = np.linspace(self.bounds_min[1], self.bounds_max[1], self.grid_res)
        z = np.linspace(self.bounds_min[2], self.bounds_max[2], self.grid_res)
        grid_x, grid_y, grid_z = np.meshgrid(x, y, z, indexing='ij')

        # Flatten to list of points (N, 3)
        query_points = np.stack([grid_x.flatten(), grid_y.flatten(), grid_z.flatten()], axis=1)

        # 1. Determine which points are INSIDE the mesh
        grid_poly = pv.PolyData(query_points)
        enclosed = grid_poly.select_enclosed_points(self.target_mesh, tolerance=0.0001)
        mask = enclosed['SelectedPoints'].astype(bool)

        payload_vectors = []
        cnt = 0
        
        # 2. Iterate to calculate forces
        for i, point in enumerate(query_points):
            fx, fy, fz = 0.0, 0.0, 0.0

            if mask[i]: # If point is INSIDE the mesh
                # Find closest point on surface
                closest_idx = self.target_mesh.find_closest_point(point)
                surf_point = self.target_mesh.points[closest_idx]

                # Force vector = Surface - Current Point
                # This pushes the user OUT towards the surface
                vec = surf_point - point

                # Apply stiffness
                fx = vec[0] * self.stiffness
                fy = vec[1] * self.stiffness
                fz = vec[2] * self.stiffness
                cnt += 1
            
            payload_vectors.extend([fx, fy, fz])

        print(f"Force field generated. {cnt} active voxels out of {len(query_points)}.")

        # Send to Falcon (CMD 11)
        # Protocol: [CMD_11, DEBUGGING: stiffness, GridRes, MinX, MinY, MinZ, MaxX, MaxY, MaxZ, Fx0, Fy0, Fz0, ...]
        payload = [
            float(self.grid_res),
            self.stiffness,
            self.bounds_min[0], self.bounds_min[1], self.bounds_min[2],
            self.bounds_max[0], self.bounds_max[1], self.bounds_max[2]
        ]
        payload.extend(payload_vectors)

        print(f"Sending {len(payload)*4/1024:.2f} KB...")
        self.queue.put({"type": 11, "payload": payload})

    def toggle_haptics(self, sender, data):
        self.is_active = data
        if self.is_active:
             if self.target_mesh is not None:
                 self.generate_and_send_field()
        else:
             self.queue.put({"type": 7, "payload": [0.0]})

    def update_stiffness(self, sender, data):
        self.stiffness = data
        if self.is_active and self.target_mesh is not None:
             self.generate_and_send_field()

    def update_loop(self, x, y, z):
        # 1. CHECK FOR PENDING FILES (Safe Loader)
        if self.pending_file_path is not None:
            self.process_model(self.pending_file_path)
            self.pending_file_path = None # Reset
            
        # 2. Update Cursor
        # We assume x, y, z are already in Meters (e.g. 0.04)
        # If your server sends CM (e.g. 4.0), you might need to divide by 100.
        # But standardizing on Meters is best.
        self.actor_cursor.position = (x, y, z)
        self.plotter.update()