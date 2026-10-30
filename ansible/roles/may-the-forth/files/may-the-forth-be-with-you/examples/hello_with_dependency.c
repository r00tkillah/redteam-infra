#include <stdio.h>
#include <stdlib.h>

extern const char *dependency_message(void);
extern int dependency_tls_value(void);

__attribute__((constructor))
static void main_constructor(void) {
    register unsigned long nr __asm__("rax") = 1;
    register unsigned long fd __asm__("rdi") = 1;
    register const char *message __asm__("rsi") = "main constructor ran\n";
    register unsigned long count __asm__("rdx") = 21;
    __asm__ volatile("syscall" : "+a"(nr) : "D"(fd), "S"(message), "d"(count) : "rcx", "r11", "memory");
}

int main(int argc, char **argv) {
    if (argc < 1 || argc > 2 || !argv || !argv[0] || argv[argc]) return 23;
    puts(dependency_message());
    if (dependency_tls_value() != 48) return 24;
    puts("dependency TLS ready");
    if (argc == 2) puts(argv[1]);
    const char *environment_marker = getenv("FORTH_MARKER");
    if (environment_marker) puts(environment_marker);
    return 0;
}
