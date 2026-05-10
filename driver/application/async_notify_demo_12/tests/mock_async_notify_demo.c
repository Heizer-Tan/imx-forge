/**
 * @file mock_async_notify_demo.c
 * @brief Mock async notify demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_async_notify_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_async_notify_dev_t* mock_async_notify_create(void) {
    mock_async_notify_dev_t* dev = calloc(1, sizeof(mock_async_notify_dev_t));
    if (!dev) {
        return NULL;
    }

    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/async_notify_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    dev->button_state = 0;
    dev->press_count = 0;
    dev->release_count = 0;
    dev->notify_count = 0;
    dev->open_count = 1;
    dev->read_count = 0;

    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_async_notify_destroy(mock_async_notify_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    unlink(dev->temp_path);
    free(dev);
}

int mock_async_notify_get_fd(mock_async_notify_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_async_notify_get_path(mock_async_notify_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_async_notify_get_button_state(mock_async_notify_dev_t* dev) {
    return dev ? dev->button_state : 0;
}

void mock_async_notify_set_button_state(mock_async_notify_dev_t* dev, int state) {
    if (!dev) {
        return;
    }
    dev->button_state = state;
}

void mock_async_notify_get_stats(mock_async_notify_dev_t* dev, int* open_count,
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

void mock_async_notify_reset_stats(mock_async_notify_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->read_count = 0;
}
