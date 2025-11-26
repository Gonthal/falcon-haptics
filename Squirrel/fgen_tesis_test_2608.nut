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
// global variables
//========================================================

gFrameCounter <- 0;
gStackConnected <- false;

gPosition <- {
    x = 0.0,
    y = 0.0,
    z = 0.0
};
gLastPosition <- {
	x = 0.0,
	y = 0.0,
	z = 0.0
};

// Add water momentum state (keeps residual flow after movement)
gWaterMomentum <- {
	x = 0.0,
	y = 0.0,
	z = 0.0
}

socket_result <- 0;

gKeyInput <- inputlistener();
gScriptTime <- timekeeper();   // setup time checker, used for delta time
gLastTime <- 0.0;			   // time at the end of the frame, initially set to 0
const SEND_INTERVAL = 0.02;    // Send data every 0.02 seconds (50 Hz)
gTimeSinceLastSend <- 0.0;     // time since last data send


//========================================================
// stacks
//========================================================

// --- Create the effect stack ---
gEffectsStack <- effectstack("effects", 1.0);      // creating default Falcon effect stack
gEnvelopeEffectID <- registereffect("Envelope");   // registering           // no fall off time at end of effect

// --- BUMPY RECOIL ---
gBumpyRecoil <- effectparameters(gEnvelopeEffectID, gEffectsStack); // create the effect
gBumpyRecoil.setvarelement("force", 0, 0);   // 0 newtons right-wards
gBumpyRecoil.setvarelement("force", 1, 0);   // 0 newtons upwards
gBumpyRecoil.setvarelement("force", 2, 20);  // 20 newtons backwards
gBumpyRecoil.setvar("attack", 10);           // ramp up to the force over 30 milliseconds
gBumpyRecoil.setvar("hold", 0);              // no hold time once at maximum force
gBumpyRecoil.setvar("decay", 0);             // no fall off time at end of effect
const BUMPY_THRESHOLD = 0.01;  // 1 cm

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
gEffectTypeTable.bumpy     <- 1;
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
function calc_distance (pos1, pos2) {
	local dx = pos2.x - pos1.x;
	local dy = pos2.y - pos1.y;
	local dz = pos2.z - pos1.z;
	return sqrt(dx*dx + dy*dy + dz*dz);
}

function getSign(x)
{
    if (x > 0) return 1;
    if (x < 0) return -1;
    return 0;
}

function get_movement_direction (pos1, pos2) {
	local direction = {
		x = 0,
		y = 0,
		z = 0
	};

	direction.x = getSign(pos2.x - pos1.x);
	direction.y = getSign(pos2.y - pos1.y);
	direction.z = getSign(pos2.z - pos1.z);

	return direction;
}

