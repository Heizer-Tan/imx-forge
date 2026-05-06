#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#define DEVICE_PATH "/dev/beep"
static const uint8_t BEEP_ON  = 0; //这里使用0为ON，是因为正点的板子是低电平触发。
static const uint8_t BEEP_OFF = 1;
static const uint8_t BEEP_DURATION_SEC = 1;

static void print_usage(const char *prog)
{
    fprintf(stderr, "Usage: %s <0|1|2>\n", prog);
    fprintf(stderr, "  0 - turn beep ON\n");
    fprintf(stderr, "  1 - turn beep OFF\n");
    fprintf(stderr, "  2 - beep once for 1 second (auto-off)\n");
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    const int fd = open(DEVICE_PATH, O_WRONLY);
    if (fd < 0) {
        fprintf(stderr, "Failed to open %s: %s\n", DEVICE_PATH, strerror(errno));
        return EXIT_FAILURE;
    }

    char mode = argv[1][0];
    switch (mode) {
    case '0':
    {
        uint8_t val = BEEP_ON;
        if (write(fd, &val, 1) != 1) {
            fprintf(stderr, "Failed to write: %s\n", strerror(errno));
            close(fd);
            return EXIT_FAILURE;
        }
        printf("Input: 0 -> Beep turned ON\n");
        break;
    }
    case '1':
    {
        uint8_t val = BEEP_OFF;
        if (write(fd, &val, 1) != 1) {
            fprintf(stderr, "Failed to write: %s\n", strerror(errno));
            close(fd);
            return EXIT_FAILURE;
        }
        printf("Input: 1 -> Beep turned OFF\n");
        break;
    }
    case '2':
    {
        uint8_t val = BEEP_ON;
        if (write(fd, &val, 1) != 1) {
            fprintf(stderr, "Failed to turn beep ON: %s\n", strerror(errno));
            close(fd);
            return EXIT_FAILURE;
        }
        sleep(BEEP_DURATION_SEC);
        val = BEEP_OFF;
        if (write(fd, &val, 1) != 1) {
            fprintf(stderr, "Failed to turn beep OFF: %s\n", strerror(errno));
            close(fd);
            return EXIT_FAILURE;
        }
        printf("Beeped for 1 second\n");
        break;
    }
    default:
        fprintf(stderr, "Error: invalid argument '%c'. Must be 0, 1, or 2.\n", mode);
        print_usage(argv[0]);
        close(fd);
        return EXIT_FAILURE;
    }

    close(fd);
    return EXIT_SUCCESS;
}