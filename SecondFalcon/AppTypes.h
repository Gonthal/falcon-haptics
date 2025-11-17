#pragma once

#ifndef APPTYPES_H
#define APPTYPES_H

#include "stdafx.h"
#include <cstdint> // uint16_t, uint32_t, etc.
#include <cstring> // std::memcpy, used on SocketClient.cpp

typedef enum {
	SOCKET_WSA_STARTUP_FAILED = 1,
	SOCKET_GETADDRINFO_FAILED,
	SOCKET_IS_INVALID,
	SOCKET_UNABLE_TO_CONNECT,
	SOCKET_BIND_FAILED,
	SOCKET_LISTEN_FAILED,
	SOCKET_ACCEPT_FAILED,
	SOCKET_CONNECTION_SUCCESSFUL
} SocketMessageTypes;

// Message types
enum : uint16_t {
	MSG_POSITION = 1,
	MSG_COMMAND = 2
};

// 
typedef enum _FalconCommand : uint16_t {
	CMD_IDLE = 0,
	CMD_PRINT_STATUS = 1,
	CMD_ERROR = 100
} FalconCommand;

#pragma pack(push, 1) // Ensure no padding is added by the compiler
typedef struct _MsgHeader {
	uint16_t      type;	  // network order
	uint16_t      len;    // payload length in bytes, network order
} MsgHeader;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct {
	float x, y, z;
} Position;
#pragma pack(pop)

/*
typedef struct {
	typedef struct position {
		float x;
		float y;
		float z;
	};
	position pos;

	typedef struct torque {
		float x;
		float y;
		float z;
	};
	torque tor;
} FalconHandler;*/

#endif