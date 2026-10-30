#include <stdio.h>

int main(int argc, char **argv) {
    puts("hello from dynamic demo elf");
    if (argc != 1 || !argv || !argv[0] || argv[1]) {
        puts("invalid in-memory entry stack");
        return 23;
    }
    puts(argv[0]);
    return 0;
}
