/**
 * @file mock_blocking_io_demo.c
 * @brief Mock blocking I/O demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_blocking_io_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_blocking_io_dev_t* mock_blocking_io_create(void) {
    mock_blocking_io_dev_t* dev = calloc(1, sizeof(mock_blocking_io_dev_t));
    if (!dev) {
        return NULL;
    }

    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/blocking_io_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    dev->head = 0;
    dev->tail = 0;
    dev->count = 0;
    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_blocking_io_destroy(mock_blocking_io_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    unlink(dev->temp_path);
    free(dev);
}

int mock_blocking_io_get_fd(mock_blocking_io_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_blocking_io_get_path(mock_blocking_io_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_blocking_io_get_buffer_count(mock_blocking_io_dev_t* dev) {
    return dev ? dev->count : 0;
}

void mock_blocking_io_get_stats(mock_blocking_io_dev_t* dev, int* open_count,
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

void mock_blocking_io_reset_stats(mock_blocking_io_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}
