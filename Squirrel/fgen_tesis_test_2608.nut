//-------------------------------------------------------------
// fgen_tutorial_02_plugin.nut
//
// Squirrel script for F-Gen plugin tutorial
//-------------------------------------------------------------

//========================================================
// setup plugins
//========================================================

// load the test plugin
//loadplugin("SQTestDLL.dll");
loadplugin("SecondFalcon.dll");

//========================================================
// Classes
//========================================================

class CommandQueue {
    _data = null;

    constructor() {
        _data = []; // Initialize an empty array to store queue elements
    }

    // Adds an element to the back of the queue (enqueue)
    function enqueue(item) {
        _data.append(item);
    }

    // Removes and returns the element from the front of the queue (dequeue)
    function dequeue() {
        if (this.isEmpty()) {
            throw "Queue is empty"; // Handle underflow
        }
        return _data.remove(0); // Remove the first element
    }

    // Returns the element at the front of the queue without removing it (peek)
    function peek() {
        if (this.isEmpty()) {
            return null; // Or throw an error, depending on desired behavior
        }
        return _data[0];
    }

    // Checks if the queue is empty
    function isEmpty() {
        return _data.len() == 0;
    }

    // Returns the number of elements in the queue
    function size() {
        return _data.len();
    }
}


//========================================================
// global variables
//========================================================

gFrameCounter <- 0;
gStackConnected <- false;

gPosition <- { x = 0.0, y = 0.0, z = 0.0 };
gLastPosition <- { x = 0.0, y = 0.0, z = 0.0 };
gTextureAnchor <- { x = 0.0, y = 0.0, z = 0.0 };
gLastFramePos <- { x = 0.0, y = 0.0, z = 0.0 };

// Add water momentum state (keeps residual flow after movement)
gWaterMomentum <- {
	x = 0.0,
	y = 0.0,
	z = 0.0
}

// DEBUGGING: MESH
gModelData <- {
    type = "sphere",  // "sphere" or "mesh"
    radius = 3.5,     // For sphere
    stiffness = 5.0,  // For sphere
    vertices = [],    // List of {x, y, z} for mesh
    faces = []        // List of [v1, v2, v3] indices for mesh
};

gIsModelActive <- false;

gCommandQueue <- CommandQueue();

gIsSphereActive <- 0.0;

//gKeyInput <- inputlistener();
gScriptTime <- timekeeper();   // setup time checker, used for delta time
gTimer <- 0.0;
gLastTime <- 0.0;			   // time at the end of the frame, initially set to 0
const SEND_INTERVAL = 0.01;    // Send data every 0.01 seconds (100 Hz)
//const READ_INTERVAL = 0.002	   // Read data every 0.002 seconds (500 Hz)
gTimeSinceLastSend <- 0.0;     // time since last data send
gTimeSinceLastRead <- 0.0;

//========================================================
// stacks
//========================================================

// --- Create the effect stack ---
gEffectsStack <- effectstack("effects", 1.0);      // creating default Falcon effect stack
gEnvelopeEffectID <- registereffect("Envelope");   // registering

// --- ROCK RECOIL ---
// Back face of the cube
gRockRecoilPush <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilPush.setvarelement("force", 0, 0);   // 0 newtons right-wards
gRockRecoilPush.setvarelement("force", 1, 0);   // 0 newtons upwards
gRockRecoilPush.setvarelement("force", 2, 20);  // 20 newtons backwards
gRockRecoilPush.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilPush.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilPush.setvar("decay", 0);             // no fall off time at end of effect

gRockRecoilPull <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilPull.setvarelement("force", 0, 0);   // 0 newtons right-wards
gRockRecoilPull.setvarelement("force", 1, 0);   // 0 newtons upwards
gRockRecoilPull.setvarelement("force", 2, -20); // 20 newtons front-wards
gRockRecoilPull.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilPull.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilPull.setvar("decay", 0);             // no fall off time at end of effect

gRockRecoilLeft <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilLeft.setvarelement("force", 0, -20); // 20 newtons left-wards
gRockRecoilLeft.setvarelement("force", 1, 0);   // 0 newtons upwards
gRockRecoilLeft.setvarelement("force", 2, 0);   // 0 newtons backwards
gRockRecoilLeft.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilLeft.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilLeft.setvar("decay", 0);             // no fall off time at end of effect

gRockRecoilRight <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilRight.setvarelement("force", 0, 20);  // 20 newtons right-wards
gRockRecoilRight.setvarelement("force", 1, 0);   // 0 newtons upwards
gRockRecoilRight.setvarelement("force", 2, 0);   // 0 newtons backwards
gRockRecoilRight.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilRight.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilRight.setvar("decay", 0);             // no fall off time at end of effect

