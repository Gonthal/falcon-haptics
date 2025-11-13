# Falcon Haptics GUI

This project is a client-server application for controlling and visualizing a Novint Falcon haptic device.

* **Client**: A C++ DLL (`SecondFalcon/`) used by a Squirrel script (`SquirrelScripts/`) to communicate from the haptics environment.
* **Server**: A Python server (`Python/`) with a DearPyGUI interface for real-time visualization.

## Setup

### C++ Client
1.  Open `SecondFalcon/SecondFalcon.sln` in Visual Studio.
2.  Make sure you have the Novint Falcon SDK installed and configured.
3.  Build the solution to produce `SecondFalcon.dll`.

### Python Server
1.  Navigate to the `Python/` directory.
2.  (Recommended) Create a virtual environment: `python -m venv venv`
3.  Activate it: `source venv/bin/activate` (or `.\venv\Scripts\activate` on Windows)
4.  Install dependencies: `pip install dearpygui`

## Running the Application
1.  Start the Python server: `python Python/interface.py`
2.  Load the `SecondFalcon.dll` and run the `fgen_tesis_test_2608.nut` script in your haptics software.