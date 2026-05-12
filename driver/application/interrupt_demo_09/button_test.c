/**
 * @file button_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Interrupt demo application
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
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

struct button_event {
    int pressed;
    unsigned long long timestamp_ns;
};

static void print_timestamp(unsigned long long ns) {
    time_t sec = ns / 1000000000ULL;
    struct tm* tm = localtime(&sec);
    printf("%02d:%02d:%02d", tm->tm_hour, tm->tm_min, tm->tm_sec);
}

void print_help(const char* app_name) {
    printf("Usage: %s <command>\n", app_name);
    printf("Commands:\n");
    printf("  monitor           - Monitor button events (poll mode)\n");
    printf("  stats             - Get interrupt statistics\n");
}

static int do_stats(int fd) {
    unsigned long long stats[4];
    int ret = ioctl(fd, 0, stats);
    if (ret < 0) {
        printf("ioctl failed, code: %d\n", errno);
        return -1;
    }

    printf("Interrupt Statistics:\n");
    printf("  IRQ count:     %llu\n", stats[0]);
    printf("  Press count:   %llu\n", stats[1]);
    printf("  Release count: %llu\n", stats[2]);
    printf("  Skipped:       %llu\n", stats[3]);
    return 0;
}

static int do_monitor(int fd) {
    struct button_event event;
    struct pollfd pfd;

    printf("Button monitor started. Press Ctrl+C to exit.\n");

    pfd.fd = fd;
    pfd.events = POLLIN;

    while (1) {
        int ret = poll(&pfd, 1, -1);
        if (ret < 0) {
            printf("poll failed, code: %d\n", errno);
            break;
        }

        if (pfd.revents & POLLIN) {
            ssize_t bytes = read(fd, &event, sizeof(event));
            if (bytes == sizeof(event)) {
                print_timestamp(event.timestamp_ns);
                printf(" - Button %s\n", event.pressed ? "PRESSED" : "RELEASED");
            } else if (bytes < 0) {
                printf("read failed, code: %d\n", errno);
                break;
            }
        }
    }

    return 0;
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/interrupt_demo";

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

    if (strcmp(cmd, "monitor") == 0) {
        ret = do_monitor(fd);
    } else if (strcmp(cmd, "stats") == 0) {
        ret = do_stats(fd);
    } else {
        printf("Error: unknown command '%s'\n", cmd);
        print_help(argv[0]);
        ret = -1;
    }

    close(fd);
    return ret ? 1 : 0;
}
