#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <asm/prctl.h>
#include <sys/syscall.h>
#include <ucontext.h>
#include <sys/wait.h>
#include <unistd.h>
#include <elf.h>
#include "workspace.h"

typedef int64_t (*forth_blob_fn)(const uint8_t *, uint64_t, uint8_t *, uint64_t, uint8_t *, uint64_t);

static bool g_elf_exec_protections = false;
static bool g_debug_hold = false;
static uint64_t g_debug_hold_seconds = 0;
static uint64_t g_ld_dry_runs = 0;
static int g_loader_depth = 0;
static struct workspace_header *g_active_workspace = NULL;
static void *g_active_entry = NULL;
static uintptr_t g_host_fs_base = 0;

struct forth_service_state {
    void *workspace;
    size_t workspace_len;
    void *maps[FORTH_OBJECT_RECORD_MAX];
    size_t map_lens[FORTH_OBJECT_RECORD_MAX];
    size_t map_count;
    void *sources[FORTH_OBJECT_RECORD_MAX];
    size_t source_lens[FORTH_OBJECT_RECORD_MAX];
    dev_t source_devs[FORTH_OBJECT_RECORD_MAX];
    ino_t source_inos[FORTH_OBJECT_RECORD_MAX];
    void *tls_map;
    size_t tls_map_len;
    const char *library_roots[8];
    size_t library_root_count;
};

static bool service_range_ok(const struct forth_service_state *state, uintptr_t address,
                             uint64_t length) {
    if (length > UINTPTR_MAX - address) return false;
    uintptr_t end = address + (uintptr_t)length;
    uintptr_t ws = (uintptr_t)state->workspace;
    if (address >= ws && end <= ws + state->workspace_len) return true;
    for (size_t i = 0; i < state->map_count; i++) {
        uintptr_t base = (uintptr_t)state->maps[i];
        if (address >= base && end <= base + state->map_lens[i]) return true;
    }
    if (state->tls_map && address >= (uintptr_t)state->tls_map &&
        end <= (uintptr_t)state->tls_map + state->tls_map_len) return true;
    return false;
}

static uint64_t service_map(void *opaque, uint64_t desired, uint64_t length,
                            uint64_t prot, uint64_t flags) {
    struct forth_service_state *state = opaque;
    if (!length || length > FORTH_OBJECT_MAP_MAX)
        return 0;
    if (prot & ~(uint64_t)(PROT_READ | PROT_WRITE) || flags & ~(uint64_t)7) return 0;
    uint64_t *cells = (uint64_t *)(void *)(state->workspace + DATA_BASE_OFF);
    uint64_t object = cells[FORTH_CURRENT_OBJECT];
    if (!(flags & 4) && cells[FORTH_LINK_PHASE] == 1 && object < FORTH_OBJECT_RECORD_MAX) {
        uint64_t rec = FORTH_OBJECT_RECORD_BASE + object * FORTH_OBJECT_RECORD_SIZE;
        if (cells[rec + FORTH_OBJECT_STATE] == 1 &&
            cells[rec + FORTH_OBJECT_MAP_SIZE] == length) {
            printf("forth_service={\"name\":\"map_reuse\",\"object\":%" PRIu64
                   ",\"length\":%" PRIu64 ",\"result\":%p}\n", object, length,
                   (void *)(uintptr_t)cells[rec + FORTH_OBJECT_MAP_BASE]);
            return cells[rec + FORTH_OBJECT_MAP_BASE];
        }
    }
    if ((flags & 4) && state->tls_map) return 0;
    if (!(flags & 4) && state->map_count >= FORTH_OBJECT_RECORD_MAX) return 0;
    int mmap_flags = MAP_PRIVATE | MAP_ANONYMOUS;
#ifdef MAP_FIXED_NOREPLACE
    if (flags & 2) mmap_flags |= MAP_FIXED_NOREPLACE;
#else
    if (flags & 2) return 0;
#endif
    void *mapping = mmap((void *)(uintptr_t)desired, length, (int)prot, mmap_flags, -1, 0);
    if (mapping == MAP_FAILED) return 0;
    if (flags & 4) {
        state->tls_map = mapping;
        state->tls_map_len = (size_t)length;
    } else {
        state->maps[state->map_count] = mapping;
        state->map_lens[state->map_count++] = (size_t)length;
    }
    printf("forth_service={\"name\":\"map\",\"requested\":%p,\"length\":%" PRIu64
           ",\"prot\":%" PRIu64 ",\"flags\":%" PRIu64 ",\"result\":%p}\n",
           (void *)(uintptr_t)desired, length, prot, flags, mapping);
    return (uint64_t)(uintptr_t)mapping;
}

static uint64_t service_unmap(void *opaque, uint64_t address, uint64_t length,
                              uint64_t unused2, uint64_t unused3) {
    struct forth_service_state *state = opaque;
    (void)unused2; (void)unused3;
    for (size_t i = 0; i < state->map_count; i++) {
        if ((uintptr_t)state->maps[i] == address && state->map_lens[i] == length) {
            if (munmap(state->maps[i], state->map_lens[i]) != 0) return (uint64_t)-errno;
            state->maps[i] = NULL;
            state->map_lens[i] = 0;
            return 0;
        }
    }
    return (uint64_t)-EINVAL;
}

static uint64_t service_protect(void *opaque, uint64_t address, uint64_t length,
                                uint64_t prot, uint64_t unused3) {
    struct forth_service_state *state = opaque;
    (void)unused3;
    if (!service_range_ok(state, (uintptr_t)address, length) || prot & ~(uint64_t)7)
        return (uint64_t)-EINVAL;
    if (mprotect((void *)(uintptr_t)address, length, (int)prot) != 0) return (uint64_t)-errno;
    printf("forth_service={\"name\":\"protect\",\"address\":%p,\"length\":%" PRIu64
           ",\"prot\":%" PRIu64 ",\"exec\":%s}\n", (void *)(uintptr_t)address,
           length, prot, (prot & PROT_EXEC) ? "true" : "false");
    return 0;
}

static uint64_t service_read_file(void *opaque, uint64_t path_address, uint64_t path_length,
                                  uint64_t source_slot, uint64_t capacity) {
    struct forth_service_state *state = opaque;
    if (!path_length || path_length >= PATH_MAX || source_slot >= FORTH_OBJECT_RECORD_MAX ||
        !capacity || capacity > FORTH_SOURCE_SIZE_MAX || state->sources[source_slot] ||
        !service_range_ok(state, (uintptr_t)path_address, path_length)) return (uint64_t)-EINVAL;
    char path[PATH_MAX];
    memcpy(path, (const void *)(uintptr_t)path_address, (size_t)path_length);
    path[path_length] = 0;
    int fd = -1;
    char rooted[PATH_MAX];
    if (path[0] == '/') {
        for (size_t i = 0; i < state->library_root_count && fd < 0; i++) {
            if (snprintf(rooted, sizeof(rooted), "%s%s", state->library_roots[i], path) >= (int)sizeof(rooted))
                continue;
            fd = open(rooted, O_RDONLY);
        }
    }
    if (fd < 0) fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("forth_service={\"name\":\"read_file_error\",\"slot\":%" PRIu64
               ",\"path\":\"%s\",\"errno\":%d}\n", source_slot, path, errno);
        return (uint64_t)-errno;
    }
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 0 || (uint64_t)st.st_size > capacity) {
        int saved = errno ? errno : EFBIG;
        close(fd);
        return (uint64_t)-saved;
    }
    for (size_t i = 0; i < FORTH_OBJECT_RECORD_MAX; i++) {
        if (state->sources[i] && state->source_devs[i] == st.st_dev &&
            state->source_inos[i] == st.st_ino) {
            printf("forth_service={\"name\":\"read_file_dedup\",\"slot\":%" PRIu64
                   ",\"existing\":%zu}\n", source_slot, i);
            close(fd);
            return ((uint64_t)(i + 1) << 32) | UINT32_MAX;
        }
    }
    void *source = malloc((size_t)st.st_size + 1);
    if (!source) { close(fd); return (uint64_t)-ENOMEM; }
    size_t done = 0;
    while (done < (size_t)st.st_size) {
        ssize_t n = read(fd, (uint8_t *)source + done, (size_t)st.st_size - done);
        if (n <= 0) {
            int saved = n < 0 ? errno : EIO;
            free(source); close(fd); return (uint64_t)-saved;
        }
        done += (size_t)n;
    }
    ((uint8_t *)source)[done] = 0;
    state->sources[source_slot] = source;
    state->source_lens[source_slot] = done;
    state->source_devs[source_slot] = st.st_dev;
    state->source_inos[source_slot] = st.st_ino;
    printf("forth_service={\"name\":\"read_file\",\"slot\":%" PRIu64
           ",\"path\":\"%s\",\"bytes\":%zu}\n", source_slot, path, done);
    uint64_t *record = (uint64_t *)((uint8_t *)state->workspace + DATA_BASE_OFF) +
                       FORTH_OBJECT_RECORD_BASE + source_slot * FORTH_OBJECT_RECORD_SIZE;
    record[FORTH_OBJECT_SOURCE_KIND] = 2;
    record[FORTH_OBJECT_SOURCE_ADDR] = (uint64_t)(uintptr_t)source;
    record[FORTH_OBJECT_SOURCE_SIZE] = done;
    return ((uint64_t)(source_slot + 1) << 32) | (uint32_t)fd;
}

static uint64_t service_close(void *opaque, uint64_t handle, uint64_t unused1,
                              uint64_t unused2, uint64_t unused3) {
    (void)opaque; (void)unused1; (void)unused2; (void)unused3;
    int fd = (int)handle;
    return fd == -1 || close(fd) == 0 ? 0 : (uint64_t)-errno;
}

static uint64_t service_copy(void *opaque, uint64_t source, uint64_t destination,
                             uint64_t length, uint64_t unused3) {
    struct forth_service_state *state = opaque;
    (void)unused3;
    if (!length || !service_range_ok(state, source, length) ||
        !service_range_ok(state, destination, length)) return (uint64_t)-EINVAL;
    memcpy((void *)(uintptr_t)destination, (const void *)(uintptr_t)source, (size_t)length);
    printf("forth_service={\"name\":\"copy\",\"source\":%p,\"destination\":%p"
           ",\"bytes\":%" PRIu64 "}\n", (void *)(uintptr_t)source,
           (void *)(uintptr_t)destination, length);
    return 0;
}

struct blob {
    uint8_t *bytes;
    size_t len;
};

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

