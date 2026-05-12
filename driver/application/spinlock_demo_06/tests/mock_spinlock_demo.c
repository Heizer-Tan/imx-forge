/**
 * @file mock_spinlock_demo.c
 * @brief Mock spinlock demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_spinlock_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_spinlock_dev_t* mock_spinlock_create(void) {
    mock_spinlock_dev_t* dev = calloc(1, sizeof(mock_spinlock_dev_t));
    if (!dev) {
        return NULL;
    }

    // Create temporary file
    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/spinlock_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    // Initialize state
    dev->protected_counter = 0;
    dev->unprotected_counter = 0;
    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    // Write initial state
    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_spinlock_destroy(mock_spinlock_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    // Clean up temporary file
    unlink(dev->temp_path);

    free(dev);
}

int mock_spinlock_get_fd(mock_spinlock_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_spinlock_get_path(mock_spinlock_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_spinlock_get_protected_counter(mock_spinlock_dev_t* dev) {
    return dev ? dev->protected_counter : 0;
}

int mock_spinlock_get_unprotected_counter(mock_spinlock_dev_t* dev) {
    return dev ? dev->unprotected_counter : 0;
}

void mock_spinlock_get_stats(mock_spinlock_dev_t* dev, int* open_count,
                              int* write_count, int* read_count) {
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

void mock_spinlock_reset_stats(mock_spinlock_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}
