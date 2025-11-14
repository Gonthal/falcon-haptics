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

// For removal
SQRESULT SQ_sendSocketInfo(HSQUIRRELVM v, const SQChar *sendbuf, SQInteger sendlen) {

	printf("Sending info to Falcon...\n");

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(sendSocketInfo);

SQRESULT SQ_sendPosition(HSQUIRRELVM v, SQFloat posx, SQFloat posy, SQFloat posz) {
	current_position.x = (float)posx;
	current_position.y = (float)posy;
	current_position.z = (float)posz;

	SendPosition(&FalconClientSocket, current_position);

	return SQ_OK;
}
SQ_BIND_GLOBAL_METHOD(sendPosition);

SQRESULT SQ_getCommand(HSQUIRRELVM v) {
	MsgHeader incoming_cmd = GetCommand(&FalconClientSocket);

	sq_pushinteger(v, incoming_cmd.type);
	sq_pushinteger(v, incoming_cmd.len);
	return SQ_OK;
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