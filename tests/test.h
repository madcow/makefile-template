#ifndef MAD_TEST_H
#define MAD_TEST_H

// Unit-Testing Macros
// Written by Leon Krieg <info@madcow.dev>

// Minimal unit-testing implementation with automatic function registration.
// Requires GCC for the section attribute. More assertion macros will be added
// in the future.

#define EXPECT(expr)  return !(expr)
#define TEST(s, t)    int test_##s##_##t##_imp(void); \
                      _test_info_t test_##s##_##t##_dat = {#s, #t, test_##s##_##t##_imp}; \
                      _test_info_t * __attribute__((section("tests"))) test_##s##_##t##_ptr = \
                      &test_##s##_##t##_dat; int test_##s##_##t##_imp(void)

typedef int (*_test_func_t)(void);
typedef struct _test_info_s {
	const char    *s, *t;
	_test_func_t  fn;
} _test_info_t;

#endif // MAD_TEST_H