static void crash_handler(int sig, siginfo_t *info, void *uctx) {
#if defined(__x86_64__)
    if (g_host_fs_base) {
        register long nr __asm__("rax") = SYS_arch_prctl;
        register long op __asm__("rdi") = ARCH_SET_FS;
        register uintptr_t base __asm__("rsi") = g_host_fs_base;
        __asm__ volatile("syscall" : "+a"(nr) : "D"(op), "S"(base) : "rcx", "r11", "memory");
    }
    ucontext_t *uc = (ucontext_t *)uctx;
    uintptr_t rip = (uintptr_t)uc->uc_mcontext.gregs[REG_RIP];
    uintptr_t entry = (uintptr_t)g_active_entry;
    fprintf(stderr, "forth_crash={\"signal\":%d,\"fault\":\"%p\",\"rip\":\"%p\",\"rsp\":\"%p\",\"rax\":\"%p\",\"rbx\":\"%p\",\"rcx\":\"%p\",\"rdi\":\"%p\",\"rsi\":\"%p\",\"rdx\":\"%p\",\"r14\":\"%p\",\"r15\":\"%p\",\"entry_offset\":%llu",
            sig, info ? info->si_addr : NULL, (void *)rip,
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RSP],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RAX],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RBX],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RCX],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RDI],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RSI],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_RDX],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_R14],
            (void *)(uintptr_t)uc->uc_mcontext.gregs[REG_R15],
            entry ? (unsigned long long)(rip - entry) : 0ULL);
    if (g_active_workspace) {
        fprintf(stderr, ",\"original_tokens\":%" PRIu64 ",\"transformed_tokens\":%" PRIu64
                ",\"rounds_done\":%" PRIu64 ",\"validate_status\":%" PRId64
                ",\"error_at\":%" PRIu64,
                g_active_workspace->original_tokens,
                g_active_workspace->transformed_tokens,
                g_active_workspace->rounds_done,
                g_active_workspace->validate_status,
                g_active_workspace->error_at);
    }
    uintptr_t rsp = (uintptr_t)uc->uc_mcontext.gregs[REG_RSP];
    if (rsp) {
        const uintptr_t *stack_words = (const uintptr_t *)rsp;
        fprintf(stderr, ",\"stack\":[\"%p\",\"%p\",\"%p\",\"%p\"]",
                (void *)stack_words[0], (void *)stack_words[1],
                (void *)stack_words[2], (void *)stack_words[3]);
    }
    fprintf(stderr, "}\n");
#else
    (void)uctx;
    fprintf(stderr, "forth_crash={\"signal\":%d,\"fault\":\"%p\"}\n",
            sig, info ? info->si_addr : NULL);
#endif
    _exit(128 + sig);
}

static void install_crash_handler(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = crash_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
}

static uint8_t *read_file(const char *path, size_t *len_out) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) die(path);
    struct stat st;
    if (fstat(fd, &st) != 0) die("fstat");
    if (st.st_size < 0) {
        fprintf(stderr, "negative file size\n");
        exit(1);
    }
    uint8_t *buf = malloc((size_t)st.st_size + 1);
    if (!buf) die("malloc");
    size_t off = 0;
    while (off < (size_t)st.st_size) {
        ssize_t n = read(fd, buf + off, (size_t)st.st_size - off);
        if (n < 0) die("read");
        if (n == 0) break;
        off += (size_t)n;
    }
    close(fd);
    buf[off] = 0;
    *len_out = off;
    return buf;
}

static bool self_transfer_interpreter_supported(const uint8_t *buf, size_t len) {
    if (len < sizeof(Elf64_Ehdr)) return true;
    const Elf64_Ehdr *eh = (const Elf64_Ehdr *)(const void *)buf;
    if (eh->e_phentsize != sizeof(Elf64_Phdr) || eh->e_phoff > len ||
        (uint64_t)eh->e_phnum * sizeof(Elf64_Phdr) > len - eh->e_phoff) return true;
    const Elf64_Phdr *ph = (const Elf64_Phdr *)(const void *)(buf + eh->e_phoff);
    for (uint16_t i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type != PT_INTERP) continue;
        if (!ph[i].p_filesz || ph[i].p_offset > len || ph[i].p_filesz > len - ph[i].p_offset)
            return false;
        const char *path = (const char *)(const void *)(buf + ph[i].p_offset);
        if (!memchr(path, 0, ph[i].p_filesz)) return false;
        const char *base = strrchr(path, '/');
        base = base ? base + 1 : path;
        return ph[i].p_filesz == strlen(path) + 1 && strcmp(base, "ld-linux-x86-64.so.2") == 0;
    }
    return true;
}

static bool elf_has_interpreter(const uint8_t *buf, size_t len) {
    if (len < sizeof(Elf64_Ehdr)) return false;
    const Elf64_Ehdr *eh = (const Elf64_Ehdr *)(const void *)buf;
    if (eh->e_phentsize != sizeof(Elf64_Phdr) || eh->e_phoff > len ||
        (uint64_t)eh->e_phnum * sizeof(Elf64_Phdr) > len - eh->e_phoff) return false;
    const Elf64_Phdr *ph = (const Elf64_Phdr *)(const void *)(buf + eh->e_phoff);
    for (uint16_t i = 0; i < eh->e_phnum; i++) if (ph[i].p_type == PT_INTERP) return true;
    return false;
}

static uint64_t elf_runtime_phdr(const Elf64_Ehdr *eh, uint64_t base, uint64_t low) {
    const Elf64_Phdr *ph = (const Elf64_Phdr *)(const void *)((const uint8_t *)eh + eh->e_phoff);
    for (uint16_t i = 0; i < eh->e_phnum; i++)
        if (ph[i].p_type == PT_PHDR) return base + ph[i].p_vaddr - low;
    for (uint16_t i = 0; i < eh->e_phnum; i++)
        if (ph[i].p_type == PT_LOAD && eh->e_phoff >= ph[i].p_offset &&
            eh->e_phoff < ph[i].p_offset + ph[i].p_filesz)
            return base + ph[i].p_vaddr + eh->e_phoff - ph[i].p_offset - low;
    return 0;
}

__attribute__((noinline))
struct blob load_shellcode_blob(const char *path) {
    struct blob b = {0};
    b.bytes = read_file(path, &b.len);
    return b;
}

__attribute__((noinline))
void *prepare_exec_mapping(const struct blob *blob) {
    void *mem = mmap(NULL, blob->len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) die("mmap shellcode");
    memcpy(mem, blob->bytes, blob->len);
    if (mprotect(mem, blob->len, PROT_READ | PROT_EXEC) != 0) die("mprotect shellcode");
    return mem;
}

__attribute__((noinline))
int64_t invoke_forth_blob(void *entry, const uint8_t *input, size_t input_len,
                          uint8_t *output, size_t output_cap,
                          uint8_t *workspace, size_t workspace_len) {
    forth_blob_fn fn = (forth_blob_fn)entry;
    return fn(input, input_len, output, output_cap, workspace, workspace_len);
}

static const char *etype_name(uint16_t t) {
    switch (t) {
    case ET_EXEC: return "EXEC";
    case ET_DYN: return "DYN";
    case ET_REL: return "REL";
    default: return "OTHER";
    }
}

static void phdr_perm_string(uint32_t flags, char out[4]) {
    out[0] = (flags & PF_R) ? 'r' : '-';
    out[1] = (flags & PF_W) ? 'w' : '-';
    out[2] = (flags & PF_X) ? 'x' : '-';
    out[3] = 0;
}

static bool is_power_of_two(uint64_t n) {
    return n != 0 && (n & (n - 1)) == 0;
}

static bool add_overflows_u64(uint64_t a, uint64_t b) {
    return UINT64_MAX - a < b;
}

static uint64_t align_down_u64(uint64_t value, uint64_t align) {
    return value & ~(align - 1);
}

static uint64_t align_up_u64(uint64_t value, uint64_t align) {
    return (value + align - 1) & ~(align - 1);
}

static const Elf64_Phdr *find_phdr_by_type(const Elf64_Phdr *ph, uint16_t phnum, uint32_t type) {
    for (uint16_t i = 0; i < phnum; i++) {
        if (ph[i].p_type == type) return &ph[i];
    }
    return NULL;
}

static bool vaddr_to_file_range(const Elf64_Phdr *ph, uint16_t phnum, uint64_t vaddr,
                                uint64_t size, uint64_t *off_out) {
    for (uint16_t i = 0; i < phnum; i++) {
        if (ph[i].p_type != PT_LOAD) continue;
        if (vaddr < ph[i].p_vaddr) continue;
        uint64_t delta = vaddr - ph[i].p_vaddr;
        if (delta > ph[i].p_filesz) continue;
        if (size > ph[i].p_filesz - delta) continue;
        *off_out = ph[i].p_offset + delta;
        return true;
    }
    return false;
}

static bool entry_in_load_segment(const Elf64_Phdr *ph, uint16_t phnum, uint64_t entry) {
    for (uint16_t i = 0; i < phnum; i++) {
        if (ph[i].p_type != PT_LOAD) continue;
        if (!add_overflows_u64(ph[i].p_vaddr, ph[i].p_memsz) &&
            entry >= ph[i].p_vaddr && entry < ph[i].p_vaddr + ph[i].p_memsz) {
            return true;
        }
    }
    return false;
}

struct loaded_image {
    uint8_t *base;
    uint64_t lowest;
    uint64_t span;
    uint64_t load_bias;
};

struct reloc_stats {
    uint64_t total;
    uint64_t relative;
    uint64_t relative_applied;
    uint64_t symbolic;
    uint64_t jump_slot;
    uint64_t out_of_range;
    uint64_t unsupported;
};

static bool image_ptr_for_vaddr(const struct loaded_image *image, uint64_t vaddr,
                                uint64_t size, void **ptr_out) {
    if (!image->base || vaddr < image->lowest) return false;
    uint64_t off = vaddr - image->lowest;
    if (off > image->span || size > image->span - off) return false;
    *ptr_out = image->base + off;
    return true;
}

static bool relocation_is_symbolic(uint32_t type) {
    return type == R_X86_64_64 ||
           type == R_X86_64_GLOB_DAT ||
           type == R_X86_64_JUMP_SLOT ||
           type == R_X86_64_COPY ||
           type == R_X86_64_DTPMOD64 ||
           type == R_X86_64_DTPOFF64 ||
           type == R_X86_64_TPOFF64;
}

