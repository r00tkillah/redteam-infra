#define _GNU_SOURCE
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

int main(void) {
    int fd = open("examples/payload_fixture.txt", O_RDONLY);
    if (fd >= 0) {
        char buf[128];
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n < 0) {
            perror("read");
            close(fd);
            return 1;
        }
        close(fd);
    }

    char *mem = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    memcpy(mem, "benign-control\n", 15);
    if (write(STDOUT_FILENO, mem, 15) != 15) {
        perror("write");
        munmap(mem, 4096);
        return 1;
    }
    munmap(mem, 4096);
    return 0;
}
