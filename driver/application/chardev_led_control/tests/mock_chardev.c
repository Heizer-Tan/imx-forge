/**
 * @file mock_chardev.c
 * @brief Mock character device implementation for testing LED control
 * @date 2026-04-18
 */

#include "mock_chardev.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_led_dev_t* mock_led_create(void) {
    mock_led_dev_t* dev = calloc(1, sizeof(mock_led_dev_t));
    if (!dev) {
        return NULL;
    }

    // Create a temporary file for the mock device
    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/mock_led_%d", getpid());

    // Open the file with O_RDWR | O_CREAT
    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    // Initialize with LED off state ('0')
    dev->led_state = false;
    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    return dev;
}

void mock_led_destroy(mock_led_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    // Clean up the temporary file
    unlink(dev->temp_path);

    free(dev);
}

int mock_led_get_fd(mock_led_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_led_get_path(mock_led_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

bool mock_led_get_state(mock_led_dev_t* dev) {
    return dev ? dev->led_state : false;
}

void mock_led_get_stats(mock_led_dev_t* dev, int* open_count, int* write_count, int* read_count) {
    if (!dev) {
        return;
    }

    if (open_count) {
        *open_count = dev->open_count;
    }
    if (write_count) {
        *write_count = dev->write_count;
    }
    if (read_count) {
        *read_count = dev->read_count;
    }
}

void mock_led_reset_stats(mock_led_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}
