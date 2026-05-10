/**
 * @file mock_timer_demo.c
 * @brief Mock timer demo device implementation for testing
 * @date 2026-05-10
 */

#include "mock_timer_demo.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_timer_dev_t* mock_timer_create(void) {
    mock_timer_dev_t* dev = calloc(1, sizeof(mock_timer_dev_t));
    if (!dev) {
        return NULL;
    }

    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/timer_demo_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    dev->running = 0;
    dev->tick_count = 0;
    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    write(dev->fd, "0", 1);
    lseek(dev->fd, 0, SEEK_SET);

    return dev;
}

void mock_timer_destroy(mock_timer_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    unlink(dev->temp_path);
    free(dev);
}

int mock_timer_get_fd(mock_timer_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_timer_get_path(mock_timer_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

int mock_timer_get_tick_count(mock_timer_dev_t* dev) {
    return dev ? dev->tick_count : 0;
}

int mock_timer_is_running(mock_timer_dev_t* dev) {
    return dev ? dev->running : 0;
}

void mock_timer_set_running(mock_timer_dev_t* dev, int running) {
    if (!dev) {
        return;
    }
    dev->running = running;
}

void mock_timer_get_stats(mock_timer_dev_t* dev, int* open_count,
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

void mock_timer_reset_stats(mock_timer_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}
