/**
 * @file async_test.c
 * @author Charliechen114514 (chengh1922@mails.jlu.edu.cn)
 * @brief Async notification demo application
 * @note Clangd might dump, build once to override the kernel compile!
 * @version 1.0
 * @date 2026-05-10
 *
 * @copyright Copyright (c) 2026
 *
 */

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static volatile int signal_received = 0;

static void sigio_handler(int signo) {
    (void)signo;
    signal_received = 1;
}

void print_help(const char* app_name) {
    printf("Usage: %s <command>\n", app_name);
    printf("Commands:\n");
    printf("  monitor           - Monitor button events (async notification)\n");
    printf("  stats             - Get statistics\n");
}

static int do_stats(int fd) {
    unsigned long long stats[3];
    int ret = ioctl(fd, 0, stats);
    if (ret < 0) {
        printf("ioctl failed, code: %d\n", errno);
        return -1;
    }

    printf("Async Notify Statistics:\n");
    printf("  Press count:   %llu\n", stats[0]);
    printf("  Release count: %llu\n", stats[1]);
    printf("  Notify count:  %llu\n", stats[2]);
    return 0;
}

static int do_monitor(int fd) {
    struct sigaction sa;

    // Setup signal handler
    sa.sa_flags = SA_RESTART;
    sa.sa_handler = sigio_handler;
    sigemptyset(&sa.sa_mask);

    if (sigaction(SIGIO, &sa, NULL) < 0) {
        printf("sigaction failed, code: %d\n", errno);
        return -1;
    }

    // Set file descriptor owner
    if (fcntl(fd, F_SETOWN, getpid()) < 0) {
        printf("fcntl F_SETOWN failed, code: %d\n", errno);
        return -1;
    }

    // Enable async notification
    int flags = fcntl(fd, F_GETFL);
    if (fcntl(fd, F_SETFL, flags | O_ASYNC) < 0) {
        printf("fcntl F_SETFL O_ASYNC failed, code: %d\n", errno);
        return -1;
    }

    printf("Async notification demo started.\n");
    printf("Press the button to receive SIGIO signals.\n");
    printf("Press Ctrl+C to exit.\n\n");

    // Main loop
    while (1) {
        // Wait for signal
        pause();

        if (signal_received) {
            signal_received = 0;

            // Read button state
            int state;
            ssize_t ret = read(fd, &state, sizeof(state));
            if (ret == sizeof(state)) {
                printf("Button event: %s\n", state ? "PRESSED" : "RELEASED");
            } else if (ret < 0) {
                printf("read failed, code: %d\n", errno);
                break;
            }
        }
    }

    return 0;
}

int main(int argc, char* argv[]) {
    const char* dev_path = "/dev/async_notify_demo";

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
