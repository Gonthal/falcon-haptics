#include "stdafx.h"
#include "SocketClient.h"
#include "AppTypes.h"

WSADATA wsaData;
//SOCKET ConnectSocket = INVALID_SOCKET;
struct addrinfo* result = NULL;
struct addrinfo* ptr = NULL;
struct addrinfo hints;
char recvbuf[DEFAULT_BUFLEN];
int recvbuflen = DEFAULT_BUFLEN;
int iResult;

// Global variables for networking threads
static std::thread sender_thread;
static std::thread receiver_thread;
static std::atomic<bool> should_threads_run(false);
static SOCKET g_ClientSocket = INVALID_SOCKET;

// Thread-safe queues (use the class defined in the header)
static ThreadSafeQueue<Position> sending_pos_q;
static ThreadSafeQueue<FalconCommand> incoming_cmd_q;

/******************************************************************/
/* UTILITY FUNCTIONS DECLARATIONS                                 */
/******************************************************************/

int send_all(SOCKET s, const char* buf, int len) {
    int total_sent = 0;
    while (total_sent < len) {
        int sent = send(s, buf + total_sent, len - total_sent, 0);
        if (sent == SOCKET_ERROR) return SOCKET_ERROR;
        total_sent += sent;
    }
    return total_sent;
}

// recv_all: loops until requested bytes have been received or an error/EOF occurs
int recv_all(SOCKET s, char* buf, int len) {
    int total_rcvd = 0;
    while (total_rcvd < len) {
        int r = recv(s, buf + total_rcvd, len - total_rcvd, 0);
        if (r == 0) return 0; // connection closed
        if (r == SOCKET_ERROR) return SOCKET_ERROR;
        total_rcvd += r;
    }
    return total_rcvd;
}

// Convenience API: build message buffer and send
int send_message(SOCKET s, uint16_t msg_type, const void* payload, uint16_t payload_len) {
    MsgHeader hdr;
    // Convert header type and length to network order
    // Both fields are uint16_t, so we use htons (used for unsigned shorts)
    // See https://learn.microsoft.com/es-es/windows/win32/api/winsock2/nf-winsock2-htons
    hdr.type = (FalconCommand) htons(msg_type);
    hdr.len = htons(payload_len);

    // Create a contiguous buffer for header + payload
    // memcpy is used because we are copying raw bytes
    std::vector<char> buffer(sizeof(MsgHeader) + payload_len);
    std::memcpy(buffer.data(), &hdr, sizeof(hdr));
    if (payload_len) {
        std::memcpy(buffer.data() + sizeof(hdr), payload, payload_len);
    }

    return send_all(s, buffer.data(), (int)buffer.size());
}

/******************************************************************/
/* SENDER / RECEIVER THREADS                                      */
/******************************************************************/

static void sender_loop() {
    while (should_threads_run) {
        // Blocking wait for a position to send
        Position pos = sending_pos_q.pop();

        // If threads are stopping, exit (we still popped a wakeup item)
        if (!should_threads_run) break;

        // This is to send position 
        uint32_t pos_payload[3];
        pos_payload[0] = float_to_net(pos.x);
        pos_payload[1] = float_to_net(pos.y);
        pos_payload[2] = float_to_net(pos.z);

        int res = send_message(g_ClientSocket, MSG_POSITION, pos_payload, sizeof(pos_payload));
        if (res == SOCKET_ERROR) {
            printf("[sender_loop] send_message failed: %d\n", WSAGetLastError());
            // Stop on error; receiver will notice socket shutdown
            should_threads_run.store(false);
            break;
        }
    }
    // optional: flush / cleanup here
}

static void receiver_loop() {
    while (should_threads_run) {
        MsgHeader hdr;
        int r = recv_all(g_ClientSocket, reinterpret_cast<char*>(&hdr), sizeof(hdr));
        if (r <= 0) {
            // connection closed or error
            printf("[receiver_loop] hader recv returned %d (error: %d)\n", r, WSAGetLastError());
            should_threads_run.store(false);
            break;
        }

        uint16_t type = ntohs(hdr.type);
        uint16_t len = ntohs(hdr.len);

        std::vector<char> payload;
        if (len > 0) {
            payload.resize(len);
            r = recv_all(g_ClientSocket, payload.data(), len);
            if (r <= 0) {
                printf("[receiver_loop] payload recv returned %d (error: %d)\n", r, WSAGetLastError());
                should_threads_run.store(false);
                break;
            }
        }

        printf("[receiver_loop] Received message type %d, length %d\n", type, len);
        // Handle command types
        switch (type) {
            case CMD_IDLE: {
                // do nothing
                break;
                }

            case CMD_PRINT_STATUS: {
                Position pos;
                pos.x = net_to_float((uint32_t) payload.data());
                pos.y = net_to_float((uint32_t) payload.data() + 4);
                pos.z = net_to_float((uint32_t)payload.data() + 8);
                printf("[receiver_loop] CMD_PRINT_STATUS received from server\n");
                printf("Position is x: %f, y: %f, z: %f\n", pos.x, pos.y, pos.z);
                break;
            }
            default: {
                printf("[receiver_loop] Unknown message type %d\n", type);
                break;
            }
        }
    }
}

/******************************************************************/
/* MAIN FUNCTIONS DECLARATIONS                                    */
/******************************************************************/