gRockRecoilUp <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilUp.setvarelement("force", 0, 0);   // 0 newtons right-wards
gRockRecoilUp.setvarelement("force", 1, 20);  // 0 newtons upwards
gRockRecoilUp.setvarelement("force", 2, 0);   // 20 newtons backwards
gRockRecoilUp.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilUp.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilUp.setvar("decay", 0);             // no fall off time at end of effect

gRockRecoilDown <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoilDown.setvarelement("force", 0, 0);   // 0 newtons right-wards
gRockRecoilDown.setvarelement("force", 1, -20); // 0 newtons downwards
gRockRecoilDown.setvarelement("force", 2, 0);   // 20 newtons backwards
gRockRecoilDown.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoilDown.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoilDown.setvar("decay", 0);             // no fall off time at end of effect

const ROCK_THRESHOLD = 0.01;  // 1 cm

// --- SANDPAPER RECOIL ---
gSandpaperRecoilPush <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilPush.setvarelement("force", 0, 0);   // 0 newtons right-wards
gSandpaperRecoilPush.setvarelement("force", 1, 0);   // 0 newtons upwards
gSandpaperRecoilPush.setvarelement("force", 2, 5);   // 5 newtons backwards
gSandpaperRecoilPush.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilPush.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilPush.setvar("decay", 0);             // no fall off time at end of effect

gSandpaperRecoilPull <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilPull.setvarelement("force", 0, 0);   // 0 newtons right-wards
gSandpaperRecoilPull.setvarelement("force", 1, 0);   // 0 newtons upwards
gSandpaperRecoilPull.setvarelement("force", 2, -5);   // 5 newtons backwards
gSandpaperRecoilPull.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilPull.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilPull.setvar("decay", 0);             // no fall off time at end of effect

gSandpaperRecoilLeft <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilLeft.setvarelement("force", 0, -5);   // 0 newtons right-wards
gSandpaperRecoilLeft.setvarelement("force", 1, 0);   // 0 newtons upwards
gSandpaperRecoilLeft.setvarelement("force", 2, 0);   // 5 newtons backwards
gSandpaperRecoilLeft.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilLeft.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilLeft.setvar("decay", 0);             // no fall off time at end of effect

gSandpaperRecoilRight <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilRight.setvarelement("force", 0, 5);   // 0 newtons right-wards
gSandpaperRecoilRight.setvarelement("force", 1, 0);   // 0 newtons upwards
gSandpaperRecoilRight.setvarelement("force", 2, 0);   // 5 newtons backwards
gSandpaperRecoilRight.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilRight.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilRight.setvar("decay", 0);             // no fall off time at end of effect

gSandpaperRecoilUp <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilUp.setvarelement("force", 0, 0);   // 0 newtons right-wards
gSandpaperRecoilUp.setvarelement("force", 1, 5);   // 0 newtons upwards
gSandpaperRecoilUp.setvarelement("force", 2, 0);   // 5 newtons backwards
gSandpaperRecoilUp.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilUp.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilUp.setvar("decay", 0);             // no fall off time at end of effect

gSandpaperRecoilDown <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoilDown.setvarelement("force", 0, 0);   // 0 newtons right-wards
gSandpaperRecoilDown.setvarelement("force", 1, -5);   // 0 newtons upwards
gSandpaperRecoilDown.setvarelement("force", 2, 0);   // 5 newtons backwards
gSandpaperRecoilDown.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoilDown.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoilDown.setvar("decay", 0);             // no fall off time at end of effect
const SANDPAPER_THRESHOLD = 0.001; // 1 mm

// --- Effect type table ---
// Used to identify different surface effects
gEffectTypeTable <- {};
gEffectTypeTable.noeffect  <- 0;
gEffectTypeTable.rock      <- 1;
gEffectTypeTable.sandpaper <- 2;
gEffectTypeTable.oil       <- 3;
gEffectTypeTable.spring    <- 4;
gEffectTypeTable.water     <- 5;
// Now, let us create the effect type variable
gEffectType <- gEffectTypeTable.noeffect; // by default, there is no effect in place

// --- ---
// Used to identify which face(s) of the cube is (are) being touched
// Each orientation is given by a normal vector to the plane being touched
gTouchedFaceOrientation <- {
	x = 0,
	y = 0,
	z = 0
}


// --- Create the control box stack ---
gControlBoxStack <- effectstack("ControlBox", 1.0);
// registering a control box effect
gControlBoxEffectID <- registereffect("ControlBox");
gControlBox <- null; // variable to store the control box in

