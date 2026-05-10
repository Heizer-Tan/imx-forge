/**
 * @file timer_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Timer demo application
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
    printf("  read              - Read timer statistics\n");
    printf("  start [ms]        - Start timer (optional interval in ms)\n");
    printf("  stop              - Stop timer\n");
    printf("  set <ms>          - Set interval (restarts if running)\n");
    printf("  reset             - Reset statistics\n");
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/timer_demo";

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
    // Handle start command
    else if (strcmp(cmd, "start") == 0) {
        char cmd_buf[64];
        int len;
        if (argc >= 3) {
            len = snprintf(cmd_buf, sizeof(cmd_buf), "start %s", argv[2]);
        } else {
            len = snprintf(cmd_buf, sizeof(cmd_buf), "start");
        }
        write(fd, cmd_buf, len);
        printf("Operation 'start' completed\n");
    }
    // Handle stop command
    else if (strcmp(cmd, "stop") == 0) {
        write(fd, "stop", 4);
        printf("Operation 'stop' completed\n");
    }
    // Handle set command
    else if (strcmp(cmd, "set") == 0) {
        if (argc < 3) {
            printf("Error: 'set' requires a value argument\n");
            close(fd);
            return 1;
        }
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "set %s", argv[2]);
        write(fd, cmd_buf, len);
        printf("Operation 'set' completed\n");
    }
    // Handle reset command
    else if (strcmp(cmd, "reset") == 0) {
        write(fd, "reset", 5);
        printf("Operation 'reset' completed\n");
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
