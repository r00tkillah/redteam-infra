#include <stdio.h>
#include <stdint.h>

static void report(const char *message, uintptr_t length) {
    register uintptr_t nr __asm__("rax") = 1;
    register uintptr_t fd __asm__("rdi") = 1;
    register const char *buffer __asm__("rsi") = message;
    register uintptr_t count __asm__("rdx") = length;
    __asm__ volatile("syscall" : "+a"(nr) : "D"(fd), "S"(buffer), "d"(count) : "rcx", "r11", "memory");
}

static _Thread_local int dependency_tls = 40;
static _Thread_local int dependency_tbss;

__attribute__((constructor))
static void dependency_constructor(void) {
    if (dependency_tls != 40 || dependency_tbss != 0) {
        report("dependency TLS template failed\n", 31);
        return;
    }
    dependency_tls++;
    dependency_tbss = 7;
    report("dependency constructor ran\n", 27);
}

int dependency_tls_value(void) {
    return dependency_tls + dependency_tbss;
}

const char *dependency_message(void) {
    return "hello from imported dependency";
}
