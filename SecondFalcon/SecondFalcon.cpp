//#include "pch.h"
#include "stdafx.h"
#include "windows.h"
#include <stdio.h>
#include "SecondFalcon.h"
#include "SocketClient.h"
#include "AppTypes.h"

char falcon_recvbuf[DEFAULT_BUFLEN];
SOCKET FalconClientSocket = INVALID_SOCKET;
static const char* init_message = "Hello, Falcon!";
FILE* pDebugLogFile = NULL;

// Is a Falcon handler really necessary?
FalconHandler falcon_instance;

Position current_position = { 0.0, 0.0, 0.0 };

SQRESULT SQ_debugLog_open(HSQUIRRELVM v) {
	pDebugLogFile = fopen("tesis_log.txt", "w");
	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(debugLog_open);

SQRESULT SQ_debugLog_close(HSQUIRRELVM v) {
	if (pDebugLogFile != NULL) {
		fclose(pDebugLogFile);
	}
	
	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(debugLog_close);

SQRESULT SQ_debugLog_print(HSQUIRRELVM v, const SQChar *pTxt) {
	if (pDebugLogFile != NULL) {
		wchar_t* inTxt = (wchar_t*)pTxt;
		fwprintf(pDebugLogFile, inTxt);
	}

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(debugLog_print);

SQRESULT SQ_createSocketConnection(HSQUIRRELVM v) {
	int func_result = OpenClientConnection(&FalconClientSocket);

	while (func_result != SOCKET_CONNECTION_SUCCESSFUL) {
		;
	}

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(createSocketConnection);

SQRESULT SQ_sendPosition(HSQUIRRELVM v, SQFloat posx, SQFloat posy, SQFloat posz) {
	current_position.x = (float)posx;
	current_position.y = (float)posy;
	current_position.z = (float)posz;

	SendPosition(&FalconClientSocket, current_position);

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(sendPosition);

SQRESULT SQ_getCommand(HSQUIRRELVM v) {
	// Pop the full message
	FalconMessage msg = GetCommand(&FalconClientSocket);

	if (msg.type == CMD_ERROR) {
		// No message received, return null
		sq_pushnull(v);
		return 1;
	}

	// Create a new Squirrel table on the stack: {}
	sq_newtable(v);

	// Add the 'type' slot
	sq_pushstring(v, _SC("type"), -1);		// Push key "type"
	sq_pushinteger(v, (int)msg.type);		// Push value (e.g., 2)
	sq_newslot(v, -3, SQFalse);				// Create slot: { type: 2 }

	// Add the 'data' slot (as an array)
	sq_pushstring(v, _SC("data"), -1);		// Push key "data"
	sq_newarray(v, 0);

	// Fill the array with floats from the payload
	for (size_t i = 0; i < msg.payload.size(); i++) {
		sq_pushfloat(v, msg.payload[i]);	// Push float value
		sq_arrayappend(v, -2);				// Append to array
	}

	sq_newslot(v, -3, SQFalse);				// Create slot: { type: 2, data: [...] }

	// Return 1, indicating we are returning ONE object (the table)
	return 1;
}
SQ_BIND_GLOBAL_METHOD(getCommand);

SQRESULT SQ_closeSocketConnection(HSQUIRRELVM v) {
	CloseClientConnection(&FalconClientSocket);

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(closeSocketConnection);

SQRESULT SQ_debugLog_printbuf(HSQUIRRELVM v) {
	if (pDebugLogFile != NULL) {
		//wchar_t* inText = (wchar_t*)recvbuf;
		fprintf(pDebugLogFile, "%s", falcon_recvbuf);
	}

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(debugLog_printbuf);