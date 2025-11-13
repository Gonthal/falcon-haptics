// SecondFalcon.h - Contains... TO DO

#pragma once

#ifndef NVNT_SECOND_FALCON_H
#define NVNT_SECOND_FALCON_H

#include "squirrel.h"

// debug log functions
SQ_GLOBAL_METHOD(debugLog_open, 0);
SQ_GLOBAL_METHOD(debugLog_close, 0);
SQ_GLOBAL_METHOD(debugLog_print, 1, const SQChar *);
SQ_GLOBAL_METHOD(createSocketConnection, 0);
SQ_GLOBAL_METHOD(sendSocketInfo, 2, const SQChar *, SQInteger);
SQ_GLOBAL_METHOD(sendPosition, 3, SQFloat, SQFloat, SQFloat);
SQ_GLOBAL_METHOD(getCommand, 0);
SQ_GLOBAL_METHOD(closeSocketConnection, 0);
SQ_GLOBAL_METHOD(debugLog_printbuf, 0);

#endif

/*#ifdef SECONDFALCON_EXPORTS
#define SECONDFALCON_API __declspec(dllexport)
#else
#define SECONDFALCON_API __declspec(dllimport)
#endif

extern "C" SECONDFALCON_API void falcon_init();*/