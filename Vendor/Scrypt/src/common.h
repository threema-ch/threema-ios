#ifndef SRC_COMMON_H_
#define SRC_COMMON_H_

#include <stdio.h>
#include <stdlib.h>

#ifndef MIN
# define MIN(a, b) ((a) > (b) ? (b) : (a))
#endif  /* MIN */

#ifndef ARRAY_SIZE
# define ARRAY_SIZE(a) (sizeof((a)) / sizeof((a)[0]))
#endif

#define ASSERT__COMMON(expr, desc, ...)                                       \
    do {                                                                      \
      if (!(expr)) {                                                          \
        fprintf(stderr, desc "\n", __VA_ARGS__);                              \
        abort();                                                              \
      }                                                                       \
    } while (0)

#define ASSERT_VA(expr, desc, ...)                                            \
    ASSERT__COMMON(expr,                                                      \
                   "Assertion failed %s:%d\n" desc,                           \
                   __FILE__,                                                  \
                   __LINE__,                                                  \
                   __VA_ARGS__)

#define ASSERT(expr, desc)                                                    \
    ASSERT__COMMON(expr,                                                      \
                   "Assertion failed %s:%d\n" desc,                           \
                   __FILE__,                                                  \
                   __LINE__)

#define UNEXPECTED ASSERT(0, "Unexpected")

#endif  /* SRC_COMMON_H_ */
