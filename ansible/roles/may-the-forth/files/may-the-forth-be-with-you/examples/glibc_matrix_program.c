#include <stdio.h>
#include <stdlib.h>

extern const char *matrix_dependency_message_v1(void);
__asm__(".symver matrix_dependency_message_v1,matrix_dependency_message@MATRIX_1.0");

__thread int matrix_program_tls = 11;
__thread int matrix_program_tbss;

__attribute__((constructor))
static void matrix_program_init(void) {
    matrix_program_tls += 2;
    matrix_program_tbss++;
}

int main(int argc, char **argv) {
    const char *environment = getenv("FORTH_MATRIX_ENV");
    if (argc != 2 || !argv || !argv[1] || !environment) return 31;
    puts(argv[1]);
    puts(environment);
    puts(matrix_dependency_message_v1());
    puts("glibc-matrix-ok");
    return 0;
}
