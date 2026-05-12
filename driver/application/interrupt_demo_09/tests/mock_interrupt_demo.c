/**
 * @file mock_interrupt_demo.c
 * @brief Mock interrupt demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_interrupt_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_interrupt_dev_t* mock_interrupt_create(void) {
    mock_interrupt_dev_t* dev = calloc(1, sizeof(mock_interrupt_dev_t));
    if (!dev) {
        return NULL;
    }

    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/interrupt_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    dev->press_count = 0;
    dev->release_count = 0;
    dev->open_count = 1;
    dev->read_count = 0;

    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_interrupt_destroy(mock_interrupt_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    unlink(dev->temp_path);
    free(dev);
}

int mock_interrupt_get_fd(mock_interrupt_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_interrupt_get_path(mock_interrupt_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_interrupt_get_press_count(mock_interrupt_dev_t* dev) {
    return dev ? dev->press_count : 0;
}

int mock_interrupt_get_release_count(mock_interrupt_dev_t* dev) {
    return dev ? dev->release_count : 0;
}

void mock_interrupt_get_stats(mock_interrupt_dev_t* dev, int* open_count,
                               int* read_count) {
    if (!dev) {
        return;
    }

    if (open_count) {
        *open_count = dev->open_count;
    }
    if (read_count) {
        *read_count = dev->read_count;
    }
}

void mock_interrupt_reset_stats(mock_interrupt_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->read_count = 0;
}