// --- Create the movement effect stack ---
// Create a separate effects stack for movement forces
gMovementStack <- effectstack("movement", 1.0);
// Create a constant effect type
gConstantEffectID <- registereffect("Constant");
// create the effect parameters for a constant effect for use as a movement force
gMovementEffectParameters <- effectparameters(gConstantEffectID, gMovementStack);
gMovementForce <- null;

// --- Create tge effect parameters for a constant effect for use as a BOUNDARY force ---
gBoundaryStack <- effectstack("boundary", 1.0);
gBoundaryEffectID <- registereffect("Constant");
gBoundaryEffectParameters <- effectparameters(gBoundaryEffectID, gBoundaryStack);
gBoundaryForce <- null;


//========================================================
// functions
//========================================================

// ------------------------------------------------------------
// Calculate the distance between two 3D points
// ------------------------------------------------------------
function calc_3d_distance (pos1, pos2) {
	local dx = pos2.x - pos1.x;
	local dy = pos2.y - pos1.y;
	local dz = pos2.z - pos1.z;
	return sqrt(dx*dx + dy*dy + dz*dz);
}

function calc_2d_distance(pos1, pos2, orientation) {
	if (orientation == 'x') {
		local dy = pos2.y - pos1.y;
		local dz = pos2.z - pos1.z;
		return sqrt(dy*dy + dz*dz);
	} else if (orientation == 'y') {
		local dx = pos2.x - pos1.x;
		local dz = pos2.z - pos1.z;
		return sqrt(dx*dx + dz*dz);
	} else if (orientation == 'z') {
		local dx = pos2.x - pos1.x;
		local dy = pos2.y - pos1.y;
		return sqrt(dx*dx + dy*dy);
	}
	//local dx = pos2.x - pos1.x;
	//local dy = pos2.y - pos1.y;
	//return sqrt(du*du + dv*dv);
}

function decodeCommand(cmd, deltaTime) {
	if (cmd.type == 100) return; // we ignore errors for now
	print("Executing command: " + cmd.type + "\n");

	//local cmd = gCommandQueue.peek();

	if (cmd.type >= 0 && cmd.type <= 5) {
		print("Command is type " + cmd.type + "\n");
		gEffectType = cmd.type;
	} else if (cmd.type == 7) {
		gIsSphereActive = 0.0;
		gIsModelActive = false;	// DEBUGGING
	} else if (cmd.type == 8) {
		gIsSphereActive = 1.0;
		gIsModelActive = true;	// DEBUGGING
	} else if (cmd.type == 9) {
		// Handle model params (legacy sphere)
		gModelData.radius = cmd.data[0];
		gModelData.stiffness = cmd.data[1];
		gIsModelActive = true;
		print("Type 9. Radius: " + gModelData.radius + ". Stiffness: " + gModelData.stiffness + " \n");
	} else if (cmd.type == 10) {
		// New command: Send full model data
		// Payload: [Stiffness, NumVerts, v1...vn, Numfaces, f1...fn]
		gModelData.type = "mesh";
		gModelData.stiffness = cmd.data[0];

		// Parse vertices
		local num_verts_floats = cmd.data[1].tointeger();
		gModelData.vertices = [];
		local start_v = 2;

		for (local i = 0; i < num_verts_floats; i += 3) {
			local vx = cmd.data[start_v + i];
			local vy = cmd.data[start_v + i + 1];
			local vz = cmd.data[start_v + i + 2];
			gModelData.vertices.append({x=vx, y=vy, z=vz});
		}

		// Parse faces
		// The face data starts after the vertex data
		local start_f = start_v + num_verts_floats + 1;
		local num_faces_ints = cmd.data[start_v + num_verts_floats].tointeger();

		gModelData.faces = [];
		for (local i = 0; i < num_faces_ints; i += 3) {
			// We sent them as floats, so convert back to integer for indices
			local f1 = cmd.data[start_f + i].tointeger();
			local f2 = cmd.data[start_f + i + 1].tointeger();
			local f3 = cmd.data[start_f + i + 2].tointeger();
			gModelData.faces.append([f1, f2, f3]);
		}

		gIsModelActive = true;
		print("Mesh Loaded: " + gModelData.faces.len() + " triangles.\n");

	} else if (cmd.type == 6) {
		if (gIsModelActive) {
			print("Type 6. Radius: " + gModelData.radius + ". Stiffness: " + gModelData.stiffness + " \n");
			// Compute proxy using model data
			local proxy = computeProxy(gPosition, gModelData);
			local k = gModelData.stiffness;
			local k_damping = 15.0;

			local velocity = { x = 0.0, y = 0.0, z = 0.0 };
            if (deltaTime > 0.000001) {
                velocity.x = (gPosition.x - gLastFramePos.x) / deltaTime;
                velocity.y = (gPosition.y - gLastFramePos.y) / deltaTime;
                velocity.z = (gPosition.z - gLastFramePos.z) / deltaTime;
            }

			local force = {
                x = (proxy.x - gPosition.x) * k - velocity.x * k_damping,
                y = (proxy.y - gPosition.y) * k - velocity.y * k_damping,
                z = (proxy.z - gPosition.z) * k - velocity.z * k_damping
            };
            gBoundaryForce.setforce(force.x, force.y, force.z);
			print("Proxy: (" + proxy.x + ", " + proxy.y + ", " + proxy.z + ")\n");
		} else {
			gBoundaryForce.setforce(0.0, 0.0, 0.0);
		}
	}
}

