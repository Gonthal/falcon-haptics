import dearpygui.dearpygui as dpg
import pyvista as pv
import numpy as np

class ApplicationTab:
    def __init__(self, queue_to_falcon):
        self.queue = queue_to_falcon
        self.sphere_radius = 0.035
        self.stiffness = 800.0
        self.is_active = False
        
        # New variable for deferred loading
        self.pending_file_path = None
        
        # --- PYVISTA SETUP ---
        self.plotter = pv.Plotter(window_size=[800, 600], title="Haptic Simulation View")
        
        self.target_mesh = pv.Sphere(radius=self.sphere_radius, center=(0, 0, 0))
        self.actor_target = self.plotter.add_mesh(self.target_mesh, color="green", opacity=0.5, show_edges=True)
        
        self.cursor_mesh = pv.Sphere(radius=0.001, center=(0, 0, 0)) 
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
                dpg.add_slider_float(label="Stiffness", default_value=800.0, min_value=100.0, max_value=1000.0, callback=self.update_stiffness)
                dpg.add_text("Note: Models are auto-scaled\nto 8cm size.")

        with dpg.file_dialog(directory_selector=False, show=False, callback=self.on_file_selected, tag="file_dialog_id", width=600, height=400):
            dpg.add_file_extension(".stl", color=(0, 255, 0, 255))
            dpg.add_file_extension(".obj", color=(0, 255, 0, 255))
            dpg.add_file_extension(".*")

    def on_file_selected(self, sender, app_data):
        # THREAD SAFETY FIX:
        # Don't load the model here. Just save the path.
        # The Main Loop will pick it up on the next frame.
        self.pending_file_path = app_data['file_path_name']

    def process_model(self, path):
        # This function now runs safely on the Main Thread
        print(f"Processing {path}...")
        try:
            raw_mesh = pv.read(path)
        except Exception as e:
            print(f"Error reading file: {e}")
            return

        # 2. DECIMATE
        self.target_mesh = raw_mesh.decimate_pro(reduction=0.9, preserve_topology=True)
        
        if self.target_mesh.n_cells > 400:
             current_faces = self.target_mesh.n_cells
             target_red = 1.0 - (400.0 / current_faces)
             if target_red > 0.99: target_red = 0.99
             self.target_mesh = self.target_mesh.decimate_pro(reduction=target_red, preserve_topology=True)

        # 3. Auto-Scale and Center
        self.target_mesh.scale(0.03 / self.target_mesh.length, inplace=True)
        self.target_mesh.translate(-np.array(self.target_mesh.center), inplace=True) 
        
        # 4. Update Visuals
        self.plotter.clear_actors()
        self.actor_target = self.plotter.add_mesh(self.target_mesh, color="green", opacity=0.5, show_edges=True)
        self.actor_cursor = self.plotter.add_mesh(self.cursor_mesh, color="red")
        self.plotter.show_grid()
        
        print(f"Model Loaded: {self.target_mesh.n_points} verts, {self.target_mesh.n_cells} faces.")
        
        # 5. Send to Falcon
        if self.is_active:
            self.send_mesh_data()

    def send_mesh_data(self):
        points = self.target_mesh.points.flatten() 
        faces = self.target_mesh.faces.reshape(-1, 4)[:, 1:].flatten()
        
        payload = []
        payload.append(self.stiffness)
        payload.append(float(len(points))) 
        payload.extend(points)
        payload.append(float(len(faces)))
        payload.extend([float(f) for f in faces])
        
        total_bytes = len(payload) * 4
        print(f"Sending {total_bytes / 1024:.2f} KB of data...")
        
        cmd = { "type": 10, "payload": payload }
        self.queue.put(cmd)

    def toggle_haptics(self, sender, data):
        self.is_active = data
        if self.is_active:
             if hasattr(self, 'target_mesh'):
                 self.send_mesh_data()
        else:
             self.queue.put({"type": 7, "payload": [0.0]})

    def update_stiffness(self, sender, data):
        self.stiffness = data
        if self.is_active:
             self.send_mesh_data()

    def update_loop(self, x, y, z):
        # 1. CHECK FOR PENDING FILES (The Safe Loader)
        if self.pending_file_path is not None:
            self.process_model(self.pending_file_path)
            self.pending_file_path = None # Reset
            
        # 2. Update Cursor
        self.actor_cursor.position = (x/100, y/100, z/100)
        self.plotter.update()