static void simulate_rela_table(const struct loaded_image *image, uint64_t vaddr,
                                uint64_t size, uint64_t ent, struct reloc_stats *stats) {
    if (!size) return;
    if (ent == 0) ent = sizeof(Elf64_Rela);
    if (ent < sizeof(Elf64_Rela)) {
        stats->unsupported++;
        return;
    }
    void *table = NULL;
    if (!image_ptr_for_vaddr(image, vaddr, size, &table)) {
        stats->out_of_range++;
        return;
    }
    uint64_t count = size / ent;
    for (uint64_t i = 0; i < count; i++) {
        const Elf64_Rela *rela = (const Elf64_Rela *)((const uint8_t *)table + i * ent);
        uint32_t type = ELF64_R_TYPE(rela->r_info);
        stats->total++;
        if (type == R_X86_64_RELATIVE) {
            uint64_t *target = NULL;
            stats->relative++;
            if (image_ptr_for_vaddr(image, rela->r_offset, sizeof(uint64_t), (void **)&target)) {
                *target = image->load_bias + (uint64_t)rela->r_addend;
                stats->relative_applied++;
            } else {
                stats->out_of_range++;
            }
        } else if (relocation_is_symbolic(type)) {
            stats->symbolic++;
            if (type == R_X86_64_JUMP_SLOT) stats->jump_slot++;
        } else {
            stats->unsupported++;
        }
    }
}

static void simulate_rel_table(const struct loaded_image *image, uint64_t vaddr,
                               uint64_t size, uint64_t ent, struct reloc_stats *stats) {
    if (!size) return;
    if (ent == 0) ent = sizeof(Elf64_Rel);
    if (ent < sizeof(Elf64_Rel)) {
        stats->unsupported++;
        return;
    }
    void *table = NULL;
    if (!image_ptr_for_vaddr(image, vaddr, size, &table)) {
        stats->out_of_range++;
        return;
    }
    uint64_t count = size / ent;
    for (uint64_t i = 0; i < count; i++) {
        const Elf64_Rel *rel = (const Elf64_Rel *)((const uint8_t *)table + i * ent);
        uint32_t type = ELF64_R_TYPE(rel->r_info);
        stats->total++;
        if (type == R_X86_64_RELATIVE) {
            uint64_t *target = NULL;
            stats->relative++;
            if (image_ptr_for_vaddr(image, rel->r_offset, sizeof(uint64_t), (void **)&target)) {
                *target += image->load_bias;
                stats->relative_applied++;
            } else {
                stats->out_of_range++;
            }
        } else if (relocation_is_symbolic(type)) {
            stats->symbolic++;
            if (type == R_X86_64_JUMP_SLOT) stats->jump_slot++;
        } else {
            stats->unsupported++;
        }
    }
}

static int prot_from_phdr_flags(uint32_t flags) {
    int prot = 0;
    if (flags & PF_R) prot |= PROT_READ;
    if (flags & PF_W) prot |= PROT_WRITE;
    if (flags & PF_X) prot |= PROT_EXEC;
    return prot ? prot : PROT_NONE;
}

static uint64_t forth_cell(const uint8_t *workspace, uint64_t index) {
    if (index >= DATA_CELLS) return 0;
    const uint64_t *cells = (const uint64_t *)(const void *)(workspace + DATA_BASE_OFF);
    return cells[index];
}

static int run_forth_plan_real_mappings(uint8_t *workspace, struct forth_service_state *services) {
    uint64_t objects = forth_cell(workspace, FORTH_QUEUE_TAIL);
    bool ok = objects <= FORTH_OBJECT_RECORD_MAX;
    for (uint64_t object = 0; object < objects; object++) {
        uint64_t rec = FORTH_OBJECT_RECORD_BASE + object * FORTH_OBJECT_RECORD_SIZE;
        uint64_t state = forth_cell(workspace, rec + FORTH_OBJECT_STATE);
        uint64_t base = forth_cell(workspace, rec + FORTH_OBJECT_MAP_BASE);
        uint64_t size = forth_cell(workspace, rec + FORTH_OBJECT_MAP_SIZE);
        uint64_t low = forth_cell(workspace, rec + FORTH_OBJECT_LOW_VADDR);
        uint64_t high = forth_cell(workspace, rec + FORTH_OBJECT_HIGH_VADDR) & UINT32_MAX;
        bool owned = forth_cell(workspace, rec + FORTH_OBJECT_SOURCE_KIND) == 2;
        uint64_t unresolved = forth_cell(workspace, FORTH_OBJECT_REQUIRED_UNRESOLVED_BASE + object);
        uint64_t resolved = forth_cell(workspace, FORTH_OBJECT_RESOLVED_BASE + object);
        uint64_t irelative = object < 12 ? forth_cell(workspace, FORTH_OBJECT_IRELATIVE_BASE + object) : 0;
        for (size_t i = 0; i < services->map_count; i++)
            owned = owned || ((uint64_t)(uintptr_t)services->maps[i] == base && services->map_lens[i] == size);
        ok = ok && state == 1 && base != 0 && low < high && size >= high - low && owned;
        printf("forth_object_record={\"index\":%" PRIu64 ",\"state\":%" PRIu64
               ",\"source\":%" PRIu64 ",\"source_size\":%" PRIu64
               ",\"final_base\":%p,\"low\":%" PRIu64 ",\"high\":%" PRIu64
               ",\"map_size\":%" PRIu64 ",\"strtab\":%" PRIu64
               ",\"symtab\":%" PRIu64 ",\"hash\":%" PRIu64
               ",\"gnu_hash\":%" PRIu64 ",\"syment\":%" PRIu64
               ",\"verdef\":%" PRIu64 ",\"verdefnum\":%" PRIu64
               ",\"verneed\":%" PRIu64 ",\"verneednum\":%" PRIu64
               ",\"tls_vaddr\":%" PRIu64 ",\"tls_filesz\":%" PRIu64
               ",\"tls_memsz\":%" PRIu64 ",\"tls_align\":%" PRIu64
               ",\"tls_offset\":%" PRIu64 ",\"tls_module\":%" PRIu64
               ",\"init\":%" PRIu64 ",\"init_array\":%" PRIu64
               ",\"init_arraysz\":%" PRIu64 ",\"resolved\":%" PRIu64
               ",\"relative_applied\":%" PRIu64 ",\"required_unresolved\":%" PRIu64
               ",\"required_symbol\":%" PRIu64 ",\"irelative_target\":%" PRIu64
               ",\"irelative_resolver\":%" PRIu64
               ",\"owned\":%s}\n", object, state,
               forth_cell(workspace, rec + FORTH_OBJECT_SOURCE_ADDR),
               forth_cell(workspace, rec + FORTH_OBJECT_SOURCE_SIZE),
               (void *)(uintptr_t)base, low, high, size,
               forth_cell(workspace, rec + FORTH_OBJECT_STRTAB),
               forth_cell(workspace, rec + FORTH_OBJECT_SYMTAB),
               forth_cell(workspace, rec + FORTH_OBJECT_HASH),
               forth_cell(workspace, rec + FORTH_OBJECT_GNU_HASH),
               forth_cell(workspace, rec + FORTH_OBJECT_SYMENT),
               forth_cell(workspace, FORTH_OBJECT_VERDEF_BASE + object),
               forth_cell(workspace, FORTH_OBJECT_VERDEFNUM_BASE + object),
               forth_cell(workspace, rec + FORTH_OBJECT_VERNEED) & UINT32_MAX,
               forth_cell(workspace, rec + FORTH_OBJECT_VERNEED) >> 32,
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE) & UINT32_MAX,
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 1),
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 2),
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 3) & UINT32_MAX,
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE) >> 32,
               forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 3) >> 32,
               object < FORTH_INIT_RECORD_MAX ? forth_cell(workspace, FORTH_INIT_RECORD_BASE + object * FORTH_INIT_RECORD_SIZE) : 0,
               object < FORTH_INIT_RECORD_MAX ? forth_cell(workspace, FORTH_INIT_RECORD_BASE + object * FORTH_INIT_RECORD_SIZE + 1) : 0,
               object < FORTH_INIT_RECORD_MAX ? forth_cell(workspace, FORTH_INIT_RECORD_BASE + object * FORTH_INIT_RECORD_SIZE + 2) & UINT32_MAX : 0,
               resolved & UINT32_MAX, resolved >> 32,
               unresolved & UINT32_MAX, unresolved >> 32,
               irelative & UINT32_MAX, irelative >> 32,
               owned ? "true" : "false");
    }
    printf("forth_plan_summary={\"ok\":%s,\"real_mappings\":true,\"mapped\":\"forth_service\"," 
           "\"maps\":%zu,\"transferred\":false}\n", ok ? "true" : "false", services->map_count);
    printf("forth_link_summary={\"phase\":%" PRIu64 ",\"tls_total\":%" PRIu64
           ",\"tls_base\":%" PRIu64 ",\"tcb_base\":%" PRIu64
           ",\"adapter\":%" PRIu64
           ",\"native_calls\":%" PRIu64 ",\"native_pending\":%" PRIu64
           ",\"native_results\":%" PRIu64
           ",\"ifunc_calls\":%" PRIu64 ",\"ifunc_result\":%" PRIu64
           ",\"constructors\":%" PRIu64
           ",\"gnu_candidates\":%" PRIu64
           ",\"nonempty_buckets\":%" PRIu64 ",\"first_hash_matches\":%" PRIu64 "}\n",
           forth_cell(workspace, FORTH_LINK_PHASE),
           forth_cell(workspace, FORTH_TLS_TOTAL),
           forth_cell(workspace, FORTH_TLS_BASE),
           forth_cell(workspace, FORTH_TCB_BASE),
           forth_cell(workspace, FORTH_ADAPTER_SELECTED),
           forth_cell(workspace, FORTH_NATIVE_CALLS),
           forth_cell(workspace, FORTH_NATIVE_PENDING),
           forth_cell(workspace, FORTH_NATIVE_RESULTS),
           forth_cell(workspace, FORTH_IFUNC_CALLS),
           forth_cell(workspace, FORTH_IFUNC_RESULT),
           forth_cell(workspace, FORTH_CONSTRUCTORS_CALLED),
           forth_cell(workspace, FORTH_GNU_CANDIDATES),
           forth_cell(workspace, FORTH_GNU_NONEMPTY),
           forth_cell(workspace, FORTH_GNU_HASH_MATCHES));
    printf("forth_gnu_chain={\"visited\":%" PRIu64 ",\"hash_matches\":%" PRIu64
           ",\"name_exact_matches\":%" PRIu64 ",\"resolved\":%" PRIu64
           ",\"segments_protected\":%" PRIu64 ",\"relro_protected\":%" PRIu64 "}\n",
           forth_cell(workspace, FORTH_GNU_CHAIN_VISITS),
           forth_cell(workspace, FORTH_GNU_CHAIN_MATCHES),
           forth_cell(workspace, FORTH_GNU_PREFIX_MATCHES),
           forth_cell(workspace, FORTH_SYMBOLS_RESOLVED),
           forth_cell(workspace, FORTH_SEGMENTS_PROTECTED),
           forth_cell(workspace, FORTH_RELRO_PROTECTED));
    uint64_t tls_base = forth_cell(workspace, FORTH_TLS_BASE);
    uint64_t tcb = forth_cell(workspace, FORTH_TCB_BASE);
    if (tls_base && tcb >= tls_base && services->tls_map &&
        tcb + 192 <= (uint64_t)(uintptr_t)services->tls_map + services->tls_map_len) {
        uint64_t fs_self = 0, dtv = 0, stack_guard = 0, dtv_max = 0, generation = 0;
        memcpy(&fs_self, (void *)(uintptr_t)tcb, 8);
        memcpy(&dtv, (void *)(uintptr_t)(tcb + 8), 8);
        memcpy(&stack_guard, (void *)(uintptr_t)(tcb + 48), 8);
        memcpy(&dtv_max, (void *)(uintptr_t)(tcb + 80), 8);
        memcpy(&generation, (void *)(uintptr_t)(tcb + 96), 8);
        bool dtv_ok = dtv == tcb + 96;
        for (uint64_t object = 0; object < objects; object++) {
            uint64_t module = forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 3) >> 32;
            uint64_t memsz = forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE + 2);
            uint64_t offset = forth_cell(workspace, FORTH_TLS_RECORD_BASE + object * FORTH_TLS_RECORD_SIZE) >> 32;
            if (!memsz) continue;
            uint64_t slot = 0;
            memcpy(&slot, (void *)(uintptr_t)(dtv + module * 16), 8);
            dtv_ok = dtv_ok && module == object + 1 && slot == tls_base + offset;
        }
        printf("forth_tls_control={\"fs_self\":%" PRIu64 ",\"dtv\":%" PRIu64
               ",\"stack_guard\":%" PRIu64 ",\"dtv_max\":%" PRIu64
               ",\"generation\":%" PRIu64 ",\"dtv_ok\":%s}\n",
               fs_self, dtv, stack_guard, dtv_max, generation, dtv_ok ? "true" : "false");
        ok = ok && fs_self == tcb && stack_guard != 0 && dtv_max >= objects && generation == 1 && dtv_ok;
    }
    return ok ? 0 : 1;
}

