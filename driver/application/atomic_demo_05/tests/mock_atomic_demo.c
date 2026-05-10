/**
 * @file mock_atomic_demo.c
 * @brief Mock atomic demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_atomic_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_atomic_dev_t* mock_atomic_create(void) {
    mock_atomic_dev_t* dev = calloc(1, sizeof(mock_atomic_dev_t));
    if (!dev) {
        return NULL;
    }

    // Create temporary file
    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/atomic_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    // Initialize state
    dev->counter = 0;
    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    // Write initial state
    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_atomic_destroy(mock_atomic_dev_t* dev) {
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

int mock_atomic_get_fd(mock_atomic_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_atomic_get_path(mock_atomic_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_atomic_get_counter(mock_atomic_dev_t* dev) {
    return dev ? dev->counter : 0;
}

void mock_atomic_set_counter(mock_atomic_dev_t* dev, int value) {
    if (!dev) {
        return;
    }

    dev->counter = value;

    // Update file content
    if (dev->fd >= 0) {
        char buf[32];
        int len = snprintf(buf, sizeof(buf), "%d", value);

        lseek(dev->fd, 0, SEEK_SET);
        ftruncate(dev->fd, 0);
        write(dev->fd, buf, len);
        lseek(dev->fd, 0, SEEK_SET);
    }
}

void mock_atomic_get_stats(mock_atomic_dev_t* dev, int* open_count,
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

void mock_atomic_reset_stats(mock_atomic_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}
