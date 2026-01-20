import dearpygui.dearpygui as dpg
import pyvista as pv
import numpy as np

class ApplicationTab:
    def __init__(self, queue_to_falcon):
        self.queue = queue_to_falcon
        self.sphere_radius = 0.035  # 3.5 cm
        self.stiffness = 1000.0    # N/m
        self.is_active = False
        
        # --- PYVISTA SETUP ---
        # 1. Create the Plotter (The 3D Window)
        # off_screen=False means it pops up a real window
        self.plotter = pv.Plotter(window_size=[800, 600], title="Haptic Simulation View")
        
        # 2. Add the "Virtual Object" (The Green Sphere)
        # Resolution=50 makes it look smooth
        self.mesh_sphere = pv.Sphere(radius=self.sphere_radius, center=(0, 0, 0), theta_resolution=50, phi_resolution=50)
        self.actor_sphere = self.plotter.add_mesh(self.mesh_sphere, color="green", opacity=0.5, show_edges=True)
        
        # 3. Add the "Cursor" (The Red Dot representing the Falcon)
        self.cursor_mesh = pv.Sphere(radius=0.005, center=(0, 0, 0)) # 5mm cursor
        self.actor_cursor = self.plotter.add_mesh(self.cursor_mesh, color="red")
        
        # 4. Add a "Proxy" (Ghost point on surface - Blue)
        self.proxy_mesh = pv.Sphere(radius=0.004, center=(0,0,0))
        self.actor_proxy = self.plotter.add_mesh(self.proxy_mesh, color="blue", opacity=0.0) # Invisible initially

        # 5. Setup Camera
        self.plotter.camera_position = [(0.2, 0.2, 0.2), (0, 0, 0), (0, 1, 0)]
        self.plotter.show_grid()
        
        # CRITICAL: Do not call plotter.show() yet!
        # We will manually trigger renders in the update loop.
        self.plotter.show(auto_close=False, interactive_update=True)

    def render(self):
        # This renders the CONTROLS in the DearPyGui window
        with dpg.group(horizontal=True):
            with dpg.group(width=250):
                dpg.add_text("Medical Simulation Controls")
                dpg.add_separator()
                
                dpg.add_checkbox(label="Activate Haptics", callback=self.toggle_haptics)
                dpg.add_slider_float(label="Radius (m)", default_value=self.sphere_radius, 
                                     min_value=0.01, max_value=0.10, callback=self.update_params)
                dpg.add_slider_float(label="Stiffness (N/m)", default_value=self.stiffness, 
                                     min_value=100.0, max_value=2000.0, callback=self.update_params)
                
                dpg.add_text("Note: 3D View is in the separate window.")

    def toggle_haptics(self, sender, data):
        self.is_active = data
        if self.is_active:
            self.send_model_to_falcon()
        else:
            # Send Disable Command
            cmd = {"type": 7, "payload": [0.0]}
            self.queue.put(cmd)

    def update_params(self, sender, data):
        if sender == "Radius (m)": 
            self.sphere_radius = data
            # Update visual mesh size
            # PyVista doesn't allow changing radius easily, so we scale it
            # Or simpler: just recreate the sphere mesh logic if needed, 
            # but scaling the actor is faster:
            # (Reset scale first to avoid compounding)
            # This is a bit complex in VTK, so for a thesis, just re-generating the mesh is fine:
            new_mesh = pv.Sphere(radius=self.sphere_radius, center=(0,0,0))
            self.mesh_sphere.overwrite(new_mesh) # Updates the geometry in place
            
        if sender == "Stiffness (N/m)": 
            self.stiffness = data
            
        if self.is_active:
            self.send_model_to_falcon()

    def send_model_to_falcon(self):
        cmd = {
            "type": 9,
            "payload": [self.sphere_radius, self.stiffness]
        }
        self.queue.put(cmd)

    def update_loop(self, x, y, z):
        """
        Called every frame by DearPyGui loop
        """
        # 1. Update Cursor Position (Red Sphere)
        # translate to new position
        current_center = self.cursor_mesh.center
        new_center = [x, y, z]
        translation_vector = [nc - cc for nc, cc in zip(new_center, current_center)]

        # Translate the mesh (inplace=True modifies the original mesh)
        self.cursor_mesh.translate(translation_vector, inplace=True)

        #self.cursor_mesh.center = [x, y, z]
        
        # 2. Update Proxy Position (Optional Visualization)
        # If you want to visualize the math from the previous step
        dist = np.sqrt(x*x + y*y + z*z)
        if dist < self.sphere_radius:
            self.actor_sphere.prop.opacity = 0.8 # Make sphere solid when touching
            self.actor_cursor.prop.color = "red"
        else:
            self.actor_sphere.prop.opacity = 0.3 # Ghostly when safe
            self.actor_cursor.prop.color = "blue"

        # 3. CRITICAL: Tell PyVista to render one frame
        # This keeps the 3D window alive and responsive
        self.plotter.update()