function executeEffect (deltaTime) {
	switch (gEffectType) {
		case gEffectTypeTable.noeffect:
			gMovementForce.setforce(0.0, 0.0, 0.0);
			break;

		case gEffectTypeTable.bumpy:
			if (calc_distance(gPosition, gLastPosition) >= BUMPY_THRESHOLD) {
				gBumpyRecoil.fire();
				gLastPosition.x = gPosition.x;
				gLastPosition.y = gPosition.y;
				gLastPosition.z = gPosition.z;
			}
			break;

		case gEffectTypeTable.sandpaper:
			if (calc_distance(gPosition, gLastPosition) >= SANDPAPER_THRESHOLD) {
				gSandpaperRecoil.fire();
				gLastPosition.x = gPosition.x;
				gLastPosition.y = gPosition.y;
				gLastPosition.z = gPosition.z;
			}
			break;

		case gEffectTypeTable.oil: {
			// --- Movement-based restorative/damping force (oppose motion on Z) ---
			// compute velocity (m/s) from position delta and deltaTime (avoid divide by zero)
			local velX = 0.0;
			local velY = 0.0;
			local velZ = 0.0;
			if (deltaTime > 0.000001) {
				velX = (gPosition.x - gLastPosition.x) / deltaTime;
				velY = (gPosition.y - gLastPosition.y) / deltaTime;
				velZ = (gPosition.z - gLastPosition.z) / deltaTime;
			}

			// simple damper (force opposite velocity). tune gains to safe values
			const KDX = 15.0;	 // damping gain (N per m/s)
			const KDY = 15.0;
			const KDZ = 45.0;
			//const KP = 0.0;		 // optional spring (N per m) if you want a restorative spring
			//local springZ = 0.0; // target position can be 0 or a chosen setpoint
			local forceX = -KDX * velX;
			local forceY = -KDY * velY;
			local forceZ = -KDZ * velZ;
			//local springForceZ = -KP * (gPosition.z - springZ);

			// combine and clamp to a safe force range
			const MAX_FORCE = 20.0;
			if (forceZ > MAX_FORCE) forceZ = MAX_FORCE;
			if (forceZ < -MAX_FORCE) forceZ = -MAX_FORCE;

			if (forceX > MAX_FORCE) forceX = MAX_FORCE;
			if (forceX < -MAX_FORCE) forceX = -MAX_FORCE;

			if (forceY > MAX_FORCE) forceY = MAX_FORCE;
			if (forceY < -MAX_FORCE) forceY = -MAX_FORCE;

			// apply combined force (X, Y, Z)
			gMovementForce.setforce(forceX, forceY, forceZ);

			gLastPosition.x = gPosition.x;
			gLastPosition.y = gPosition.y;
			gLastPosition.z = gPosition.z;

			break;
		}

		case gEffectTypeTable.spring {
			break;
		}

		case gEffectTypeTable.water: {
			// compute velocity on X, Y, Z
			local velX = 0.0;
			local velY = 0.0;
			local velZ = 0.0;
			if (deltaTime > 0.000001) {
				velX = (gPosition.x - gLastPosition.x) / deltaTime;
				velY = (gPosition.y - gLastPosition.y) / deltaTime;
				velZ = (gPosition.z - gLastPosition.z) / deltaTime;
			}

			// VISCOSITY: ordinary damping opposing instantaneous velocity
			const KD_WATER_X = 5.0;
			const KD_WATER_Y = 5.0;
			const KD_WATER_Z = 5.0;	// damping gain (N per m/s) - tuneable
			local viscousForceX = -KD_WATER_X * velX;
			local viscousForceY = -KD_WATER_Y * velY;
			local viscousForceZ = -KD_WATER_Z * velZ;

			// RESIDUAL FLOW: integrate recent velocity into a momentum state that decays slowly
			// Integration gain controls how much flow is "picked up" while moving
			const FLOW_INTEGRATION = 70.0 // tuneable
			gWaterMomentum.x += velX * FLOW_INTEGRATION * deltaTime;
			gWaterMomentum.y += velY * FLOW_INTEGRATION * deltaTime;
			gWaterMomentum.z += velZ * FLOW_INTEGRATION * deltaTime;

			// Decay the momentum over time so residual flow fades
			const FLOW_DECAY_RATE = 0.01; // per second (increase -> faster decay)
			local decayFactor = 1.0 - FLOW_DECAY_RATE * deltaTime;
			if (decayFactor < 0.0) decayFactor = 0.0;
			gWaterMomentum.x *= decayFactor;
			gWaterMomentum.y *= decayFactor;
			gWaterMomentum.z *= decayFactor;

			// Residual force tries to push opposite the stored momentum
			const K_RESIDUAL = 5.0 // strength of residual flow - tuneable
			local residualForceX = -K_RESIDUAL * gWaterMomentum.x;
			local residualForceY = -K_RESIDUAL * gWaterMomentum.y;
			local residualForceZ = -K_RESIDUAL * gWaterMomentum.z;

			// Combine forces and clamp to safe limits4
			local forceX = viscousForceX + residualForceX;
			local forceY = viscousForceY + residualForceY;
			local forceZ = viscousForceZ + residualForceZ;
			const MAX_FORCE = 20.0;

			if (forceX > MAX_FORCE) forceX = MAX_FORCE;
			if (forceX < -MAX_FORCE) forceX = -MAX_FORCE;
			if (forceY > MAX_FORCE) forceY = MAX_FORCE;
			if (forceY < -MAX_FORCE) forceY = -MAX_FORCE;
			if (forceZ > MAX_FORCE) forceZ = MAX_FORCE;
			if (forceZ < -MAX_FORCE) forceZ = -MAX_FORCE;

			// apply combined force (only on Z here)
			gMovementForce.setforce(forceX, forceY, forceZ);

			gLastPosition.x = gPosition.x;
            gLastPosition.y = gPosition.y;
            gLastPosition.z = gPosition.z;
			break;
		}

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
	//createSocketConnection(); // SOCKET INITIALIZATION
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
	gTimeSinceLastSend += deltaTime;
	local MAX_DELTA = 0.05 // 50 ms
	if (deltaTime > MAX_DELTA) {
		deltaTime = MAX_DELTA;
	}

	gKeyInput.update();

	// optional debug
	// if (gFrameCounter % 100 = 0) {
	// 	print("Delta Time: " + deltaTime + "\n");
    //}

	// --- Read device position ---
	gPosition.x = deviceaxis(deviceHandle, 0);
	gPosition.y = deviceaxis(deviceHandle, 1);
	gPosition.z = deviceaxis(deviceHandle, 2);


	//print("Variables: " + currentTime + " : " + gLastTime + " : " + deltaTime + " : " + gTimeSinceLastSend + "\n");

	if (gTimeSinceLastSend >= SEND_INTERVAL) {

		sendPosition(gPosition.x, gPosition.y, gPosition.z);
		// Reset the timer. Using modulo is robust for very slow frames.
		gTimeSinceLastSend = gTimeSinceLastSend % SEND_INTERVAL;
	}

	// Execute the current effect: none, bumpy, sandpaper, oil or water
	executeEffect(deltaTime);


	// --- Keyboard presses ---

	// adjust the movement effect based on button presses
	/*if (gKeyInput.isinputdown(KEY_A)) {
		gMovementForce.setforce(-4, 0, 0);
	} else {
		gMovementForce.setforce(0, 0, 0);
	}*/

	// --- Falcon button presses ---

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LOGO)) {
		if (gEffectType == gEffectTypeTable.noeffect) {
			print("Bumpy!\n");
			gEffectType = gEffectTypeTable.bumpy;
		} else if (gEffectType == gEffectTypeTable.bumpy) {
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
		}
		print("Logo\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_TRIANGLE)) {
		local header = getCommand();

		print("Received header: " + header + "\n");
		print("Triangle\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LIGHTNING)) {
		// launch simple recoil effect
		//gSimpleRecoil.fire();
		print("Lightning\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_PLUS)) {
		print("Plus\n")
	}

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
	//closeSocketConnection();    // Close the socket
	print("Shutdown Script\n");
}

