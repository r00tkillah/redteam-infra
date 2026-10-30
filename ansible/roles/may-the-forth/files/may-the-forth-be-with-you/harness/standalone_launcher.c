#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define BOOT_MAGIC UINT64_C(0x31544f4f42485446)

struct bootstrap {
    uint64_t magic;
    uint64_t version;
    const char *path;
    uint64_t path_len;
    uint64_t flags;
    uint64_t argc;
    char *const *argv;
    char *const *envp;
    uint64_t bundle_length;
};

extern char **environ;

static void die(const char *what) {
    perror(what);
    exit(2);
}

int main(int argc, char **argv) {
    bool embedded = argc >= 2 && (strcmp(argv[1], "--embedded") == 0 ||
                                  strcmp(argv[1], "--embedded-raw") == 0);
    bool embedded_raw = argc >= 2 && strcmp(argv[1], "--embedded-raw") == 0;
    if ((!embedded && argc < 3) || (embedded && argc < 3)) {
        fprintf(stderr, "usage: %s blob target-elf [target-args...]\n"
                        "       %s --embedded bundle [target-args...]\n"
                        "       %s --embedded-raw bundle\n", argv[0], argv[0], argv[0]);
        return 2;
    }
    const char *blob_path = embedded ? argv[2] : argv[1];
    int fd = open(blob_path, O_RDONLY);
    if (fd < 0) die("open blob");
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) die("stat blob");
    void *blob = mmap(NULL, (size_t)st.st_size, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (blob == MAP_FAILED) die("mmap blob");
    size_t done = 0;
    while (done < (size_t)st.st_size) {
        ssize_t n = read(fd, (uint8_t *)blob + done, (size_t)st.st_size - done);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) die("read blob");
        done += (size_t)n;
    }
    close(fd);
    if (mprotect(blob, (size_t)st.st_size, PROT_READ | PROT_EXEC) != 0)
        die("mprotect blob");
    char *default_argv[] = {"embedded-static", NULL};
    struct bootstrap boot = {
        .magic = BOOT_MAGIC,
        .version = embedded ? 2 : 1,
        .path = embedded ? default_argv[0] : argv[2],
        .path_len = strlen(embedded ? default_argv[0] : argv[2]),
        .argc = (uint64_t)(argc - 2),
        .argv = &argv[2],
        .envp = environ,
        .bundle_length = embedded ? (uint64_t)st.st_size : 0,
    };
    ((void (*)(const struct bootstrap *))blob)(embedded_raw ? NULL : &boot);
    return 111;
}