/*
*  This functions takes care of stablishing the socket
*  connection with the server
*/
int OpenClientConnection(SOCKET* ClientSocket) {
    // Initialize Winsock
    iResult = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (iResult != 0) {
        printf("WSAStartup failed with error: %d\n", iResult);
        return SOCKET_WSA_STARTUP_FAILED;
    }

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    const char* server_name = "localhost";
    printf("No server name specified, using default: %s\n", server_name);
    // Resolve the server address and port
    iResult = getaddrinfo(server_name, DEFAULT_PORT, &hints, &result);
    if (iResult != 0) {
        printf("getaddrinfo failed with error: %d\n", iResult);
        WSACleanup();
        return SOCKET_GETADDRINFO_FAILED;
    }

    // Attempt to connect to an address until one succeeds
    for (ptr = result; ptr != NULL; ptr = ptr->ai_next) {
        // Create a SOCKET for connecting to server
        *ClientSocket = socket(ptr->ai_family, ptr->ai_socktype,
            ptr->ai_protocol);
        if (*ClientSocket == INVALID_SOCKET) {
            printf("socket failed with error: %ld\n", WSAGetLastError());
            WSACleanup();
            return SOCKET_IS_INVALID;
        }

        // Connect to server.
        iResult = connect(*ClientSocket, ptr->ai_addr, (int)ptr->ai_addrlen);
        if (iResult == SOCKET_ERROR) {
            closesocket(*ClientSocket);
            *ClientSocket = INVALID_SOCKET;
            continue;
        }
        break;
    }

    freeaddrinfo(result);

    if (*ClientSocket == INVALID_SOCKET) {
        printf("Unable to connect to server!\n");
        WSACleanup();
        return SOCKET_UNABLE_TO_CONNECT;
    }

    // store socket and start threads
    g_ClientSocket = *ClientSocket;
    should_threads_run.store(true);

    // start threads
    sender_thread = std::thread(sender_loop);
    receiver_thread = std::thread(receiver_loop);

    printf("Connected. Sender/Receiver threads started\n");
    return SOCKET_CONNECTION_SUCCESSFUL;
}

/*
*  This function sends the position of the Falcon
*/
int SendPosition(SOCKET* ClientSocket, const Position& pos) {
    // Push position to sending queue
    sending_pos_q.push(pos);
    return 1;
}

/*
MsgHeader ReceiveCommand(SOCKET* ClientSocket, FalconCommand* cmd_handler) {
    MsgHeader hdr;
    const int hdrsize = sizeof(MsgHeader); // We need another name to not confuse it with hdr.len. hdrlen != hdr.len
    //char net_buf[hdrsize + 12];
    std::vector<char> net_buf(hdrsize + 12);

    int r = recv_all(*ClientSocket, net_buf.data(), hdrsize);
    if (r > 0) {
        std::memcpy(&hdr, net_buf.data(), hdrsize);
        hdr.type = ntohs(hdr.type);
        hdr.len = ntohs(hdr.len);
        printf("[ReceiveCommand] I received this bytes, header and length: %d, %d and %d.\n", r, hdr.type, hdr.len);

        if (hdr.len > 0) {
            Position pos_data = { 10.0, 12.0, 14.0 };
            std::memcpy(&pos_data, net_buf.data() + hdrsize, hdr.len);
            pos_data.x = net_to_float(pos_data.x);
            pos_data.y = net_to_float(pos_data.y);
            pos_data.z = net_to_float(pos_data.z);

            printf("[ReceiveCommand] Position is x: %f, y: %f, and z: %f\n", pos_data.x, pos_data.y, pos_data.z);
        }
    }
    else {
        printf("[recv_command] Nothing has been received.\n");
    }
    return hdr;
}*/
    
// For removal
int SendInfo(SOCKET* ClientSocket, char* sendbuf, int sendlen) {
        
    if (!sendbuf) {
        printf("Invalid send buffer.\n");
        return 1;
    }

    if (sendlen == 0) {
        // nothing to send 
        printf("No data to send. \n");
        return 0;
    }

    //iResult = send_sentence(*ClientSocket, sendbuf, sendlen);
    iResult = send_all(*ClientSocket, sendbuf, sendlen);
    if (iResult == SOCKET_ERROR) {
        printf("Send failed with error: %d\n", WSAGetLastError());
        closesocket(*ClientSocket);
        WSACleanup();
        return 1;
    }
    printf("Sent %d bytes: \"%s\"\n", iResult, sendbuf);

    iResult = recv(*ClientSocket, recvbuf, recvbuflen, 0);
    if (iResult > 0) {
        printf("Bytes received: %d -- \"", iResult);
        fwrite(recvbuf, 1, iResult, stdout);
        printf("\"\n");
    }
    else if (iResult == 0) {
        printf("Connection closed by server.\n");
    }
    else {
        printf("recv failed with error: %d\n", WSAGetLastError());
        closesocket(*ClientSocket);
        WSACleanup();
        return 1;
    }

    return 0;
}

/*
*  This function takes care of closing the socket
*/
int CloseClientConnection(SOCKET* ClientSocket) {
    // request threads to stop
    should_threads_run.store(false);

    // Shutdown the connection since no more data will be sent
    iResult = shutdown(*ClientSocket, SD_SEND);
    if (iResult == SOCKET_ERROR) {
        printf("shutdown failed with error: %d\n", WSAGetLastError());
        closesocket(*ClientSocket);
        WSACleanup();
        return 1;
    }

    // wake sender by pushing a dummy position (unblocks pop)
    sending_pos_q.push(Position{ 0.0f, 0.0f, 0.0f });

    // join threads
    if (sender_thread.joinable()) sender_thread.join();
    if (receiver_thread.joinable()) receiver_thread.join();

    // Cleanup
    closesocket(*ClientSocket);
    WSACleanup();

    printf("Client finished. Press ENTER to exit...\n");
    getchar();
    return 0;
}