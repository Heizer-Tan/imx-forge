/**
 * @file buffer_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Blocking I/O demo application
 * @note Clangd might dump, build once to override the kernel compile!
 * @version 1.0
 * @date 2026-05-10
 *
 * @copyright Copyright (c) 2026
 *
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

void print_help(const char* app_name) {
    printf("Usage: %s <command> [args]\n", app_name);
    printf("Commands:\n");
    printf("  write <string>    - Write string to buffer\n");
    printf("  read <n>          - Read n bytes from buffer\n");
    printf("  prodcons          - Producer-consumer test (fork)\n");
}

static int do_write(int fd, const char* str) {
    size_t len = strlen(str);
    ssize_t ret = write(fd, str, len);
    if (ret < 0) {
        printf("write failed, code: %d\n", errno);
        return -1;
    }

    printf("Wrote %zd bytes\n", ret);
    return 0;
}

static int do_read(int fd, int count) {
    char* buf = malloc(count + 1);
    if (!buf) {
        printf("malloc failed\n");
        return -1;
    }

    ssize_t ret = read(fd, buf, count);
    if (ret < 0) {
        printf("read failed, code: %d\n", errno);
        free(buf);
        return -1;
    }

    buf[ret] = '\0';
    printf("Read %zd bytes: %s\n", ret, buf);
    free(buf);
    return 0;
}

static int do_prodcons(int fd) {
    pid_t pid = fork();
    if (pid < 0) {
        printf("fork failed, code: %d\n", errno);
        return -1;
    }

    if (pid == 0) {
        // Child: consumer
        printf("Consumer: waiting for data...\n");
        char buf[128];
        ssize_t ret = read(fd, buf, sizeof(buf) - 1);
        if (ret < 0) {
            printf("read failed, code: %d\n", errno);
            exit(1);
        }

        buf[ret] = '\0';
        printf("Consumer: read %zd bytes: %s\n", ret, buf);
        exit(0);
    } else {
        // Parent: producer
        const char* test_msg = "Hello, blocking I/O!";
        size_t len = strlen(test_msg);

        printf("Producer: writing %zu bytes\n", len);
        sleep(1);  // Let consumer start waiting first

        ssize_t ret = write(fd, test_msg, len);
        if (ret < 0) {
            printf("write failed, code: %d\n", errno);
            wait(NULL);
            return -1;
        }

        printf("Producer: wrote %zd bytes\n", ret);
        wait(NULL);
    }

    return 0;
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/blocking_io_demo";

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
            ret = do_write(fd, argv[2]);
        }
    } else if (strcmp(cmd, "read") == 0) {
        if (argc < 3) {
            printf("Error: 'read' requires a count argument\n");
            ret = -1;
        } else {
            ret = do_read(fd, atoi(argv[2]));
        }
    } else if (strcmp(cmd, "prodcons") == 0) {
        ret = do_prodcons(fd);
    } else {
        printf("Error: unknown command '%s'\n", cmd);
        print_help(argv[0]);
        ret = -1;
    }

    close(fd);
    return ret ? 1 : 0;
}
