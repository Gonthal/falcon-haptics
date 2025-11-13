//#include "pch.h"
#include "stdafx.h"
#include "SecondFalcon.h"

SCRIPT_LIBRARY_EXPORT_ENTRY("secondfalcondll") {
	SQAutoRegisterGlobals(v);

	return SQ_OK;
}