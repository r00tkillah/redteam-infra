#include <stdint.h>

typedef void *(*fixture_fn)(void);

static void *fixture_implementation(void) {
    return (void *)(uintptr_t)0x1122334455667788ULL;
}

static fixture_fn resolve_fixture(void) {
    return fixture_implementation;
}

void *ifunc_fixture(void) __attribute__((ifunc("resolve_fixture")));
