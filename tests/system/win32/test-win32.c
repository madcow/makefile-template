#include "system/win32/win32.h"
#include <stdlib.h>

int test_some_win32_function(void)
{
	// Runs for win32 targets only
	return (add(100, 200) == 300) ? 0 : EXIT_FAILURE;
}
