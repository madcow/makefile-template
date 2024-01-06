#include "system/linux/linux.h"
#include <stdlib.h>

int test_some_linux_function(void)
{
	// Runs for linux targets only
	return (add(100, 200) == 300) ? 0 : EXIT_FAILURE;
}
