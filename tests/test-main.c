// Placeholder for real unit-testing framework

#include <stdio.h>

#define MSG_SUCCESS  "[CHK] Unit-test succeeded.\n"
#define MSG_ERROR    "[CHK] Unit-test failed.\n"

#ifdef LINUX
#include "system/linux/test-linux.h"
#endif

#ifdef WIN32
#include "system/win32/test-win32.h"
#endif

int main(void)
{
	#ifdef LINUX
	if (test_some_linux_function() == 0) {
		printf(MSG_SUCCESS);
		return 0;
	} else {
		printf(MSG_ERROR);
		return 1;
	}
	#endif

	#ifdef WIN32
	if (test_some_win32_function() == 0) {
		printf(MSG_SUCCESS);
		return 0;
	} else {
		printf(MSG_ERROR);
		return 1;
	}
	#endif
}
