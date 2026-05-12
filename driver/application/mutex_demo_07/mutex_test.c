/**
 * @file mutex_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Mutex demo application
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
#include <string.h>
#include <unistd.h>

void print_help(const char* app_name) {
    printf("Usage: %s <command> [args]\n", app_name);
    printf("Commands:\n");
    printf("  read              - Read current state\n");
    printf("  write <value>     - Write value to shared data\n");
    printf("  slow_write <value> - Write with delay (demonstrates sleeping)\n");
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/mutex_demo";

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
    // Handle write command
    else if (strcmp(cmd, "write") == 0) {
        if (argc < 3) {
            printf("Error: 'write' requires a value argument\n");
            close(fd);
            return 1;
        }
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "write %s", argv[2]);
        write(fd, cmd_buf, len);
        printf("Operation 'write' completed\n");
    }
    // Handle slow_write command
    else if (strcmp(cmd, "slow_write") == 0) {
        if (argc < 3) {
            printf("Error: 'slow_write' requires a value argument\n");
            close(fd);
            return 1;
        }
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "slow_write %s", argv[2]);
        write(fd, cmd_buf, len);
        printf("Operation 'slow_write' completed\n");
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
