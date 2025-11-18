import asyncio
import struct
import queue
import socket
from enum import IntEnum

# --- Constants ---
HOST = '127.0.0.1' # Standard loopback interface address (localhost)
PORT = 27015

class FalconCommand(IntEnum):
    CMD_IDLE         = 0x0000
    CMD_PRINT_STATUS = 0x0001

# --- Write loop --- 
async def write_loop(writer, command_queue) -> None:
    """
    Awaits commands from the command_queue and sends them to the client.
    """
    print("Starting write loop...")
    while True:
        try:
            # get_nowait() is non-blocking.
            command = command_queue.get_nowait()

            # We have a command. Pack and send it.
            cmd_type = command['type']
            payload = command['payload']

            print(f"[write_loop] Sending command {cmd_type} with payload {payload}")

            # Pack payload generically as N floats (for now)
            fmt = '!' + ('f' * len(payload))
            packed_payload = struct.pack(fmt, *payload)

            packed_header = struct.pack('!hh', cmd_type, len(packed_payload))

            # Send header + payload together and drain once
            writer.write(packed_header + packed_payload)
            await writer.drain()
        except queue.Empty:
            # No command in queue, sleep for a bit to yield control
            # This prevents this loop from consumin 100% CPU
            await asyncio.sleep(0.02) # Check ~50 times per second
        except (ConnectionResetError, BrokenPipeError):
            print("Write loop: Client disconnected")
            break

# --- Read loop ---
async def read_loop(reader, data_queue) -> None:
    """
    Reads data from the client and puts it into the data_queue.
    """
    print("Starting read loop...")
    while True:
        try:
            # Read the 4-byte header (type and length)
            header_data = await reader.readexactly(4)
            msg_type, msg_len = struct.unpack('!hh', header_data)

            # Read the payload
            payload = await reader.readexactly(msg_len)

            if msg_type == 1: # MSG_POSITION
                x, y, z = struct.unpack('!fff', payload)
                # Scale the values from m to cm
                x *= 100.0
                y *= 100.0
                z *= 100.0
                #print(f"Received position: ({x:.2f}, {y:.2f}, {z:.2f})")
                data_queue.put((x, y, z))

        except (asyncio.IncompleteReadError, ConnectionResetError):
            print("Read loop: Client disconnected")
            break

# --- Network Communication Handler ---
async def handle_client(reader, writer, data_queue, command_queue) -> None:
    """
    Manages a single client connection by running read and write loops concurrently.
    """
    peername = writer.get_extra_info('peername')
    print(f"Connected by {peername}")

    # Disable Nagle's algorithm (TCP_NODELAY)
    sock = writer.get_extra_info('socket')
    if sock is not None:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    # Create two concurrent tasks
    read_task = asyncio.create_task(read_loop(reader, data_queue))
    write_task = asyncio.create_task(write_loop(writer, command_queue))

    # Wait for either task to complete (which signal disconnects)
    await asyncio.gather(read_task, write_task)

    print(f"Client {peername} connection closed.")
    writer.close()
    try:
        await writer.wait_closed()
    except Exception:
        pass


# --- Server Starter ---
async def start_server(data_queue, command_queue) -> None:
    """
    Starts the TCP server and configures it to use the handle_client coroutine.
    """
    # The lambda function ensures that our data_queue is passed to each
    # new instance of the handle_client coroutine.
    server = await asyncio.start_server(
        lambda r, w: handle_client(r, w, data_queue, command_queue),
        HOST, PORT)
    
    print(f"Server has started and is listening on {HOST}:{PORT}")

    async with server:
        await server.serve_forever()
        