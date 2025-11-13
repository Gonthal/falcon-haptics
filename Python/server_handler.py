import asyncio
import struct
from enum import IntEnum

# --- Constants ---
HOST = '127.0.0.1' # Standard loopback interface address (localhost)
PORT = 27015

class FalconCommand(IntEnum):
    CMD_IDLE         = 0x0000,
    CMD_PRINT_STATUS = 0x0001,

# --- Network Communication Handler ---
async def handle_client(reader, writer, data_queue) -> None:
    """Comments..."""
    peername = writer.get_extra_info('peername')
    print(f"Connected by {peername}")
    while True:
        try:
            # Read the 4-byte header (type and length)
            header_data = await reader.readexactly(4)
            msg_type, msg_length = struct.unpack('!hh', header_data)
            
            # Read the payload based on the length of the header
            payload = await reader.readexactly(msg_length)

            if msg_type == FalconCommand.CMD_PRINT_STATUS.value:
                # Unpack the payload as three floats (x, y, z)
                x, y, z = struct.unpack('!fff', payload)
                # Scale the values from m to cm
                x *= 100.0
                y *= 100.0
                z *= 100.0
                print(f"Received position from {peername}: ({x:.2f}, {y:.2f}, {z:.2f})")

                # Put the received data into the thread-safe queue for the GUI
                data_queue.put((x, y, z))
        except (asyncio.IncompleteReadError, ConnectionResetError):
            print(f"Client {peername} disconnected.")
            break
        except Exception as e:
            print(f"An error ocurred with the client {peername}: {e}")
            break

# --- Server Starter ---
async def start_server(data_queue) -> None:
    """
    Starts the TCP server and configures it to use the handle_client coroutine.
    """
    # The lambda function ensures that our data_queue is passed to each
    # new instance of the handle_client coroutine.
    server = await asyncio.start_server(
        lambda r, w: handle_client(r, w, data_queue),
        HOST, PORT)
    
    print(f"Server started on {HOST}:{PORT}")

    async with server:
        await server.serve_forever()
        