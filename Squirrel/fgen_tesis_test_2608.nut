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

socket_result <- 0;

gCommandQueue <- CommandQueue();

gKeyInput <- inputlistener();
gScriptTime <- timekeeper();   // setup time checker, used for delta time
gLastTime <- 0.0;			   // time at the end of the frame, initially set to 0
const SEND_INTERVAL = 0.01;    // Send data every 0.02 seconds (50 Hz)
const READ_INTERVAL = 0.002	   // Read data every 0.002 seconds (500 Hz)
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

function decodeCommand(cmd) {
	if (cmd.type == 100) return; // we ignore errors for now
	print("Executing command: " + cmd.type + "\n");

	//local cmd = gCommandQueue.peek();

	if (cmd.type >= 0 && cmd.type <= 5) {
		print("Command is type " + cmd.type + "\n");
		gEffectType = cmd.type;
	} else {
		// executeBoundary(cmd.data)
	}

	// Free the first position of the queue
	//gCommandQueue.dequeue();
}

function executeCubeBoundaries (velocity) {
	local forceX = 0.0;
	local forceY = 0.0;
	local forceZ = 0.0;

	// --- Configuration ---
	// Distance from the center to the wall (the units are in meters)
	const WALL_LIMIT = 0.03;
	local outer_limit = WALL_LIMIT + gPosition.z * 0.5;

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
	// we will need to check out this whole control box thing
	// or let it flop
	//gTestControlBox = effectparameters(gControlBoxEffectID, gControlBoxStack);
	//gTestControlBox.setvar("deadband", 0.4);
	//gControlBox = controlbox(gTestControlBox, gControlBoxStack);
	// launch the control box
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

	/*gKeyInput.update();*/

	// optional debug
	// if (gFrameCounter % 100 = 0) {
	// 	print("Delta Time: " + deltaTime + "\n");
    //}

	// Socket and command processing
	// Drain the socket: Read ALL pending commands for this frame
	local cmd = getCommand();
	while (cmd.type != 100) {
		gCommandQueue.enqueue(cmd);
		cmd = getCommand();
	}

	// Process the queue
	while (!gCommandQueue.isEmpty()) {
		local q_item = gCommandQueue.peek();
		gCommandQueue.dequeue();
		decodeCommand(q_item);
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

	executeCubeBoundaries(velocity);
	executeEffect(velocity, deltaTime);

	gTimeSinceLastSend += deltaTime;
	if (gTimeSinceLastSend >= SEND_INTERVAL) {

		sendPosition(gPosition.x, gPosition.y, gPosition.z);
		// Reset the timer. Using modulo is robust for very slow frames.
		gTimeSinceLastSend = gTimeSinceLastSend % SEND_INTERVAL;
	}

	// --- Keyboard presses ---

	// adjust the movement effect based on button presses
	/*if (gKeyInput.isinputdown(KEY_A)) {
		gMovementForce.setforce(-20, 0, 0);
	} else {
		gMovementForce.setforce(0, 0, 0);
	}*/

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
	gLastTime = gScriptTime.elapsedseconds();
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

