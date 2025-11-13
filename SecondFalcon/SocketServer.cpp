#include "stdafx.h"
#include "SocketServer.h"

// Need to link with Ws2_32.lib
#pragma comment (lib, "Ws2_32.lib")
// #pragma comment (lib, "Mswsock.lib")

#define DEFAULT_BUFLEN 512
#define DEFAULT_PORT "27015"

namespace Server {
    WSADATA wsaDataServer;
    int iResultServer;

    SOCKET ListenSocket = INVALID_SOCKET;
    //SOCKET ClientSocket = INVALID_SOCKET;
    struct addrinfo* result_server = NULL;
    struct addrinfo hints_server;

    int iSendResult;

    int OpenConnection(SOCKET* ClientSocket) {
        iResultServer = WSAStartup(MAKEWORD(2, 2), &wsaDataServer);
        if (iResultServer != 0) {
            printf("WSAStartup failed with error: %d\n", iResultServer);
            return 1;
        }

        ZeroMemory(&hints_server, sizeof(hints_server));
        hints_server.ai_family = AF_INET;
        hints_server.ai_socktype = SOCK_STREAM;
        hints_server.ai_protocol = IPPROTO_TCP;
        hints_server.ai_flags = AI_PASSIVE;

        // Resolve the server address and port
        iResultServer = getaddrinfo(NULL, DEFAULT_PORT, &hints_server, &result_server);
        if (iResultServer != 0) {
            printf("getaddrinfo failed with error: %d\n", iResultServer);
            WSACleanup();
            return 2;
        }

        // Create a SOCKET for the server to listen for client connections.
        ListenSocket = socket(result_server->ai_family, result_server->ai_socktype, result_server->ai_protocol);
        if (ListenSocket == INVALID_SOCKET) {
            printf("socket failed with error: %ld\n", WSAGetLastError());
            freeaddrinfo(result_server);
            WSACleanup();
            return 3;
        }

        // Setup the TCP listening socket
        iResultServer = bind(ListenSocket, result_server->ai_addr, (int)result_server->ai_addrlen);
        if (iResultServer == SOCKET_ERROR) {
            printf("bind failed with error: %d\n", WSAGetLastError());
            freeaddrinfo(result_server);
            closesocket(ListenSocket);
            WSACleanup();
            return 4;
        }

        freeaddrinfo(result_server);

        iResultServer = listen(ListenSocket, SOMAXCONN);
        if (iResultServer == SOCKET_ERROR) {
            printf("listen failed with error: %d\n", WSAGetLastError());
            closesocket(ListenSocket);
            WSACleanup();
            return 5;
        }

        // Accept a client socket
        *ClientSocket = accept(ListenSocket, NULL, NULL);
        if (*ClientSocket == INVALID_SOCKET) {
            printf("accept failed with error: %d\n", WSAGetLastError());
            closesocket(ListenSocket);
            WSACleanup();
            return 6;
        }

        // No longer need server socket
        closesocket(ListenSocket);
        return 7;
    }

    int ReceiveInfo(SOCKET* ClientSocket,
        char recvbuf_server[DEFAULT_BUFLEN],
        int recvbuflen) {
        // Receive until the peer shuts down the connection
        do {
            iResultServer = recv(*ClientSocket, recvbuf_server, recvbuflen, 0);
            if (iResultServer > 0) {
                printf("Bytes received: %d\n", iResultServer);

                // Echo the buffer back to the sender
                iSendResult = send(*ClientSocket, recvbuf_server, iResultServer, 0);
                if (iSendResult == SOCKET_ERROR) {
                    printf("send failed with error: %d\n", WSAGetLastError());
                    closesocket(*ClientSocket);
                    WSACleanup();
                    return 1;
                }
                printf("Bytes sent: %d\n", iSendResult);
            }
            else if (iResultServer == 0)
                printf("Connection closing...\n");
            else {
                printf("recv failed with error: %d\n", WSAGetLastError());
                closesocket(*ClientSocket);
                WSACleanup();
                return 1;
            }
        } while (iResultServer > 0);
    }

    int CloseConnection(SOCKET* ClientSocket) {
        // shutdown the connection since we're done
        iResultServer = shutdown(*ClientSocket, SD_SEND);
        if (iResultServer == SOCKET_ERROR) {
            printf("shutdown failed with error: %d\n", WSAGetLastError());
            closesocket(*ClientSocket);
            WSACleanup();
            return 1;
        }
        // cleanup
        closesocket(*ClientSocket);
        WSACleanup();
    }
}