function computeProxy(position, model) {
    if (model.type == "sphere") {
        local dist = sqrt(position.x*position.x + position.y*position.y + position.z*position.z);
        if (dist < model.radius) {
            local scale = model.radius / dist;
            return {x = position.x * scale, y = position.y * scale, z = position.z * scale};
        } else {
            return {x = position.x, y = position.y, z = position.z};
        }
    } else if (model.type == "mesh") {

        // --- OPTIMIZATION 1: BROAD PHASE ---
        // If we are further than 6cm from center, don't even bother checking triangles.
        // (Assuming model is max 4cm radius + 2cm buffer)
        // 0.06^2 = 0.0036 // Let us try with 3cm radius + 1cm buffer
        local distSq = position.x*position.x + position.y*position.y + position.z*position.z;
        if (distSq > 0.000961) { // 3cm + 0.2cm buffer
             return {x = position.x, y = position.y, z = position.z};
        }

        local closest = {x = position.x, y = position.y, z = position.z};
        local minDist = 999999.0;

        // Pre-calculate squared cull distance (1.5 cm)
        // Triangles further than this won't be checked accurately
        //const CULL_DIST_SQ = 0.000225; // 0.015 * 0.015

		const CULL_DIST_SQ = 0.00000625; // 0.005 * 0.005

        foreach (face in model.faces) {
            local v1 = model.vertices[face[0]];

            // --- OPTIMIZATION 2: NARROW PHASE CULLING ---
            // Fast check: Is the cursor close to the first vertex?
            // If not, skip the expensive closestPointOnTriangle math.
            local dx = position.x - v1.x;
            local dy = position.y - v1.y;
            local dz = position.z - v1.z;

            // If distance^2 > 1.5cm^2, SKIP IT
            if ((dx*dx + dy*dy + dz*dz) > CULL_DIST_SQ) {continue;}

            local v2 = model.vertices[face[1]];
            local v3 = model.vertices[face[2]];

            local pointOnTri = closestPointOnTriangle(position, v1, v2, v3);
            local dist = calc_3d_distance(position, pointOnTri);

            if (dist < minDist) {
                minDist = dist;
                closest = pointOnTri;
            }
        }
        return closest;
    }
    return {x = 0.0, y = 0.0, z = 0.0};
}

// Robust 'Closest Point on Triangle'
// Based on Real-Time Collision Detection (Ericson)
function closestPointOnTriangle(p, a, b, c) {
    local ab = subtract(b, a);
    local ac = subtract(c, a);
    local ap = subtract(p, a);

    // Check if P in vertex region outside A
    local d1 = dot(ab, ap);
    local d2 = dot(ac, ap);
    if (d1 <= 0.0 && d2 <= 0.0) return a;

    // Check if P in vertex region outside B
    local bp = subtract(p, b);
    local d3 = dot(ab, bp);
    local d4 = dot(ac, bp);
    if (d3 >= 0.0 && d4 <= d3) return b;

    // Check if P in edge region of AB
    local vc = d1 * d4 - d3 * d2;
    if (vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0) {
        local v = d1 / (d1 - d3);
        return {x = a.x + v * ab.x, y = a.y + v * ab.y, z = a.z + v * ab.z};
    }

    // Check if P in vertex region outside C
    local cp = subtract(p, c);
    local d5 = dot(ab, cp);
    local d6 = dot(ac, cp);
    if (d6 >= 0.0 && d5 <= d6) return c;

    // Check if P in edge region of AC
    local vb = d5 * d2 - d1 * d6;
    if (vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0) {
        local w = d2 / (d2 - d6);
        return {x = a.x + w * ac.x, y = a.y + w * ac.y, z = a.z + w * ac.z};
    }

    // Check if P in edge region of BC
    local va = d3 * d6 - d5 * d4;
    if (va <= 0.0 && (d4 - d3) >= 0.0 && (d5 - d6) >= 0.0) {
        local w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        local cb = subtract(c, b);
        return {x = b.x + w * cb.x, y = b.y + w * cb.y, z = b.z + w * cb.z};
    }

    // P inside face region. Compute via barycentric coordinates
    local denom = 1.0 / (va + vb + vc);
    local v = vb * denom;
    local w = vc * denom;

    return {
        x = a.x + ab.x * v + ac.x * w,
        y = a.y + ab.y * v + ac.y * w,
        z = a.z + ab.z * v + ac.z * w
    };
}

