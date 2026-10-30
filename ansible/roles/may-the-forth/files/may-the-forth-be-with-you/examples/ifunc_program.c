#include <stdint.h>
#include <stdio.h>

extern void *ifunc_fixture(void);

int main(void) {
    if ((uintptr_t)ifunc_fixture() != UINT64_C(0x1122334455667788)) return 32;
    puts("IFUNC fixture ready");
    return 0;
}