static void apply_segment_protections(const struct loaded_image *image, const Elf64_Phdr *ph, uint16_t phnum) {
    if (!g_elf_exec_protections || !image->base) return;
    long page_long = sysconf(_SC_PAGESIZE);
    uint64_t page = page_long > 0 ? (uint64_t)page_long : 4096;
    for (uint16_t i = 0; i < phnum; i++) {
        if (ph[i].p_type != PT_LOAD || ph[i].p_memsz == 0) continue;
        uint64_t rel_start = ph[i].p_vaddr - image->lowest;
        uint64_t rel_end = rel_start + ph[i].p_memsz;
        uint64_t page_start = align_down_u64(rel_start, page);
        uint64_t page_end = align_up_u64(rel_end, page);
        if (page_end > image->span) page_end = align_up_u64(image->span, page);
        if (page_start >= page_end) continue;
        int prot = prot_from_phdr_flags(ph[i].p_flags);
        if (mprotect(image->base + page_start, page_end - page_start, prot) != 0) die("mprotect elf image");
        char perms[4];
        phdr_perm_string(ph[i].p_flags, perms);
        printf("elf_protect={\"index\":%u,\"addr\":%p,\"length\":%" PRIu64
               ",\"perms\":\"%s\",\"exec\":%s,\"transferred\":false}\n",
               i, (void *)(image->base + page_start), page_end - page_start,
               perms, (ph[i].p_flags & PF_X) ? "true" : "false");
    }
}

static uint8_t *make_synthetic_elf_buffer(size_t *len_out) {
    const size_t len = 0x1100;
    uint8_t *buf = calloc(1, len);
    if (!buf) die("calloc synthetic elf");

    Elf64_Ehdr *eh = (Elf64_Ehdr *)buf;
    memcpy(eh->e_ident, ELFMAG, SELFMAG);
    eh->e_ident[EI_CLASS] = ELFCLASS64;
    eh->e_ident[EI_DATA] = ELFDATA2LSB;
    eh->e_ident[EI_VERSION] = EV_CURRENT;
    eh->e_ident[EI_OSABI] = ELFOSABI_SYSV;
    eh->e_type = ET_DYN;
    eh->e_machine = EM_X86_64;
    eh->e_version = EV_CURRENT;
    eh->e_entry = 0x100;
    eh->e_phoff = sizeof(Elf64_Ehdr);
    eh->e_ehsize = sizeof(Elf64_Ehdr);
    eh->e_phentsize = sizeof(Elf64_Phdr);
    eh->e_phnum = 2;

    Elf64_Phdr *ph = (Elf64_Phdr *)(buf + eh->e_phoff);
    ph[0].p_type = PT_LOAD;
    ph[0].p_flags = PF_R | PF_X;
    ph[0].p_offset = 0;
    ph[0].p_vaddr = 0;
    ph[0].p_filesz = 0x200;
    ph[0].p_memsz = 0x300;
    ph[0].p_align = 0x1000;

    ph[1].p_type = PT_LOAD;
    ph[1].p_flags = PF_R | PF_W;
    ph[1].p_offset = 0x1000;
    ph[1].p_vaddr = 0x2000;
    ph[1].p_filesz = 0x20;
    ph[1].p_memsz = 0x80;
    ph[1].p_align = 0x1000;

    memcpy(buf + 0x100, "synthetic-buffer-elf", 20);
    memcpy(buf + 0x1000, "buffer-data", 11);
    *len_out = len;
    return buf;
}

static uint8_t *make_synthetic_static_elf_buffer(size_t *len_out) {
    const size_t len = 0x2020;
    uint8_t *buf = calloc(1, len);
    if (!buf) die("calloc synthetic static elf");

    Elf64_Ehdr *eh = (Elf64_Ehdr *)buf;
    memcpy(eh->e_ident, ELFMAG, SELFMAG);
    eh->e_ident[EI_CLASS] = ELFCLASS64;
    eh->e_ident[EI_DATA] = ELFDATA2LSB;
    eh->e_ident[EI_VERSION] = EV_CURRENT;
    eh->e_ident[EI_OSABI] = ELFOSABI_SYSV;
    eh->e_type = ET_DYN;
    eh->e_machine = EM_X86_64;
    eh->e_version = EV_CURRENT;
    eh->e_entry = 0x1000;
    eh->e_phoff = sizeof(Elf64_Ehdr);
    eh->e_ehsize = sizeof(Elf64_Ehdr);
    eh->e_phentsize = sizeof(Elf64_Phdr);
    eh->e_phnum = 3;

    Elf64_Phdr *ph = (Elf64_Phdr *)(buf + eh->e_phoff);
    ph[0].p_type = PT_LOAD;
    ph[0].p_flags = PF_R;
    ph[0].p_offset = 0;
    ph[0].p_vaddr = 0;
    ph[0].p_filesz = 0xe8;
    ph[0].p_memsz = 0xe8;
    ph[0].p_align = 0x1000;

    ph[1].p_type = PT_LOAD;
    ph[1].p_flags = PF_R | PF_X;
    ph[1].p_offset = 0x1000;
    ph[1].p_vaddr = 0x1000;
    ph[1].p_filesz = 0x21;
    ph[1].p_memsz = 0x21;
    ph[1].p_align = 0x1000;

    ph[2].p_type = PT_LOAD;
    ph[2].p_flags = PF_R;
    ph[2].p_offset = 0x2000;
    ph[2].p_vaddr = 0x2000;
    ph[2].p_filesz = 0x1b;
    ph[2].p_memsz = 0x1b;
    ph[2].p_align = 0x1000;

    static const uint8_t code[] = {
        0xb8, 0x01, 0x00, 0x00, 0x00,
        0xbf, 0x01, 0x00, 0x00, 0x00,
        0x48, 0x8d, 0x35, 0xef, 0x0f, 0x00, 0x00,
        0xba, 0x1b, 0x00, 0x00, 0x00,
        0x0f, 0x05,
        0xb8, 0x3c, 0x00, 0x00, 0x00,
        0x31, 0xff,
        0x0f, 0x05,
    };
    memcpy(buf + 0x1000, code, sizeof(code));
    memcpy(buf + 0x2000, "hello from memory-only elf\n", 27);
    *len_out = len;
    return buf;
}