// Helper functions for vectors
function subtract(a, b) { return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}; }
function dot(a, b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
function cross(a, b) { return {x = a.y*b.z - a.z*b.y, y = a.z*b.x - a.x*b.z, z = a.x*b.y - a.y*b.x}; }

function executeCubeBoundaries (velocity) {
	local forceX = 0.0;
	local forceY = 0.0;
	local forceZ = 0.0;

	// --- Configuration ---
	// Distance from the center to the wall (the units are in meters)
	const WALL_LIMIT = 0.03;
	local outer_limit = WALL_LIMIT;// + gPosition.z * 0.5;

	// Stiffness: How "hard" the wall feels (N/m)
	// Keep it between 800 and 1200. If it starts to buzz, decrease
	const K_STIFFNESS = 1000.0;

	// Damping: Prevents the bouncing (N/(m/s))
	const K_DAMPING = 15.0;

	// --- Left wall ---
	if (gPosition.x < -outer_limit) {
		// We are touching the left face of the cube
		gTouchedFaceOrientation.x = -1;
		local perforation = (-outer_limit) - gPosition.x;
		// Spring pushes to the RIGHT (+)
		local springForce = perforation * K_STIFFNESS;
		// Damper resists velocity
		local dampingForce = -velocity.x * K_DAMPING;
		forceX = springForce + dampingForce;
		// Constraint: Force must always push OUT, never pull in
		if (forceX < 0.0) forceX = 0.0;
	}
	// --- Right Wall ---
    else if (gPosition.x > outer_limit) {
		gTouchedFaceOrientation.x = 1;
        local perforation = gPosition.x - outer_limit;
        local springForce = -perforation * K_STIFFNESS; // Push LEFT (-)
        local dampingForce = -velocity.x * K_DAMPING;

        forceX = springForce + dampingForce;
        if (forceX > 0.0) forceX = 0.0;
    } else {
		gTouchedFaceOrientation.x = 0;
	}

    // --- Bottom Wall ---
    if (gPosition.y < -outer_limit) {
		gTouchedFaceOrientation.y = -1;
        local perforation = (-outer_limit) - gPosition.y;
        local springForce = perforation * K_STIFFNESS; // Push UP (+)
        local dampingForce = -velocity.y * K_DAMPING;

        forceY = springForce + dampingForce;
        if (forceY < 0.0) forceY = 0.0;
    }
    // --- Top Wall ---
    else if (gPosition.y > outer_limit) {
		gTouchedFaceOrientation.y = 1;
        local perforation = gPosition.y - outer_limit;
        local springForce = -perforation * K_STIFFNESS; // Push DOWN (-)
        local dampingForce = -velocity.y * K_DAMPING;

        forceY = springForce + dampingForce;
        if (forceY > 0.0) forceY = 0.0;
    } else {
		gTouchedFaceOrientation.y = 0;
	}

    // --- Back Wall ---
    if (gPosition.z < -WALL_LIMIT) {
		gTouchedFaceOrientation.z = -1;
        local perforation = (-WALL_LIMIT) - gPosition.z;
        local springForce = perforation * K_STIFFNESS; // Push FRONT (+)
        local dampingForce = -velocity.z * K_DAMPING;

        forceZ = springForce + dampingForce;
        if (forceZ < 0.0) forceZ = 0.0;
    }
    // --- Front Wall ---
    else if (gPosition.z > WALL_LIMIT - 0.01) {
		gTouchedFaceOrientation.z = 1;
        local perforation = gPosition.z - WALL_LIMIT;
        local springForce = -perforation * K_STIFFNESS; // Push BACK (-)
        local dampingForce = -velocity.z * K_DAMPING;

        forceZ = springForce + dampingForce;
        if (forceZ > 0.0) forceZ = 0.0;
    } else {
		gTouchedFaceOrientation.z = 0;
	}

	// --- Safety clamp ---
	const MAX_FORCE = 20.0;
	if (forceX > MAX_FORCE) forceX = MAX_FORCE;
	if (forceX < -MAX_FORCE) forceX = -MAX_FORCE;
	if (forceY > MAX_FORCE) forceY = MAX_FORCE;
	if (forceY < -MAX_FORCE) forceY = -MAX_FORCE;
	if (forceZ > MAX_FORCE) forceZ = MAX_FORCE;
	if (forceZ < -MAX_FORCE) forceZ = -MAX_FORCE;

	gBoundaryForce.setforce(forceX, forceY, forceZ);
}

function executeEffect (velocity, deltaTime) {
	switch (gEffectType) {
		case gEffectTypeTable.noeffect:
			gMovementForce.setforce(0.0, 0.0, 0.0);
			break;

		case gEffectTypeTable.rock:
			if (gTouchedFaceOrientation.x == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'x') >= ROCK_THRESHOLD) {
					gRockRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.x == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'x') >= ROCK_THRESHOLD) {
					gRockRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}

			if (gTouchedFaceOrientation.y == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'y') >= ROCK_THRESHOLD) {
					gRockRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.y == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'y') >= ROCK_THRESHOLD) {
					gRockRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}

			if (gTouchedFaceOrientation.z == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'z') >= ROCK_THRESHOLD) {
					gRockRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.z == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'z') >= ROCK_THRESHOLD) {
					gRockRecoilPull.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}
			/*if (calc_2d_distance(gPosition, gTextureAnchor) >= ROCK_THRESHOLD) {
				//gRockRecoilBack.fire();
				gTextureAnchor.x = gPosition.x;
				gTextureAnchor.y = gPosition.y;
				gTextureAnchor.z = gPosition.z;
			}*/
			break;

		case gEffectTypeTable.sandpaper:
			if (gTouchedFaceOrientation.x == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'x') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.x == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'x') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}

			if (gTouchedFaceOrientation.y == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'y') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.y == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'y') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}

			if (gTouchedFaceOrientation.z == -1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'z') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPush.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			} else if (gTouchedFaceOrientation.z == 1) {
				if (calc_2d_distance(gPosition, gTextureAnchor, 'z') >= SANDPAPER_THRESHOLD) {
					gSandpaperRecoilPull.fire();
					gTextureAnchor.x = gPosition.x;
					gTextureAnchor.y = gPosition.y;
					gTextureAnchor.z = gPosition.z;
				}
			}

			/*if (calc_2d_distance(gPosition, gTextureAnchor) >= SANDPAPER_THRESHOLD) {
				gSandpaperRecoil.fire();
				gTextureAnchor.x = gPosition.x;
				gTextureAnchor.y = gPosition.y;
				gTextureAnchor.z = gPosition.z;
			}*/
			break;

		case gEffectTypeTable.oil:
			// --- Movement-based restorative/damping force  ---
			const K_OIL = 15.0;

			local fx = -K_OIL * velocity.x;
			local fy = -K_OIL * velocity.y;
			local fz = -K_OIL * velocity.z;

			// Clamp and apply force
			if (fx > 20.0) fx = 20.0; if (fx < -20.0) fx = -20.0;
			if (fy > 20.0) fx = 20.0; if (fy < -20.0) fy = -20.0;
			if (fz > 20.0) fx = 20.0; if (fz < -20.0) fz = -20.0;

			gMovementForce.setforce(fx, fy, fz);
			break;


		case gEffectTypeTable.spring:
			const K_SPRING = 150.0; // Spring constant, tunable.
			// Spring's resting position, important for f = -kx equation
			local spring_resting_point = { x = 0.0, y = 0.0, z = 0.0 };
			local fx = -K_SPRING * (gPosition.x - spring_resting_point.x);
			local fy = -K_SPRING * (gPosition.y - spring_resting_point.y);
			local fz = -K_SPRING * (gPosition.z - spring_resting_point.z);

			// Clamp the force
			if (fx > 10.0) fx = 10.0; if (fx < -10.0) fx = -10.0;
			if (fy > 10.0) fx = 10.0; if (fy < -10.0) fy = -10.0;
			if (fz > 10.0) fx = 10.0; if (fz < -10.0) fz = -10.0;

			gMovementForce.setforce(fx, fy, fz);
			break;


		case gEffectTypeTable.water:
			// Viscosity
			const K_H20 = 5.0;
			local fx = -K_H20 * velocity.x;
			local fy = -K_H20 * velocity.y;
			local fz = -K_H20 * velocity.z;

			// Flow momentum (accumulate velocity over time)
			const FLOW_GAIN = 100.0;
			const FLOW_DECAY = 0.95; // Simple decay multiplier by frame

			gWaterMomentum.x += velocity.x * FLOW_GAIN * deltaTime;
			gWaterMomentum.y += velocity.y * FLOW_GAIN * deltaTime;
			gWaterMomentum.z += velocity.z * FLOW_GAIN * deltaTime;

			// Apply decay
			gWaterMomentum.x *= FLOW_DECAY;
			gWaterMomentum.y *= FLOW_DECAY;
			gWaterMomentum.z *= FLOW_DECAY;

			// Apply residual force
			const K_RESID = 3.5;
			fx += -K_RESID * gWaterMomentum.x;
			fy += -K_RESID * gWaterMomentum.y;
			fz += -K_RESID * gWaterMomentum.z;

			if (fx > 20.0) fx = 20.0; if (fx < -20.0) fx = -20.0;
			if (fy > 20.0) fx = 20.0; if (fy < -20.0) fy = -20.0;
			if (fz > 20.0) fx = 20.0; if (fz < -20.0) fz = -20.0;

			gMovementForce.setforce(fx, fy, fz);
			break;


		default:
			print("Unknown effect type\n");
			break;
	}
}

