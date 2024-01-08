#include <stdio.h>
#include "test.h"

extern _test_info_t *__start_tests;
extern _test_info_t *__stop_tests;

int main(void)
{
	// Iterate through all _test_info structures found in the tests
	// section of the binary, call function and print return status.

	_test_info_t **it = &__start_tests;
	for (; it < &__stop_tests; it++) {
		printf("[CHK] %s:%s...%s\n", (*it)->s, (*it)->t,
		       (*it)->fn() ? "NO" : "YES");
	}

	return 0;
}