__attribute__((noinline))
int run_elf_mapping_sim_buffer(const uint8_t *buf, size_t len, const char *source_kind, const char *label) {
    printf("elf_source={\"kind\":\"%s\",\"label\":\"%s\",\"bytes\":%zu}\n", source_kind, label, len);
    if (len < sizeof(Elf64_Ehdr)) {
        fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"short_header\"}\n");
        return 1;
    }

    const Elf64_Ehdr *eh = (const Elf64_Ehdr *)buf;
    if (memcmp(eh->e_ident, ELFMAG, SELFMAG) != 0 ||
        eh->e_ident[EI_CLASS] != ELFCLASS64 ||
        eh->e_ident[EI_DATA] != ELFDATA2LSB ||
        eh->e_machine != EM_X86_64) {
        fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"unsupported_elf64_x86_64\"}\n");
        return 1;
    }
    if (eh->e_phentsize != sizeof(Elf64_Phdr) ||
        (uint64_t)eh->e_phoff + (uint64_t)eh->e_phnum * sizeof(Elf64_Phdr) > len) {
        fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"bad_program_headers\"}\n");
        return 1;
    }

    uint64_t load_count = 0, memsz_total = 0, filesz_total = 0, bss_total = 0;
    uint64_t lowest = UINT64_MAX, highest = 0;
    bool saw_exec_load = false, saw_writable_load = false, saw_bad_align = false;
    bool saw_dynamic = false, reloc_required = false, rela_present = false, rel_present = false, jmprel_present = false;
    uint64_t rela_size = 0, rel_size = 0, pltrel_size = 0, needed_count = 0;
    uint64_t rela_vaddr = 0, rel_vaddr = 0, jmprel_vaddr = 0;
    uint64_t rela_ent = sizeof(Elf64_Rela), rel_ent = sizeof(Elf64_Rel), plt_rel_kind = DT_RELA;
    const Elf64_Phdr *ph = (const Elf64_Phdr *)(buf + eh->e_phoff);
    const Elf64_Phdr *interp = find_phdr_by_type(ph, eh->e_phnum, PT_INTERP);
    if (interp && interp->p_offset + interp->p_filesz <= len && interp->p_filesz > 0) {
        printf("elf_interp={\"path\":\"%.*s\"}\n", (int)(interp->p_filesz - 1), (const char *)(buf + interp->p_offset));
    }
    for (uint16_t i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type == PT_DYNAMIC) saw_dynamic = true;
        if (ph[i].p_type != PT_LOAD) continue;
        if ((uint64_t)ph[i].p_offset + ph[i].p_filesz > len) {
            fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"segment_out_of_file\",\"index\":%u}\n", i);
            return 1;
        }
        if (ph[i].p_memsz < ph[i].p_filesz || add_overflows_u64(ph[i].p_vaddr, ph[i].p_memsz)) {
            fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"bad_segment_size\",\"index\":%u}\n", i);
            return 1;
        }
        load_count++;
        filesz_total += ph[i].p_filesz;
        memsz_total += ph[i].p_memsz;
        bss_total += ph[i].p_memsz - ph[i].p_filesz;
        saw_exec_load = saw_exec_load || ((ph[i].p_flags & PF_X) != 0);
        saw_writable_load = saw_writable_load || ((ph[i].p_flags & PF_W) != 0);
        if (ph[i].p_vaddr < lowest) lowest = ph[i].p_vaddr;
        if (ph[i].p_vaddr + ph[i].p_memsz > highest) highest = ph[i].p_vaddr + ph[i].p_memsz;

        bool align_valid = ph[i].p_align == 0 || ph[i].p_align == 1 ||
                           (is_power_of_two(ph[i].p_align) &&
                            (ph[i].p_vaddr % ph[i].p_align) == (ph[i].p_offset % ph[i].p_align));
        saw_bad_align = saw_bad_align || !align_valid;
        char perms[4];
        phdr_perm_string(ph[i].p_flags, perms);
        uint8_t *segment = calloc(1, ph[i].p_memsz ? ph[i].p_memsz : 1);
        if (!segment) die("calloc segment");
        memcpy(segment, buf + ph[i].p_offset, ph[i].p_filesz);
        printf("elf_segment={\"index\":%u,\"vaddr\":%" PRIu64 ",\"filesz\":%" PRIu64
               ",\"memsz\":%" PRIu64 ",\"bss\":%" PRIu64 ",\"flags\":%u,\"perms\":\"%s\","
               "\"align\":%" PRIu64 ",\"align_valid\":%s,\"mapped\":\"nonexec_heap\"}\n",
               i, (uint64_t)ph[i].p_vaddr, (uint64_t)ph[i].p_filesz,
               (uint64_t)ph[i].p_memsz, (uint64_t)(ph[i].p_memsz - ph[i].p_filesz),
               ph[i].p_flags, perms, (uint64_t)ph[i].p_align,
               align_valid ? "true" : "false");
        free(segment);
    }

    struct loaded_image image = {0};
    if (load_count) {
        image.lowest = lowest;
        image.span = highest - lowest;
        image.load_bias = eh->e_type == ET_DYN ? 0x700000000000ULL : 0;
        if (image.span == 0 || image.span > 128ULL * 1024ULL * 1024ULL) {
            fprintf(stderr, "elf_report={\"ok\":false,\"error\":\"image_span_unsupported\",\"span\":%" PRIu64 "}\n",
                    image.span);
            return 1;
        }
        image.base = mmap(NULL, image.span, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (image.base == MAP_FAILED) die("mmap elf image");
        for (uint16_t i = 0; i < eh->e_phnum; i++) {
            if (ph[i].p_type != PT_LOAD) continue;
            memcpy(image.base + (ph[i].p_vaddr - lowest), buf + ph[i].p_offset, ph[i].p_filesz);
        }
        printf("elf_image={\"mapped\":\"anonymous_nonexec_rw\",\"base\":%p,\"span\":%" PRIu64
               ",\"lowest_vaddr\":%" PRIu64 ",\"load_bias\":%" PRIu64
               ",\"segments_copied\":%" PRIu64 ",\"bss_zeroed\":%" PRIu64 "}\n",
               (void *)image.base, image.span, image.lowest, image.load_bias,
               load_count, bss_total);
    }

    const Elf64_Phdr *dynamic = find_phdr_by_type(ph, eh->e_phnum, PT_DYNAMIC);
    if (dynamic && dynamic->p_filesz >= sizeof(Elf64_Dyn)) {
        uint64_t dyn_off = 0;
        if (!vaddr_to_file_range(ph, eh->e_phnum, dynamic->p_vaddr, dynamic->p_filesz, &dyn_off)) {
            dyn_off = dynamic->p_offset;
        }
        if (dyn_off + dynamic->p_filesz <= len) {
            const Elf64_Dyn *dyn = (const Elf64_Dyn *)(buf + dyn_off);
            size_t dyn_count = dynamic->p_filesz / sizeof(Elf64_Dyn);
            for (size_t i = 0; i < dyn_count; i++) {
                if (dyn[i].d_tag == DT_NULL) break;
                if (dyn[i].d_tag == DT_NEEDED) needed_count++;
                if (dyn[i].d_tag == DT_RELA) {
                    rela_present = true;
                    rela_vaddr = dyn[i].d_un.d_ptr;
                }
                if (dyn[i].d_tag == DT_RELASZ) rela_size = dyn[i].d_un.d_val;
                if (dyn[i].d_tag == DT_RELAENT) rela_ent = dyn[i].d_un.d_val;
                if (dyn[i].d_tag == DT_REL) {
                    rel_present = true;
                    rel_vaddr = dyn[i].d_un.d_ptr;
                }
                if (dyn[i].d_tag == DT_RELSZ) rel_size = dyn[i].d_un.d_val;
                if (dyn[i].d_tag == DT_RELENT) rel_ent = dyn[i].d_un.d_val;
                if (dyn[i].d_tag == DT_JMPREL) {
                    jmprel_present = true;
                    jmprel_vaddr = dyn[i].d_un.d_ptr;
                }
                if (dyn[i].d_tag == DT_PLTRELSZ) pltrel_size = dyn[i].d_un.d_val;
                if (dyn[i].d_tag == DT_PLTREL) plt_rel_kind = dyn[i].d_un.d_val;
            }
        }
    }
    reloc_required = rela_present || rel_present || jmprel_present || rela_size || rel_size || pltrel_size;

    struct reloc_stats reloc_stats = {0};
    if (image.base && reloc_required) {
        if (rela_present && rela_size) simulate_rela_table(&image, rela_vaddr, rela_size, rela_ent, &reloc_stats);
        if (rel_present && rel_size) simulate_rel_table(&image, rel_vaddr, rel_size, rel_ent, &reloc_stats);
        if (jmprel_present && pltrel_size) {
            if (plt_rel_kind == DT_REL) simulate_rel_table(&image, jmprel_vaddr, pltrel_size, rel_ent, &reloc_stats);
            else simulate_rela_table(&image, jmprel_vaddr, pltrel_size, rela_ent, &reloc_stats);
        }
    }
    apply_segment_protections(&image, ph, eh->e_phnum);

    bool entry_in_load = entry_in_load_segment(ph, eh->e_phnum, eh->e_entry);
    printf("elf_dynamic={\"present\":%s,\"needed_count\":%" PRIu64
           ",\"relocation_required\":%s,\"rela_present\":%s,\"rel_present\":%s,"
           "\"jmprel_present\":%s,\"rela_size\":%" PRIu64 ",\"rel_size\":%" PRIu64
           ",\"pltrel_size\":%" PRIu64 "}\n",
           saw_dynamic ? "true" : "false", needed_count,
           reloc_required ? "true" : "false", rela_present ? "true" : "false",
           rel_present ? "true" : "false", jmprel_present ? "true" : "false",
           rela_size, rel_size, pltrel_size);
    printf("elf_relocations={\"required\":%s,\"total_seen\":%" PRIu64
           ",\"relative_seen\":%" PRIu64 ",\"relative_applied\":%" PRIu64
           ",\"symbolic_unresolved\":%" PRIu64 ",\"jump_slots\":%" PRIu64
           ",\"unsupported\":%" PRIu64 ",\"out_of_range\":%" PRIu64
           ",\"resolver_needed\":%s}\n",
           reloc_required ? "true" : "false", reloc_stats.total,
           reloc_stats.relative, reloc_stats.relative_applied,
           reloc_stats.symbolic, reloc_stats.jump_slot,
           reloc_stats.unsupported, reloc_stats.out_of_range,
           (reloc_stats.symbolic || reloc_stats.unsupported || needed_count) ? "true" : "false");
    printf("elf_initial_stack={\"prepared\":true,\"argc\":1,\"argv0\":\"%s\","
           "\"auxv_phnum\":%u,\"auxv_entry\":%" PRIu64 ",\"auxv_base_required\":%s}\n",
           label, eh->e_phnum, (uint64_t)eh->e_entry, interp ? "true" : "false");
    printf("elf_entry_transfer={\"target\":\"%s\",\"entry\":%" PRIu64
           ",\"dry_entry\":%" PRIu64 ",\"transferred\":false}\n",
           interp ? "interpreter" : "program",
           (uint64_t)eh->e_entry,
           image.load_bias + (uint64_t)eh->e_entry);

    printf("elf_report={\"ok\":true,\"type\":\"%s\",\"entry\":%" PRIu64
           ",\"phnum\":%u,\"load_segments\":%" PRIu64
           ",\"filesz_total\":%" PRIu64 ",\"memsz_total\":%" PRIu64
           ",\"bss_total\":%" PRIu64
           ",\"lowest_vaddr\":%" PRIu64 ",\"highest_vaddr\":%" PRIu64
           ",\"span\":%" PRIu64 ",\"entry_in_load\":%s,\"has_interp\":%s"
           ",\"has_dynamic\":%s,\"has_exec_load\":%s,\"has_writable_load\":%s"
           ",\"bad_alignment\":%s,\"relocation_required\":%s"
           ",\"execution\":\"not_transferred\"}\n",
           etype_name(eh->e_type), (uint64_t)eh->e_entry, eh->e_phnum,
           load_count, filesz_total, memsz_total, bss_total,
           load_count ? lowest : 0, load_count ? highest : 0,
           load_count ? highest - lowest : 0,
           entry_in_load ? "true" : "false", interp ? "true" : "false",
           saw_dynamic ? "true" : "false", saw_exec_load ? "true" : "false",
           saw_writable_load ? "true" : "false", saw_bad_align ? "true" : "false",
           reloc_required ? "true" : "false");
    if (image.base) munmap(image.base, image.span);
    if (g_loader_depth == 0 && interp && g_ld_dry_runs > 0 &&
        interp->p_offset + interp->p_filesz <= len && interp->p_filesz > 1) {
        char interp_path[PATH_MAX] = {0};
        size_t interp_len = interp->p_filesz - 1;
        if (interp_len >= sizeof(interp_path)) interp_len = sizeof(interp_path) - 1;
        memcpy(interp_path, buf + interp->p_offset, interp_len);
        for (uint64_t run = 0; run < g_ld_dry_runs; run++) {
            size_t ld_len = 0;
            uint8_t *ld_buf = read_file(interp_path, &ld_len);
            printf("elf_ld_dry_run={\"run\":%" PRIu64 ",\"path\":\"%s\",\"bytes\":%zu,"
                   "\"transferred\":false}\n",
                   run + 1, interp_path, ld_len);
            g_loader_depth++;
            int ld_rc = run_elf_mapping_sim_buffer(ld_buf, ld_len, "ld_interpreter", interp_path);
            g_loader_depth--;
            free(ld_buf);
            if (ld_rc != 0) return ld_rc;
        }
    }
    return 0;
}