// ------------------------------------------------------------
// activate or deactivate the effects stacks
// ------------------------------------------------------------
function ConnectOrDisconnectStacks (deviceHandle, bConnect) {
	// Unlocking the device list on stacks
	gEffectsStack.setdevicelock(false);
	gControlBoxStack.setdevicelock(false);
	gMovementStack.setdevicelock(false);
	gBoundaryStack.setdevicelock(false);

	if (bConnect) {
		// add the device to the stacks, input slot 0
		gEffectsStack.adddevice(deviceHandle, 0);
		gControlBoxStack.adddevice(deviceHandle, 0);
		gMovementStack.adddevice(deviceHandle, 0);
		gBoundaryStack.adddevice(deviceHandle, 0);
	} else {
		// remove the device from the stacks, input slot 0
		gEffectsStack.removedevice(deviceHandle, 0);
		gControlBoxStack.removedevice(deviceHandle, 0);
		gMovementStack.removedevice(deviceHandle, 0);
		gBoundaryStack.removedevice(deviceHandle, 0);
	}

	// lock the device list on the stacks
	gEffectsStack.setdevicelock(true);
	gControlBoxStack.setdevicelock(true);
	gMovementStack.setdevicelock(true);
	gBoundaryStack.setdevicelock(true);

	if (bConnect) {
		// connect the stacks to the device for output
		deviceconnectstack(deviceHandle, gEffectsStack);
		deviceconnectstack(deviceHandle, gControlBoxStack);
		deviceconnectstack(deviceHandle, gMovementStack);
		deviceconnectstack(deviceHandle, gBoundaryStack);
	} else {
		// disconnect the stacks from the device
		devicedisconnectstack(deviceHandle, gEffectsStack);
		devicedisconnectstack(deviceHandle, gControlBoxStack);
		devicedisconnectstack(deviceHandle, gMovementStack);
		devicedisconnectstack(deviceHandle, gBoundaryStack);
	}
}
//-------------------------------------------------------------
// Initialize this script
// Called once when this script is first loaded
//-------------------------------------------------------------
function HapticsInitialize (registryConfigHandle)
{
	print("Initialize Script\n");
	createSocketConnection(); // SOCKET INITIALIZATION
	gControlBox = controlbox(effectparameters("_DefaultControlBox", gControlBoxStack), gControlBoxStack);
	if (gControlBox != null) {
		setinputeffect(gControlBox);
	}
}


