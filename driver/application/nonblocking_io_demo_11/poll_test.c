/**
 * @file poll_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Non-blocking I/O & poll demo application
 * @note Clangd might dump, build once to override the kernel compile!
 * @version 1.0
 * @date 2026-05-10
 *
 * @copyright Copyright (c) 2026
 *
 */

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void print_help(const char* app_name) {
    printf("Usage: %s <command> [args]\n", app_name);
    printf("Commands:\n");
    printf("  write <string>    - Write string to buffer\n");
    printf("  read <n>          - Read n bytes from buffer\n");
    printf("  poll              - Poll test (timeout 2s)\n");
    printf("  nonblock <str>    - Non-blocking write test\n");
}

static int do_write(int fd, const char* str, int nonblock) {
    size_t len = strlen(str);
    int flags = 0;

    if (nonblock) {
        flags = fcntl(fd, F_GETFL);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    ssize_t ret = write(fd, str, len);
    if (ret < 0) {
        if (errno == EAGAIN) {
            printf("Write would block (buffer full)\n");
        } else {
            printf("write failed, code: %d\n", errno);
        }
        if (nonblock) {
            fcntl(fd, F_SETFL, flags);
        }
        return -1;
    }

    printf("Wrote %zd bytes\n", ret);

    if (nonblock) {
        fcntl(fd, F_SETFL, flags);
    }

    return 0;
}

static int do_read(int fd, int count, int nonblock) {
    char* buf;
    int flags = 0;

    if (nonblock) {
        flags = fcntl(fd, F_GETFL);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    buf = malloc(count + 1);
    if (!buf) {
        printf("malloc failed\n");
        if (nonblock) {
            fcntl(fd, F_SETFL, flags);
        }
        return -1;
    }

    ssize_t ret = read(fd, buf, count);
    if (ret < 0) {
        if (errno == EAGAIN) {
            printf("Read would block (no data)\n");
        } else {
            printf("read failed, code: %d\n", errno);
        }
        free(buf);
        if (nonblock) {
            fcntl(fd, F_SETFL, flags);
        }
        return -1;
    }

    buf[ret] = '\0';
    printf("Read %zd bytes: %s\n", ret, buf);
    free(buf);

    if (nonblock) {
        fcntl(fd, F_SETFL, flags);
    }

    return 0;
}

static int do_poll_test(int fd) {
    struct pollfd pfd;

    printf("Poll test started. Press Ctrl+C to exit.\n");

    pfd.fd = fd;
    pfd.events = POLLIN;

    while (1) {
        // 2 second timeout
        int ret = poll(&pfd, 1, 2000);

        if (ret < 0) {
            printf("poll failed, code: %d\n", errno);
            break;
        } else if (ret == 0) {
            printf("Timeout: no data within 2 seconds\n");
            continue;
        }

        if (pfd.revents & POLLIN) {
            char buf[128];
            ret = read(fd, buf, sizeof(buf) - 1);
            if (ret > 0) {
                buf[ret] = '\0';
                printf("Read %d bytes: %s\n", ret, buf);
            } else if (ret < 0 && errno != EAGAIN) {
                printf("read failed, code: %d\n", errno);
                break;
            }
        }
    }

    return 0;
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/nonblocking_io_demo";

    if (argc < 2) {
        print_help(argv[0]);
        return 1;
    }

    const int fd = open(dev_path, O_RDWR);
    if (fd < 0) {
        printf("Failed to open %s, code: %d\n", dev_path, errno);
        return 1;
    }

    const char* cmd = argv[1];
    int ret = 0;

    if (strcmp(cmd, "write") == 0) {
        if (argc < 3) {
            printf("Error: 'write' requires a string argument\n");
            ret = -1;
        } else {
            ret = do_write(fd, argv[2], 0);
        }
    } else if (strcmp(cmd, "read") == 0) {
        if (argc < 3) {
            printf("Error: 'read' requires a count argument\n");
            ret = -1;
        } else {
            ret = do_read(fd, atoi(argv[2]), 0);
        }
    } else if (strcmp(cmd, "poll") == 0) {
        ret = do_poll_test(fd);
    } else if (strcmp(cmd, "nonblock") == 0) {
        if (argc < 3) {
            printf("Error: 'nonblock' requires a string argument\n");
            ret = -1;
        } else {
            ret = do_write(fd, argv[2], 1);
        }
    } else {
        printf("Error: unknown command '%s'\n", cmd);
        print_help(argv[0]);
        ret = -1;
    }

    close(fd);
    return ret ? 1 : 0;
}
