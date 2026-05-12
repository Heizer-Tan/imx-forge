/**
 * @file spinlock_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Spinlock demo application
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
#include <unistd.h>

void print_help(const char* app_name) {
    printf("Usage: %s <command> [args]\n", app_name);
    printf("Commands:\n");
    printf("  read              - Read statistics\n");
    printf("  protected <n>     - Do n protected increments\n");
    printf("  unprotected <n>  - Do n unprotected increments\n");
    printf("  reset             - Reset counters\n");
    printf("  stress <n>        - Run stress test with n iterations\n");
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/spinlock_demo";

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

    // Handle read command
    if (strcmp(cmd, "read") == 0) {
        char buf[1024];
        const int bytes = read(fd, buf, sizeof(buf) - 1);
        if (bytes < 0) {
            printf("Failed to read, code: %d\n", errno);
            close(fd);
            return 1;
        }
        buf[bytes] = '\0';
        printf("%s\n", buf);
    }
    // Handle protected command
    else if (strcmp(cmd, "protected") == 0) {
        int n = argc >= 3 ? atoi(argv[2]) : 1;
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "protected %d", n);
        write(fd, cmd_buf, len);
        printf("Operation 'protected' completed\n");
    }
    // Handle unprotected command
    else if (strcmp(cmd, "unprotected") == 0) {
        int n = argc >= 3 ? atoi(argv[2]) : 1;
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "unprotected %d", n);
        write(fd, cmd_buf, len);
        printf("Operation 'unprotected' completed\n");
    }
    // Handle reset command
    else if (strcmp(cmd, "reset") == 0) {
        write(fd, "reset", 5);
        printf("Operation 'reset' completed\n");
    }
    // Handle stress command
    else if (strcmp(cmd, "stress") == 0) {
        int n = argc >= 3 ? atoi(argv[2]) : 1000;
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "stress %d", n);
        write(fd, cmd_buf, len);
        printf("Operation 'stress' completed\n");
    }
    // Unknown command
    else {
        printf("Error: unknown command '%s'\n", cmd);
        print_help(argv[0]);
        close(fd);
        return 1;
    }

    close(fd);
    return 0;
}