//-------------------------------------------------------------
// Activate this script
// Called whenever this script becomes active (such as after
// returning to the application this script is attached to
// after switching to another window)
//-------------------------------------------------------------
function HapticsActivated (deviceHandle)
{
	ConnectOrDisconnectStacks(deviceHandle, true);
	// launch the movement force
	gMovementForce = constantforce(gMovementEffectParameters, gMovementStack);
	gBoundaryForce = constantforce(gBoundaryEffectParameters, gBoundaryStack);
	print("Script Activated\n");
}


//-------------------------------------------------------------
// Run this script
// Called repeatedly while this acript is active
//-------------------------------------------------------------
function HapticsThink (deviceHandle)
{
	// --- Calculate the delta time ---
	gFrameCounter += 1;
	gScriptTime.update();
	local currentTime = gScriptTime.elapsedseconds();
	local deltaTime = currentTime - gLastTime;

	// --- Send position data at a fixed time ---
	local MAX_DELTA = 0.05 // 50 ms
	if (deltaTime > MAX_DELTA) {
		deltaTime = MAX_DELTA;
	}

	// Socket and command processing
	// Drain the socket: Read ALL pending commands for this frame
	local cmd = getCommand();
	while (cmd != null && cmd.type != 100) {
		gCommandQueue.enqueue(cmd);
		cmd = getCommand();
	}

	// Process the queue
	while (!gCommandQueue.isEmpty()) {
		local q_item = gCommandQueue.peek();
		gCommandQueue.dequeue();
		decodeCommand(q_item, deltaTime);
	}

	// --- Read device position ---
	gPosition.x = deviceaxis(deviceHandle, 0);
	gPosition.y = deviceaxis(deviceHandle, 1);
	gPosition.z = deviceaxis(deviceHandle, 2);

	// Calculate current velocity
	local velocity = { x = 0.0, y = 0.0, z = 0.0 };
	if (deltaTime > 0.000001) {
		velocity.x = (gPosition.x - gLastFramePos.x) / deltaTime;
		velocity.y = (gPosition.y - gLastFramePos.y) / deltaTime;
		velocity.z = (gPosition.z - gLastFramePos.z) / deltaTime;
	}

	if (gIsModelActive) {
		// Calculate the proxy
		local proxy = computeProxy(gPosition, gModelData);

		// Calculate force
		// Note: vector direction matters. We want to pull TOWARDS the proxy.
		local k = gModelData.stiffness;
		local k_damp = 15.0; // Damping to prevent buzzing

		local fx = (proxy.x - gPosition.x) * k;
		local fy = (proxy.y - gPosition.y) * k;
		local fz = (proxy.z - gPosition.z) * k;

		// Apply damping (resistance to velocity)
		fx = fx - (velocity.x * k_damp);
		fy = fy - (velocity.y * k_damp);
		fz = fz - (velocity.z * k_damp);

		// Apply to Falcon
		// Only apply force if we are actually penetrating (or just always apply to attract)
		// For a solid wall, we usually only push if inside.

		local dist = calc_3d_distance(gPosition, proxy);
		// The computeProxy function returns the surface point
		// If dist > 0, it means we are away from the surface point.
		// But computeProxy logic usually returns 'gPosition' if we are outside
		// Let us trust the computeProxy logic for now:

		gBoundaryForce.setforce(fx, fy, fz);
	} else if (gIsSphereActive == 0) {
		executeCubeBoundaries(velocity);
		executeEffect(velocity, deltaTime);
	}
	//executeCubeBoundaries(velocity);
	//executeEffect(velocity, deltaTime);

	gScriptTime.update(); // Force a clock refresh
	local executionTime = gScriptTime.elapsedseconds(); // T1

	// DEBUGGING: Measure frequency every 1000 frames (approx once per second)
    if (gFrameCounter % 1000 == 0) {
        // Convert to microseconds for readability
		print("Execution time: " + (executionTime * 100000.0) + "us\n");

		// Calculate load percentage (assuming 1 ms target budget)
		local loadPercent = (executionTime / 0.001) * 100.0;
		print("CPU Load: " + loadPercent + " %\n");
    }

	gTimeSinceLastSend += deltaTime;
	if (gTimeSinceLastSend >= SEND_INTERVAL) {

		sendPosition(gPosition.x, gPosition.y, gPosition.z);
		// Reset the timer. Using modulo is robust for very slow frames.
		gTimeSinceLastSend = gTimeSinceLastSend % SEND_INTERVAL;
	}

	// --- Falcon button presses ---

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LOGO)) {
		print("Logo\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_TRIANGLE)) {
		print("Triangle\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LIGHTNING)) {
		print("Lightning\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_PLUS)) {
		print("Plus\n")
	}

	gLastFramePos.x = gPosition.x;
	gLastFramePos.y = gPosition.y;
	gLastFramePos.z = gPosition.z;
	// --- Get the next frame ready ---
	gScriptTime.update();
	gLastTime = gScriptTime.elapsedseconds() + executionTime;
}


//-------------------------------------------------------------
// Deactivate this script
// called whenever this script stops being active (such as if
// you switch to another window)
//-------------------------------------------------------------
function HapticsDeactivated (deviceHandle)
{
	ConnectOrDisconnectStacks(deviceHandle, false);
	// remove the movement force
	gMovementForce.dispose();
	gMovementForce = null;

	// remove the boundary force
	gBoundaryForce.dispose();
	gBoundaryForce = null;
	print("Script Deactivated\n");
}


//-------------------------------------------------------------
// Shutdown this script
// called when this script is cancelled and unloaded
//-------------------------------------------------------------
function HapticsShutdown (  )
{
	closeSocketConnection();    // Close the socket
	print("Shutdown Script\n");
}