__attribute__((noinline))
int run_elf_mapping_sim(const char *path) {
    size_t len = 0;
    uint8_t *buf = read_file(path, &len);
    int rc = run_elf_mapping_sim_buffer(buf, len, "disk", path);
    free(buf);
    return rc;
}

__attribute__((noinline))
int run_elf_mapping_sim_synthetic_buffer(void) {
    size_t len = 0;
    uint8_t *buf = make_synthetic_elf_buffer(&len);
    int rc = run_elf_mapping_sim_buffer(buf, len, "memory_buffer", "synthetic-elf64-x86_64");
    free(buf);
    return rc;
}

__attribute__((noinline))
int run_payload_print(void) {
    const char *msg = "stage2.5 hello from a benign payload\n";
    printf("payload_report={\"kind\":\"print\",\"ok\":true,\"bytes\":%zu}\n", strlen(msg));
    fputs(msg, stdout);
    return 0;
}

__attribute__((noinline))
int run_payload_cat_fixture(const char *path) {
    size_t len = 0;
    uint8_t *buf = read_file(path, &len);
    printf("payload_report={\"kind\":\"cat_fixture\",\"ok\":true,\"path\":\"%s\",\"bytes\":%zu}\n",
           path, len);
    if (len > 0) {
        fwrite(buf, 1, len, stdout);
        if (buf[len - 1] != '\n') putchar('\n');
    }
    free(buf);
    return 0;
}

__attribute__((noinline))
int run_payload_spawn_id(void) {
    fflush(NULL);
    pid_t pid = fork();
    if (pid < 0) die("fork");
    if (pid == 0) {
        char *const argv[] = {"/usr/bin/id", NULL};
        execv(argv[0], argv);
        _exit(127);
    }

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) die("waitpid");
    bool ok = WIFEXITED(status) && WEXITSTATUS(status) == 0;
    printf("payload_report={\"kind\":\"spawn_id\",\"ok\":%s,\"pid\":%ld,\"status\":%d,"
           "\"shell\":false,\"argv_fixed\":true}\n",
           ok ? "true" : "false", (long)pid, status);
    return ok ? 0 : 1;
}

static int run_payload_scenario(const char *payload, const char *fixture_path) {
    if (strcmp(payload, "print") == 0) return run_payload_print();
    if (strcmp(payload, "cat-fixture") == 0) return run_payload_cat_fixture(fixture_path);
    if (strcmp(payload, "spawn-id") == 0) return run_payload_spawn_id();
    if (strcmp(payload, "all") == 0) {
        int rc = 0;
        rc |= run_payload_print();
        rc |= run_payload_cat_fixture(fixture_path);
        rc |= run_payload_spawn_id();
        return rc;
    }
    fprintf(stderr, "unknown payload scenario: %s\n", payload);
    return 2;
}

__attribute__((noreturn))
static void transfer_with_initial_stack(void *target, const char *argv0,
                                        const char *const *extra_args, size_t extra_count,
                                        const char *const *environment, size_t environment_count,
                                        uint64_t phdr, uint64_t phent, uint64_t phnum,
                                        uint64_t interpreter_base, uint64_t entry,
                                        uint64_t fs_base, uint64_t environ_address) {
    size_t stack_size = 1024 * 1024;
    uint8_t *stack = mmap(NULL, stack_size, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS | MAP_STACK, -1, 0);
    if (stack == MAP_FAILED) die("mmap entry stack");
    uint8_t *cursor = stack + stack_size;
    uint64_t argp[17];
    size_t argc = extra_count + 1;
    for (size_t i = argc; i-- > 0;) {
        const char *arg = i == 0 ? argv0 : extra_args[i - 1];
        size_t arglen = strlen(arg) + 1;
        cursor -= arglen;
        memcpy(cursor, arg, arglen);
        argp[i] = (uint64_t)(uintptr_t)cursor;
    }
    cursor -= 16;
    for (unsigned i = 0; i < 16; i++) cursor[i] = (uint8_t)(i * 17 + 3);
    uint64_t randomp = (uint64_t)(uintptr_t)cursor;
    uint64_t envp[16];
    for (size_t i = environment_count; i-- > 0;) {
        size_t envlen = strlen(environment[i]) + 1;
        cursor -= envlen;
        memcpy(cursor, environment[i], envlen);
        envp[i] = (uint64_t)(uintptr_t)cursor;
    }
    uint64_t words[64];
    size_t word_count = 0;
    words[word_count++] = argc;
    for (size_t i = 0; i < argc; i++) words[word_count++] = argp[i];
    words[word_count++] = 0;
    for (size_t i = 0; i < environment_count; i++) words[word_count++] = envp[i];
    words[word_count++] = 0;
    const uint64_t auxv[] = {
        AT_PHDR, phdr, AT_PHENT, phent, AT_PHNUM, phnum,
        AT_PAGESZ, 4096, AT_BASE, interpreter_base, AT_ENTRY, entry,
        AT_UID, getuid(), AT_EUID, geteuid(), AT_GID, getgid(), AT_EGID, getegid(),
        AT_SECURE, 0, AT_RANDOM, randomp, AT_EXECFN, argp[0], AT_NULL, 0,
    };
    memcpy(words + word_count, auxv, sizeof(auxv));
    word_count += sizeof(auxv) / sizeof(auxv[0]);
    size_t words_size = word_count * sizeof(words[0]);
    cursor = (uint8_t *)((uintptr_t)(cursor - words_size) & ~(uintptr_t)15);
    memcpy(cursor, words, words_size);
    if (environ_address) {
        uint64_t target_envp = (uint64_t)(uintptr_t)(cursor + (2 + argc) * sizeof(uint64_t));
        memcpy((void *)(uintptr_t)environ_address, &target_envp, sizeof(target_envp));
    }
    if (fs_base && syscall(SYS_arch_prctl, ARCH_SET_FS, fs_base) != 0) _exit(127);
    __asm__ volatile("mov %0, %%rsp\nmov %1, %%r11\nxor %%rbp, %%rbp\nxor %%rdx, %%rdx\njmp *%%r11"
                     : : "r"(cursor), "r"(target) : "rdx", "r11", "memory");
    __builtin_unreachable();
}

struct compiled_artifact_header {
    uint64_t magic;
    uint32_t version;
    uint32_t dictionary_entries;
    uint32_t dictionary_bytes;
    uint32_t main_tokens;
    uint32_t word_tokens;
    uint32_t reserved;
};

#define COMPILED_ARTIFACT_MAGIC 0x31434d4854524f46ULL

static void emit_compiled_artifact(const char *path, const uint8_t *workspace,
                                   const struct workspace_header *hdr) {
    const uint8_t *entry = workspace + IMAGE_BASE_OFF + 49152;
    const uint8_t *start = entry;
    uint64_t dictionary_entries = hdr->word_meta >> 51;
    for (uint64_t i = 0; i < dictionary_entries; i++) {
        uint64_t kind;
        memcpy(&kind, entry, sizeof(kind));
        entry += DICT_ENTRY_SIZE;
        if (kind == DICT_CALLABLE) {
            uint16_t tokens;
            memcpy(&tokens, entry - DICT_ENTRY_SIZE + 8, sizeof(tokens));
            entry += (size_t)tokens * 16;
        } else if (kind != DICT_CONST) {
            die("compiled dictionary kind");
        }
        if (entry > workspace + ORIG_BASE_OFF) die("compiled dictionary bounds");
    }
    size_t dictionary_bytes = (size_t)(entry - start);
    struct compiled_artifact_header artifact = {
        .magic = COMPILED_ARTIFACT_MAGIC,
        .version = 1,
        .dictionary_entries = (uint32_t)dictionary_entries,
        .dictionary_bytes = (uint32_t)dictionary_bytes,
        .main_tokens = (uint32_t)hdr->original_tokens,
        .word_tokens = (uint32_t)hdr->word_meta,
    };
    uint8_t *dictionary = malloc(dictionary_bytes);
    if (!dictionary) die("malloc compiled dictionary");
    memcpy(dictionary, start, dictionary_bytes);
    for (uint8_t *cursor = dictionary; cursor < dictionary + dictionary_bytes;) {
        uint64_t kind;
        memcpy(&kind, cursor, sizeof(kind));
        if (kind == DICT_CALLABLE) {
            uint64_t body;
            uint16_t tokens;
            memcpy(&body, cursor + 16, sizeof(body));
            memcpy(&tokens, cursor + 8, sizeof(tokens));
            body -= (uint64_t)(uintptr_t)workspace;
            memcpy(cursor + 16, &body, sizeof(body));
            cursor += DICT_ENTRY_SIZE + (size_t)tokens * 16;
        } else {
            cursor += DICT_ENTRY_SIZE;
        }
    }
    FILE *output = fopen(path, "wb");
    if (!output || fwrite(&artifact, sizeof(artifact), 1, output) != 1 ||
        fwrite(dictionary, dictionary_bytes, 1, output) != 1 ||
        fwrite((const void *)(uintptr_t)hdr->original_base,
               (size_t)hdr->original_tokens * 16, 1, output) != 1 || fclose(output) != 0)
        die("write compiled artifact");
    free(dictionary);
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "usage: %s [--blob build/forth.bin] [--seed N] [--rounds N] [--script file]\n"
            "          [--elf-forth path] [--forth-bootstrap-path path] [--elf-forth-buffer-demo] [--elf path] [--elf-buffer-demo]\n"
            "          [--elf-exec-protections] [--ld-dry-runs N]\n"
            "          [--payload print|cat-fixture|spawn-id|all] [--payload-fixture examples/payload_fixture.txt]\n"
            "          [--dump-tokens] [--emit-compiled path] [--compile-only] [--callable-words] [--syscall-services] [--real-forth-mappings] [--forth-transfer|--forth-self-transfer] [--forth-lib-root path] [--forth-arg value] [--forth-env KEY=VALUE]\n"
            "          [--debug-hold] [--debug-hold-seconds N]\n"
            "       %s --input '2 3 + . cr'\n",
            argv0, argv0);
}

