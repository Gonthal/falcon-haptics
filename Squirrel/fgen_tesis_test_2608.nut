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

gPosition <- {
    x = 0.0,
    y = 0.0,
    z = 0.0
};

socket_result <- 0;

gScriptTime <- timekeeper();   // setup time checker, used for delta time
gLastTime <- 0.0;			   // time at the end of the frame, initially set to 0
const SEND_INTERVAL = 0.02;    // Send data every 0.02 seconds (50 Hz)
gTimeSinceLastSend <- 0.0;

//========================================================
// stacks
//========================================================

gEffectStack <- effectstack("effects", 1.0);      // creating default Falcon effect stack
gEnvelopeEffectID <- registereffect("Envelope");  // registering

// --- Create a simple recoil effect and set its default parameters
gSimpleRecoil <- effectparameters(gEnvelopeEffectID, gEffectStack); // create the effect
gSimpleRecoilTable <- {};
gSimpleRecoilTable.xforce <- 0;
gSimpleRecoilTable.yforce <- 0;
gSimpleRecoilTable.zforce <- 20;
gSimpleRecoilTable.attack <- 30;
gSimpleRecoilTable.hold <- 0;
gSimpleRecoilTable.decay <- 0;
gSimpleRecoil.setvarelement("force", 0, gSimpleRecoilTable.xforce);  // 0 newtons right-wards
gSimpleRecoil.setvarelement("force", 1, gSimpleRecoilTable.yforce);  // 0 newtons upwards
gSimpleRecoil.setvarelement("force", 2, gSimpleRecoilTable.zforce); // 20 newtons backwards
gSimpleRecoil.setvar("attack", gSimpleRecoilTable.attack); // ramp up to the force over 30 milliseconds
gSimpleRecoil.setvar("hold", gSimpleRecoilTable.hold);    // no hold time once at maximum force
gSimpleRecoil.setvar("decay", gSimpleRecoilTable.decay);   // no fall off time at end of effect

//-------------------------------------------------------------
// Initialize this script
// Called once when this script is first loaded
//-------------------------------------------------------------
function HapticsInitialize (registryConfigHandle)
{
	print("Initialize Script\n");
	createSocketConnection(); // SOCKET INITIALIZATION
}


//-------------------------------------------------------------
// Activate this script
// Called whenever this script becomes active (such as after
// returning to the application this script is attached to
// after switching to another window)
//-------------------------------------------------------------
function HapticsActivated (deviceHandle)
{
	// setup log file
	// debugLog_open();

	gEffectStack.setdevicelock(false);				// unlocking the device list on stack
	gEffectStack.adddevice(deviceHandle, 0);		// adding the device to the stack input slot 0
	gEffectStack.setdevicelock(true);				// locking the device list on stack
	deviceconnectstack(deviceHandle, gEffectStack); // connect the stack to the device for output

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

	// --- Read device position ---
	gPosition.x = deviceaxis(deviceHandle, 0);
	gPosition.y = deviceaxis(deviceHandle, 1);
	gPosition.z = deviceaxis(deviceHandle, 2);

	// --- Send position data at a fixed time ---
	gTimeSinceLastSend += deltaTime;
	//print("Variables: " + currentTime + " : " + gLastTime + " : " + deltaTime + " : " + gTimeSinceLastSend + "\n");

	if (gTimeSinceLastSend >= SEND_INTERVAL) {

		sendPosition(gPosition.x, gPosition.y, gPosition.z);
		// Reset the timer. Using modulo is robust for very slow frames.
		gTimeSinceLastSend = gTimeSinceLastSend % SEND_INTERVAL;
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LOGO)) {
		if (gSimpleRecoilTable.zforce == 20) {
			gSimpleRecoilTable.zforce = 40;
		} else {
			gSimpleRecoilTable.zforce = 20;
		}
		gSimpleRecoil.setvarelement("force", 2, gSimpleRecoilTable.zforce);
		print("Logo\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_TRIANGLE)) {
		local header = getCommand();

		print("Received header: " + header + "\n");

		/*if (header == 100) {
			print("Nothing has been received...\n");
		} else {
			print("Received command and length: " + header + " : " + len + "\n");
		}*/
		print("Triangle\n");
	}

	if (devicewasbuttonjustpressed(deviceHandle, FALCON_LIGHTNING)) {
		// launch simple recoil effect
		gSimpleRecoil.fire();
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
	// close log file
	// debugLog_close();

	gEffectStack.setdevicelock(false);				   // unlocking the device list on stack
	gEffectStack.removedevice(deviceHandle, 0);		   // removing the device to the stack input slot 0
	gEffectStack.setdevicelock(true);				   // locking the device list on stack
	devicedisconnectstack(deviceHandle, gEffectStack); // disconnect the stack to the device for output

	print("Script Deactivated\n");
}


//-------------------------------------------------------------
// Shutdown this script
// called when this script is cancelled and unloaded
//-------------------------------------------------------------
function HapticsShutdown (  )
{
	closeSocketConnection(); // Close the socket
	print("Shutdown Script\n");
}

