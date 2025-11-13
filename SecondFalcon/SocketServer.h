#pragma once

#ifndef SOCKETSERVER_H
#define SOCKETSERVER_H

#undef UNICODE

#define WIN32_LEAN_AND_MEAN

#include "stdafx.h"
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>
#include <stdio.h>

#define DEFAULT_BUFLEN 512
namespace Server {
	int OpenConnection(SOCKET* ClientSocket);
	int ReceiveInfo(SOCKET* ClientSocket, char recvbuf[DEFAULT_BUFLEN], int recvbuflen);
	int CloseConnection(SOCKET* ClientSocket);
}


#endif