int main(int argc, char **argv) {
    install_crash_handler();
    if (syscall(SYS_arch_prctl, ARCH_GET_FS, &g_host_fs_base) != 0) die("ARCH_GET_FS");

    const char *blob_path = "build/forth_dev.bin";
    bool blob_set = false;
    const char *script_path = "examples/math.fs";
    const char *input_text = NULL;
    const char *forth_elf_path = NULL;
    const char *forth_bootstrap_path = NULL;
    const char *elf_path = NULL;
    bool forth_elf_buffer_demo = false;
    bool elf_buffer_demo = false;
    bool script_set = false;
    const char *payload = NULL;
    const char *payload_fixture = "examples/payload_fixture.txt";
    uint64_t seed = 1;
    uint64_t rounds = 1;
    bool dump_tokens = false;
    const char *compiled_path = NULL;
    bool compile_only = false;
    bool callable_words = true;
    bool syscall_services = false;
    bool real_forth_mappings = false;
    bool forth_transfer = false;
    bool forth_self_transfer = false;
    bool forth_self_link = false;
    const char *forth_args[16];
    size_t forth_arg_count = 0;
    const char *forth_environment[16];
    size_t forth_environment_count = 0;
    const char *forth_library_roots[8];
    size_t forth_library_root_count = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--blob") == 0 && i + 1 < argc) {
            blob_path = argv[++i];
            blob_set = true;
        }
        else if (strcmp(argv[i], "--seed") == 0 && i + 1 < argc) seed = strtoull(argv[++i], NULL, 0);
        else if (strcmp(argv[i], "--rounds") == 0 && i + 1 < argc) rounds = strtoull(argv[++i], NULL, 0);
        else if (strcmp(argv[i], "--script") == 0 && i + 1 < argc) {
            script_path = argv[++i];
            script_set = true;
        }
        else if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) input_text = argv[++i];
        else if (strcmp(argv[i], "--elf-forth") == 0 && i + 1 < argc) {
            forth_elf_path = argv[++i];
            if (!script_set && !input_text) script_path = "build/elf64_dryload.instrumented.fthp";
            callable_words = true;
        }
        else if (strcmp(argv[i], "--forth-bootstrap-path") == 0 && i + 1 < argc) {
            forth_bootstrap_path = argv[++i];
            if (!script_set && !input_text) script_path = "build/elf64_dryload.instrumented.fthp";
            callable_words = true;
            syscall_services = true;
            real_forth_mappings = true;
        }
        else if (strcmp(argv[i], "--elf-forth-buffer-demo") == 0) {
            forth_elf_buffer_demo = true;
            if (!script_set && !input_text) script_path = "build/elf64_dryload.instrumented.fthp";
            callable_words = true;
        }
        else if (strcmp(argv[i], "--elf") == 0 && i + 1 < argc) elf_path = argv[++i];
        else if (strcmp(argv[i], "--elf-buffer-demo") == 0) elf_buffer_demo = true;
        else if (strcmp(argv[i], "--elf-exec-protections") == 0) g_elf_exec_protections = true;
        else if (strcmp(argv[i], "--ld-dry-runs") == 0 && i + 1 < argc) {
            g_ld_dry_runs = strtoull(argv[++i], NULL, 0);
            if (g_ld_dry_runs > 4) g_ld_dry_runs = 4;
        }
        else if (strcmp(argv[i], "--payload") == 0 && i + 1 < argc) payload = argv[++i];
        else if (strcmp(argv[i], "--payload-fixture") == 0 && i + 1 < argc) payload_fixture = argv[++i];
        else if (strcmp(argv[i], "--dump-tokens") == 0) dump_tokens = true;
        else if (strcmp(argv[i], "--emit-compiled") == 0 && i + 1 < argc) {
            compiled_path = argv[++i];
            compile_only = true;
            callable_words = true;
        }
        else if (strcmp(argv[i], "--compile-only") == 0) compile_only = true;
        else if (strcmp(argv[i], "--callable-words") == 0) callable_words = true;
        else if (strcmp(argv[i], "--syscall-services") == 0) syscall_services = true;
        else if (strcmp(argv[i], "--real-forth-mappings") == 0) real_forth_mappings = true;
        else if (strcmp(argv[i], "--forth-transfer") == 0) {
            forth_transfer = true;
            real_forth_mappings = true;
        }
        else if (strcmp(argv[i], "--forth-self-transfer") == 0) {
            forth_transfer = true;
            forth_self_transfer = true;
            real_forth_mappings = true;
        }
        else if (strcmp(argv[i], "--forth-self-link") == 0) {
            forth_self_link = true;
            real_forth_mappings = true;
        }
        else if (strcmp(argv[i], "--forth-lib-root") == 0 && i + 1 < argc && forth_library_root_count < 8)
            forth_library_roots[forth_library_root_count++] = argv[++i];
        else if (strcmp(argv[i], "--forth-arg") == 0 && i + 1 < argc && forth_arg_count < 16)
            forth_args[forth_arg_count++] = argv[++i];
        else if (strcmp(argv[i], "--forth-env") == 0 && i + 1 < argc && forth_environment_count < 16)
            forth_environment[forth_environment_count++] = argv[++i];
        else if (strcmp(argv[i], "--debug-hold") == 0) g_debug_hold = true;
        else if (strcmp(argv[i], "--debug-hold-seconds") == 0 && i + 1 < argc) {
            g_debug_hold = true;
            g_debug_hold_seconds = strtoull(argv[++i], NULL, 0);
        }
        else {
            usage(argv[0]);
            return 2;
        }
    }

    if (!blob_set && !script_set && !input_text &&
        (forth_elf_path || forth_bootstrap_path || forth_elf_buffer_demo))
        blob_path = "build/forth.bin";

    struct blob sc = load_shellcode_blob(blob_path);
    void *entry = prepare_exec_mapping(&sc);

    size_t input_len = 0;
    uint8_t *input = input_text ? (uint8_t *)strdup(input_text) : read_file(script_path, &input_len);
    if (input_text) input_len = strlen(input_text);
    if (!input) die("input");
    size_t forth_elf_len = 0;
    uint8_t *forth_elf = NULL;
    const char *forth_elf_source = "none";
    const char *forth_elf_label = "";
    if (forth_elf_path) {
        forth_elf = read_file(forth_elf_path, &forth_elf_len);
        forth_elf_source = "disk";
        forth_elf_label = forth_elf_path;
    } else if (forth_elf_buffer_demo) {
        forth_elf = make_synthetic_static_elf_buffer(&forth_elf_len);
        forth_elf_source = "memory_buffer";
        forth_elf_label = "synthetic-static-pie-elf64-x86_64";
    }
    if ((forth_self_transfer || forth_self_link) && forth_elf &&
        !self_transfer_interpreter_supported(forth_elf, forth_elf_len)) {
        fprintf(stderr, "Forth self-transfer supports static ELFs and x86-64 glibc binaries\n");
        return 2;
    }

    uint8_t *output = calloc(1, OUTPUT_SIZE);
    uint8_t *workspace = calloc(1, WORKSPACE_SIZE);
    if (!output || !workspace) die("calloc");

    struct workspace_header *hdr = (struct workspace_header *)workspace;
    struct forth_service_state services = {
        .workspace = workspace,
        .workspace_len = WORKSPACE_SIZE,
    };
    memcpy(services.library_roots, forth_library_roots,
           forth_library_root_count * sizeof(forth_library_roots[0]));
    services.library_root_count = forth_library_root_count;
    hdr->magic = WS_MAGIC_VALUE;
    hdr->seed = seed;
    hdr->rounds = rounds;
    if (compile_only) hdr->flags |= WS_FLAG_COMPILE_ONLY;
    if (callable_words) hdr->flags |= WS_FLAG_CALLABLE;
    if (syscall_services) hdr->flags |= WS_FLAG_SYSCALL_SERVICES;
    hdr->elf_base = (uint64_t)(uintptr_t)forth_elf;
    hdr->elf_len = forth_elf_len;
    hdr->service_map = (uint64_t)(uintptr_t)service_map;
    hdr->service_unmap = (uint64_t)(uintptr_t)service_unmap;
    hdr->service_protect = (uint64_t)(uintptr_t)service_protect;
    hdr->service_read_file = (uint64_t)(uintptr_t)service_read_file;
    hdr->service_close = (uint64_t)(uintptr_t)service_close;
    hdr->service_context = (uint64_t)(uintptr_t)&services;
    hdr->service_copy = (uint64_t)(uintptr_t)service_copy;
    uint64_t *loader_cells = (uint64_t *)(void *)(workspace + DATA_BASE_OFF);
    if (forth_elf) {
        loader_cells[FORTH_OBJECT_RECORD_BASE + FORTH_OBJECT_SOURCE_KIND] = 1;
        loader_cells[FORTH_OBJECT_RECORD_BASE + FORTH_OBJECT_SOURCE_ADDR] = hdr->elf_base;
        loader_cells[FORTH_OBJECT_RECORD_BASE + FORTH_OBJECT_SOURCE_SIZE] = hdr->elf_len;
    }
    bool self_relocating_pie = forth_self_transfer && forth_elf_len >= sizeof(Elf64_Ehdr) &&
                               ((const Elf64_Ehdr *)(const void *)forth_elf)->e_type == ET_DYN &&
                               !elf_has_interpreter(forth_elf, forth_elf_len);
    loader_cells[FORTH_TRANSFER_MODE] = self_relocating_pie ? 3 : (forth_self_transfer || forth_self_link) ? 2 : forth_transfer ? 1 : 0;
    const char *runtime_path = forth_bootstrap_path ? forth_bootstrap_path : forth_elf_path;
    if (runtime_path && strlen(runtime_path) < FORTH_PATH_BUFFER_SIZE - FORTH_MAIN_PATH_OFFSET) {
        size_t main_path_len = strlen(runtime_path);
        memcpy(workspace + WORKSPACE_SIZE - FORTH_PATH_BUFFER_SIZE + FORTH_MAIN_PATH_OFFSET,
               runtime_path, main_path_len);
        loader_cells[FORTH_MAIN_PATH_LEN] = main_path_len;
    }

    g_active_workspace = hdr;
    g_active_entry = entry;
    int64_t rc = invoke_forth_blob(entry, input, input_len, output, OUTPUT_SIZE, workspace, WORKSPACE_SIZE);
    if (real_forth_mappings && rc >= 0 && (forth_elf || forth_bootstrap_path)) {
        uint64_t *loader = (uint64_t *)(void *)(workspace + DATA_BASE_OFF);
        for (uint64_t pass = 1; pass < FORTH_OBJECT_RECORD_MAX &&
             loader[FORTH_CURRENT_OBJECT] != UINT64_MAX && rc >= 0; pass++) {
            uint64_t object = loader[FORTH_CURRENT_OBJECT];
            uint64_t source = loader[FORTH_CURRENT_SOURCE];
            if (object >= FORTH_OBJECT_RECORD_MAX || source != object) {
                rc = -EINVAL;
                break;
            }
            memset(output, 0, OUTPUT_SIZE);
            rc = invoke_forth_blob(entry, input, input_len, output, OUTPUT_SIZE,
                                   workspace, WORKSPACE_SIZE);
            printf("forth_discovery_pass={\"object\":%" PRIu64 ",\"rc\":%" PRId64
                   ",\"state\":%" PRIu64 "}\n", object, rc, loader[FORTH_CURRENT_OBJECT]);
        }
    }
    g_active_workspace = NULL;
    g_active_entry = NULL;
    if (compiled_path) {
        if (rc < 0 || hdr->validate_status != 1) die("compile artifact validation");
        emit_compiled_artifact(compiled_path, workspace, hdr);
    }
    printf("forth_output=%.*s", rc > 0 ? (int)rc : 0, output);
    if (rc <= 0 || output[rc - 1] != '\n') printf("\n");
    if (forth_elf) {
        printf("forth_elf_source={\"kind\":\"%s\",\"label\":\"%s\",\"bytes\":%zu}\n",
               forth_elf_source, forth_elf_label, forth_elf_len);
    }
    printf("forth_meta={\"rc\":%" PRId64 ",\"seed\":%" PRIu64 ",\"original_tokens\":%" PRIu64
           ",\"word_tokens\":%u,\"word_count\":%u,\"word_rounds_done\":%u,\"transformed_tokens\":%" PRIu64 ",\"transforms\":%" PRIu64
           ",\"status\":%" PRId64 ",\"max_depth\":%" PRIu64
           ",\"final_depth\":%" PRIu64 ",\"trace_count\":%" PRIu64
           ",\"validate_status\":%" PRId64 ",\"error_at\":%" PRIu64
           ",\"rounds\":%" PRIu64 ",\"rounds_done\":%" PRIu64 "}\n",
           rc, hdr->seed, hdr->original_tokens, (unsigned)hdr->word_meta,
           (unsigned)(hdr->word_meta >> 32) & UINT16_MAX,
           (unsigned)(hdr->word_meta >> 48) & 7, hdr->transformed_tokens,
           hdr->transforms, hdr->status, hdr->max_depth, hdr->final_depth,
           hdr->trace_count, hdr->validate_status, hdr->error_at,
           hdr->rounds, hdr->rounds_done);
    if (dump_tokens) {
        uint64_t *orig = (uint64_t *)(uintptr_t)hdr->original_base;
        uint64_t *xform = (uint64_t *)(uintptr_t)hdr->transformed_base;
        uint64_t *trace = (uint64_t *)(uintptr_t)hdr->trace_base;
        for (uint64_t i = 0; i < hdr->original_tokens; i++) {
            printf("orig_token={\"i\":%" PRIu64 ",\"op\":%" PRIu64 ",\"imm\":%" PRIu64 "}\n",
                   i, orig[i * 2], orig[i * 2 + 1]);
        }
        for (uint64_t i = 0; i < hdr->transformed_tokens; i++) {
            printf("xform_token={\"i\":%" PRIu64 ",\"op\":%" PRIu64 ",\"imm\":%" PRIu64 "}\n",
                   i, xform[i * 2], xform[i * 2 + 1]);
        }
        if (hdr->flags & WS_FLAG_CALLABLE) {
            const uint8_t *entry = workspace + IMAGE_BASE_OFF + 49152;
            uint32_t words = (uint32_t)(hdr->word_meta >> 32) & UINT16_MAX;
            for (uint32_t i = 0; i < words; i++) {
                uint64_t kind, tokens;
                memcpy(&kind, entry, sizeof(kind));
                memcpy(&tokens, entry + 8, sizeof(tokens));
                tokens &= UINT16_MAX;
                if (kind == 3) {
                    uint64_t variants = 0;
                    const uint64_t *body = (const uint64_t *)(entry + 48);
                    for (uint64_t j = 0; j < tokens; j++) variants += body[j * 2] > OP_SYSCALL6;
                    printf("word_body={\"word\":%u,\"tokens\":%" PRIu64
                           ",\"polymorphic_tokens\":%" PRIu64 "}\n", i, tokens, variants);
                }
                entry += 48 + ((kind == 2 || kind == 3) ? tokens * 16 : 0);
            }
        }
        for (uint64_t i = 0; i < hdr->trace_count; i++) {
            printf("trace_event={\"i\":%" PRIu64 ",\"event\":%" PRIu64
                   ",\"op\":%" PRIu64 ",\"imm\":%" PRIu64 ",\"aux\":%" PRIu64 "}\n",
                   i, trace[i * 4], trace[i * 4 + 1], trace[i * 4 + 2],
                   trace[i * 4 + 3]);
        }
    }

    int elf_rc = 0;
    int payload_rc = 0;
    int forth_plan_rc = 0;
    if (real_forth_mappings && forth_elf && rc >= 0) {
        forth_plan_rc = run_forth_plan_real_mappings(workspace, &services);
    }
    if (forth_transfer && !forth_plan_rc && rc >= 0) {
        uint64_t rec = FORTH_OBJECT_RECORD_BASE;
        uint64_t base = forth_cell(workspace, rec + FORTH_OBJECT_MAP_BASE);
        uint64_t low = forth_cell(workspace, rec + FORTH_OBJECT_LOW_VADDR);
        uint64_t entry_vaddr = forth_cell(workspace, rec + FORTH_OBJECT_ENTRY) & UINT32_MAX;
        uint64_t size = forth_cell(workspace, rec + FORTH_OBJECT_MAP_SIZE);
        if (!base || entry_vaddr < low || entry_vaddr - low >= size || forth_elf_len < sizeof(Elf64_Ehdr) ||
            false) {
            fprintf(stderr, "Forth transfer currently requires one static object\n");
            forth_plan_rc = 2;
        } else {
            const Elf64_Ehdr *eh = (const Elf64_Ehdr *)(const void *)forth_elf;
            uint64_t program_entry = base + entry_vaddr - low;
            uint64_t interpreter_base = 0;
            uint64_t environ_address = 0;
            uint64_t transfer_entry = program_entry;
            if (!forth_self_transfer && services.map_count > 1) {
                uint64_t ldrec = FORTH_OBJECT_RECORD_BASE + FORTH_OBJECT_RECORD_SIZE;
                interpreter_base = forth_cell(workspace, ldrec + FORTH_OBJECT_MAP_BASE) -
                                   forth_cell(workspace, ldrec + FORTH_OBJECT_LOW_VADDR);
                transfer_entry = interpreter_base + (forth_cell(workspace, ldrec + FORTH_OBJECT_ENTRY) & UINT32_MAX);
            } else if (forth_cell(workspace, FORTH_ADAPTER_SELECTED)) {
                uint64_t libc_object = forth_cell(workspace, FORTH_LIBC_OBJECT);
                if (libc_object < services.map_count) {
                    uint64_t libcrec = FORTH_OBJECT_RECORD_BASE + libc_object * FORTH_OBJECT_RECORD_SIZE;
                    uint64_t adapter = forth_cell(workspace, FORTH_ADAPTER_SELECTED) - 1;
                    environ_address = forth_cell(workspace, libcrec + FORTH_OBJECT_MAP_BASE) -
                                      forth_cell(workspace, libcrec + FORTH_OBJECT_LOW_VADDR) +
                                      forth_cell(workspace, FORTH_ADAPTER_BASE + adapter * FORTH_ADAPTER_SIZE + 6);
                }
            }
            void *target = (void *)(uintptr_t)transfer_entry;
            printf("forth_entry_transfer={\"kind\":\"%s\",\"target\":%p,\"transferred\":true}\n",
                   interpreter_base ? "interpreter" : "program", target);
            fflush(NULL);
            transfer_with_initial_stack(target, forth_elf_label,
                                        forth_args, forth_arg_count,
                                        forth_environment, forth_environment_count,
                                        elf_runtime_phdr(eh, base, low),
                                        eh->e_phentsize, eh->e_phnum,
                                        interpreter_base, program_entry,
                                        interpreter_base ? 0 : forth_cell(workspace, FORTH_TCB_BASE),
                                        environ_address);
        }
    }
    if (payload) payload_rc = run_payload_scenario(payload, payload_fixture);
    if (elf_path) elf_rc = run_elf_mapping_sim(elf_path);
    if (!elf_rc && elf_buffer_demo) elf_rc = run_elf_mapping_sim_synthetic_buffer();

    for (size_t i = 0; i < services.map_count; i++) {
        if (services.maps[i] && munmap(services.maps[i], services.map_lens[i]) != 0)
            die("munmap Forth-owned object");
    }
    if (services.tls_map && munmap(services.tls_map, services.tls_map_len) != 0)
        die("munmap Forth TLS block");
    for (size_t i = 0; i < FORTH_OBJECT_RECORD_MAX; i++) free(services.sources[i]);

    munmap(entry, sc.len);
    free(sc.bytes);
    free(input);
    free(forth_elf);
    free(output);
    free(workspace);
    return rc < 0 ? 1 : (forth_plan_rc ? forth_plan_rc : (payload_rc ? payload_rc : elf_rc));
}
