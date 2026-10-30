#include <stdio.h>

static _Thread_local int initialized_tls = 40;
static _Thread_local int zero_tls;

int main(void) {
    if (initialized_tls != 40 || zero_tls != 0) return 41;
    initialized_tls++;
    zero_tls = 7;
    if (initialized_tls != 41 || zero_tls != 7) return 42;
    puts("static TLS template ready");
    return 0;
}
