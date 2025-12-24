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
gLastPosition <- {
	x = 0.0,
	y = 0.0,
	z = 0.0
};
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
const SEND_INTERVAL = 0.02;    // Send data every 0.02 seconds (50 Hz)
const READ_INTERVAL = 0.002	   // Read data every 0.002 seconds (500 Hz)
gTimeSinceLastSend <- 0.0;     // time since last data send
gTimeSinceLastRead <- 0.0;

//========================================================
// stacks
//========================================================

// --- Create the effect stack ---
gEffectsStack <- effectstack("effects", 1.0);      // creating default Falcon effect stack
gEnvelopeEffectID <- registereffect("Envelope");   // registering           // no fall off time at end of effect

// --- ROCK RECOIL ---
gRockRecoil <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gRockRecoil.setvarelement("force", 0, 0);   // 0 newtons right-wards
gRockRecoil.setvarelement("force", 1, 0);   // 0 newtons upwards
gRockRecoil.setvarelement("force", 2, 20);  // 20 newtons backwards
gRockRecoil.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gRockRecoil.setvar("hold", 0);              // no hold time once at maximum force
gRockRecoil.setvar("decay", 0);             // no fall off time at end of effect
const ROCK_THRESHOLD = 0.01;  // 1 cm

// --- SANDPAPER RECOIL ---
gSandpaperRecoil <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gSandpaperRecoil.setvarelement("force", 0, 0);   // 0 newtons right-wards
gSandpaperRecoil.setvarelement("force", 1, 0);   // 0 newtons upwards
gSandpaperRecoil.setvarelement("force", 2, 5);   // 5 newtons backwards
gSandpaperRecoil.setvar("attack", 10);           // ramp up to the force over 10 milliseconds
gSandpaperRecoil.setvar("hold", 0);              // no hold time once at maximum force
gSandpaperRecoil.setvar("decay", 0);             // no fall off time at end of effect
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


// --- Create the control box stack ---
gControlBoxStack <- effectstack("ControlBox", 1.0);
// registering a control box effect
gControlBoxEffectID <- registereffect("ControlBox");
gControlBox <- null; // variable to store the control box in


gTestControlBox <- null;

// --- Create the movement effect stack ---
// Create a separate effects stack for movement forces
gMovementStack <- effectstack("movement", 1.0);
//Create a constant effect type
gConstantEffectID <- registereffect("Constant");
// create the effect parameters for a constant effect for use as a movement force
gMovementEffectParameters <- effectparameters(gConstantEffectID, gMovementStack);
gMovementForce <- null;
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

function calc_2d_distance(pos1, pos2) {
	local dx = pos2.x - pos1.x;
	local dy = pos2.y - pos1.y;
	return sqrt(dx*dx + dy*dy);
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

function executeBoundaryForce(directions) {
	return null;
}

function executeEffect (velocity, deltaTime) {
	switch (gEffectType) {
		case gEffectTypeTable.noeffect:
			gMovementForce.setforce(0.0, 0.0, 0.0);
			break;

		case gEffectTypeTable.rock:
			if (calc_2d_distance(gPosition, gTextureAnchor) >= ROCK_THRESHOLD) {
				gRockRecoil.fire();
				gTextureAnchor.x = gPosition.x;
				gTextureAnchor.y = gPosition.y;
				gTextureAnchor.z = gPosition.z;
			}
			break;

		case gEffectTypeTable.sandpaper:
			if (calc_2d_distance(gPosition, gTextureAnchor) >= SANDPAPER_THRESHOLD) {
				gSandpaperRecoil.fire();
				gTextureAnchor.x = gPosition.x;
				gTextureAnchor.y = gPosition.y;
				gTextureAnchor.z = gPosition.z;
			}
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

	if (bConnect) {
		// add the device to the stacks, input slot 0
		gEffectsStack.adddevice(deviceHandle, 0);
		gControlBoxStack.adddevice(deviceHandle, 0);
		gMovementStack.adddevice(deviceHandle, 0);
	} else {
		// remove the device from the stacks, input slot 0
		gEffectsStack.removedevice(deviceHandle, 0);
		gControlBoxStack.removedevice(deviceHandle, 0);
		gMovementStack.removedevice(deviceHandle, 0);
	}

	// lock the device list on the stacks
	gEffectsStack.setdevicelock(true);
	gControlBoxStack.setdevicelock(true);
	gMovementStack.setdevicelock(true);

	if (bConnect) {
		// connect the stacks to the device for output
		deviceconnectstack(deviceHandle, gEffectsStack);
		deviceconnectstack(deviceHandle, gControlBoxStack);
		deviceconnectstack(deviceHandle, gMovementStack);
	} else {
		// disconnect the stacks from the device
		devicedisconnectstack(deviceHandle, gEffectsStack);
		devicedisconnectstack(deviceHandle, gControlBoxStack);
		devicedisconnectstack(deviceHandle, gMovementStack);
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

	gKeyInput.update();

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
		/*if (gEffectType == gEffectTypeTable.noeffect) {
			print("Rock!\n");
			gEffectType = gEffectTypeTable.rock;
		} else if (gEffectType == gEffectTypeTable.rock) {
			print("Sandpaper!\n");
			gEffectType = gEffectTypeTable.sandpaper;
		} else if (gEffectType == gEffectTypeTable.sandpaper) {
			print("Oil!\n");
			gEffectType = gEffectTypeTable.oil;
		} else if (gEffectType == gEffectTypeTable.oil) {
			print("Water!\n");
			gEffectType = gEffectTypeTable.water;
		} else {
			print("No effect!\n");
			gEffectType = gEffectTypeTable.noeffect;
		}*/
		print("Logo\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_TRIANGLE)) {
		// cmd is a table: { type: ..., data = [...] }
		/*local cmd = getCommand();

		if (cmd.type != 100) {
			print("The effect type is " + cmd.type + "\n");
			gEffectType = cmd.type;
		} else {
			print("ERROR: invalidad command type \n");
		}*/

		/*if (cmd.type != 0) {
			print("Received command type: " + cmd.type + "\n");

			// Access payload data array
			if (cmd.data.len() >= 3) {
				print("Payload ");
				foreach (idx, val in cmd.data) {
					print(val + " ");
				}
				print("\n");

				//local val1 = cmd.data[0];
				//local val2 = cmd.data[1];
				//local val3 = cmd.data[2];
				//print("Payload: " + val1 + ", " + val2 + ", " + val3 + "\n");
			} else {
				print("Something went wrong with the command. \n");
			}
		}*/
		print("Triangle\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LIGHTNING)) {
		/*gTestControlBox.setvar("deadband", 0.3)
		gControlBox = controlbox(gTestControlBox, gControlBoxStack);
		if (gControlBox != null) {
			setinputeffect(gControlBox);
		} else {
			print("Oops, something went wrong with the control box. \n")
		}*/
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

