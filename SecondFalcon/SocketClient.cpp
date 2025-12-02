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
static ThreadSafeQueue<Position> incoming_pos_q;
static ThreadSafeQueue<MsgHeader> incoming_cmd_hdr_q;
static ThreadSafeQueue<FalconMessage> incoming_msg_q;

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
    hdr.type = htons(msg_type);
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

        // If threads are stopping, exit 
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
            should_threads_run = false;
            break;
        }
    }
    // optional: flush / cleanup here
}

static void receiver_loop() {
    while (should_threads_run) {
        MsgHeader hdr;
        const int hdrsize = sizeof(MsgHeader);
        std::vector<char> hdr_buf(hdrsize);

        int r = recv_all(g_ClientSocket, hdr_buf.data(), hdrsize);

        // Check for errors or closed connection
        if (r <= 0) {
            // connection closed or error
            printf("[receiver_loop] header recv returned %d (error: %d)\n", r, WSAGetLastError());
            should_threads_run = false; // Tell the sender thread to stop
            break; // Exit the loop
        }

        std::memcpy(&hdr, hdr_buf.data(), hdrsize);
        hdr.type = net_to_short(hdr.type);
        hdr.len = net_to_short(hdr.len);

        printf("[receiver_loop] The header is %d and len is %d.\n", hdr.type, hdr.len);
        
        FalconMessage msg;
        msg.type = hdr.type;

        if (hdr.len > 0) {
            std::vector<char> payload_buf(hdr.len);
            
            // Check for disconnection on payload as well
            int r_payload = recv_all(g_ClientSocket, payload_buf.data(), hdr.len);
            if (r_payload <= 0) {
                printf("[receiver_loop] payload recv returned %d (error: %d)\n", r_payload, WSAGetLastError());
                should_threads_run = false;
                break;
            }

            // Convert bytes to floats (this will need REVISION later)
            int num_floats = hdr.len / sizeof(float);
            for (int i = 0; i < num_floats; i++) {
                uint32_t temp;
                std:memcpy(
                    &temp,
                    payload_buf.data() + (i * sizeof(float)),
                    sizeof(float)
                );
                msg.payload.push_back(net_to_float(temp));
            }

            incoming_msg_q.push(msg);
            //incoming_cmd_hdr_q.push(hdr);

            //Position pos_data;
            //std::memcpy(&pos_data, payload_buf.data(), hdr.len);
            //pos_data.x = net_to_float((uint32_t)payload_buf.data());
            //pos_data.y = net_to_float((uint32_t)payload_buf.data() + 4);
            //pos_data.z = net_to_float((uint32_t)payload_buf.data() + 8);
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

FalconMessage GetCommand(SOCKET* ClientSocket) {
    FalconMessage msg = { CMD_ERROR, {} }; // Empty payload
    if (incoming_msg_q.empty()) {
        return msg;
    }
    return incoming_msg_q.pop();
}

void StopNetworkingThreads() {
    if (!should_threads_run) return;

    printf("[StopNetworkingThreads] Stopping networking threads...\n");
    should_threads_run = false;

    // Unblock threads waiting on pop()
    sending_pos_q.unblock_all();
    incoming_pos_q.unblock_all();
    incoming_cmd_hdr_q.unblock_all();

    // Shutdown and close the socket
    // This will interrupt the blocking 'recv_all' in the receiver thread
    if (g_ClientSocket != INVALID_SOCKET) {
        shutdown(g_ClientSocket, SD_BOTH);
        closesocket(g_ClientSocket);
        g_ClientSocket = INVALID_SOCKET;
    }

    if (sender_thread.joinable()) {
        printf("[StopNetworkingThreads] Joining sender thread... ");
        sender_thread.join();
        printf("Sender thread joined.\n");
    }

    if (receiver_thread.joinable()) {
        printf("[StopNetworkingThreads] Joining receiver thread... ");
        receiver_thread.join();
        printf("Receiver thread joined.\n");
    }
}

/*
*  This function takes care of closing the socket
*/
int CloseClientConnection(SOCKET* ClientSocket) {
    // request threads to stop
    StopNetworkingThreads();

    // Socket is already closed, just clean up WSA
    WSACleanup();
    *ClientSocket = INVALID_SOCKET;

    printf("Client connection closed.\n");
    return 0;
}