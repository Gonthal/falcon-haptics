import socket
import struct
from enum import IntEnum

HOST = '127.0.0.1' # Standard loopback interface address (localhost)
PORT = 27015

class FalconCommand(IntEnum):
    CMD_IDLE         = 0x0000,
    CMD_PRINT_STATUS = 0x0001,

def recv_exact(conn, n):
    buf = b''
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((HOST, PORT))
    s.listen()
    conn, addr = s.accept()
    with conn:
        print(f"Connected by {addr}")
        while True:
            # Example 1: read exactly 3 floats (12 bytes)
            raw_data = recv_exact(conn, 16)
            if raw_data is None:
                break
            type, length, x, y, z = struct.unpack('!hhfff', raw_data) # '!': network(big-endian), 'f': 32-bit float
            print(f"Received floats: {x}, {y}, {z}")

            # echo back the same floats in network order
            # conn.sendall(struct.pack('!fff', x, y, z))
            conn.sendall(struct.pack('!hhfff', FalconCommand.CMD_PRINT_STATUS.value, 12, x, y, z))