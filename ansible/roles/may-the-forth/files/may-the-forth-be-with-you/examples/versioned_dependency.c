#include <stdio.h>

extern int wrong_anchor(void);
extern const char *dependency_message_v1(void);
__asm__(".symver dependency_message_v1,dependency_message@HELLO_1.0");

int main(void) {
    if (wrong_anchor() != 0) return 31;
    puts(dependency_message_v1());
    return 0;
}
