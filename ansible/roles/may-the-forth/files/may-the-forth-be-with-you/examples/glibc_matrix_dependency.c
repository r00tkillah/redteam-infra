__thread int matrix_dependency_tls = 16;
__thread int matrix_dependency_tbss;

__attribute__((constructor))
static void matrix_dependency_init(void) {
    matrix_dependency_tls++;
    matrix_dependency_tbss++;
}

const char *matrix_dependency_message(void) {
    return matrix_dependency_tls == 17 && matrix_dependency_tbss == 1
           ? "matrix-dependency-ok" : "matrix-dependency-bad";
}
