#pragma once

#ifndef APPTYPES_H
#define APPTYPES_H

#include "stdafx.h"
#include <cstdint> // uint16_t, uint32_t, etc.
#include <cstring> // std::memcpy, used on SocketClient.cpp
#include <vector>

// Is this deprecated?
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
typedef enum _FalconCommandTypes : uint16_t {
	CMD_NONE      = 0,
	CMD_ROCK      = 1,
	CMD_SANDPAPER = 2,
	CMD_OIL       = 3,
	CMD_SPRING    = 4,
	CMD_WATER     = 5,
	CMD_ERROR     = 100
} FalconCommandTypes;

#pragma pack(push, 1) // Ensure no padding is added by the compiler
typedef struct _MsgHeader {
	uint16_t type;	 // payload length in bytes, 2 bytes, network order
	uint32_t len;    // 4 bytes (changed from short i.e. 2 bytes), network order
} MsgHeader;
#pragma pack(pop)

// Struct to hold the full command data
typedef struct _FalconMessage {
	uint16_t type;
	std::vector<float> payload;
} FalconMessage;

#pragma pack(push, 1)
typedef struct _Position {
	float x, y, z;
} Position;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct _Torque {
	float x, y, z;
} Torque;
#pragma pack(pop)

typedef struct _FalconHandler {
	Position pos;
	Torque torque;
} FalconHandler;

#endif