/**
 * @file led_control.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief A Simple LED Control Apps
 * @note Clangd might dumped, build once to override the kernel compile!
 * @version 0.1
 * @date 2026-04-18
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
    printf("Usage: %s /path/to/chardev_file <0/1>\n", app_name);
    printf("    - /path/to/chardev_file: char dev file in /dev/, which should be the led handle "
           "file\n");
    printf("    - <0/1>: 0 for off, 1 for on\n");
    printf("@note: make sure the protocols match!\n");
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        print_help(argv[0]);
        return 1;
    }

    const char* dev_file = argv[1];
    const char* user_indication = argv[2];

    if (strcmp(user_indication, "1") != 0 && strcmp(user_indication, "0") != 0) {
        printf("Expected only 1 and 0, but get %s\n", user_indication);
        return 1;
    }

    const int dev_file_fd = open(dev_file, O_RDWR);
    if (dev_file_fd < 0) {
        printf("Failed to open the file: %s, code: %d\n", dev_file, errno);
        return 1;
    }

    write(dev_file_fd, user_indication, 1);

    // OK, read once
    char buffer[2] = {0};
    const int bytes = read(dev_file_fd, buffer, 1);
    if (bytes < 0) {
        printf("Failed to read the file: %s, code: %d\n", dev_file, errno);
        return 1;
    }
    if (buffer[0] == '1') {
        printf("LED is on now, status from the dev file!\n");
    } else if (buffer[0] == '0') {
        printf("LED is off now, status from the dev file!\n");
    } else {
        printf("Unknown value: %s", buffer);
        return -1;
    }

    return 0;
}
