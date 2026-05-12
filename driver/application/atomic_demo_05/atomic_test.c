/**
 * @file atomic_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Atomic operations demo application
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
    printf("  read              - Read statistics\n");
    printf("  set <value>       - Set counter to value\n");
    printf("  add <value>       - Add value to counter\n");
    printf("  sub <value>       - Subtract value from counter\n");
    printf("  inc               - Increment counter\n");
    printf("  dec               - Decrement counter\n");
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/atomic_demo";

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
    // Handle add command
    else if (strcmp(cmd, "add") == 0) {
        if (argc < 3) {
            printf("Error: 'add' requires a value argument\n");
            close(fd);
            return 1;
        }
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "add %s", argv[2]);
        write(fd, cmd_buf, len);
        printf("Operation 'add' completed\n");
    }
    // Handle sub command
    else if (strcmp(cmd, "sub") == 0) {
        if (argc < 3) {
            printf("Error: 'sub' requires a value argument\n");
            close(fd);
            return 1;
        }
        char cmd_buf[64];
        const int len = snprintf(cmd_buf, sizeof(cmd_buf), "sub %s", argv[2]);
        write(fd, cmd_buf, len);
        printf("Operation 'sub' completed\n");
    }
    // Handle inc command
    else if (strcmp(cmd, "inc") == 0) {
        write(fd, "inc", 3);
        printf("Operation 'inc' completed\n");
    }
    // Handle dec command
    else if (strcmp(cmd, "dec") == 0) {
        write(fd, "dec", 3);
        printf("Operation 'dec' completed\n");
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
