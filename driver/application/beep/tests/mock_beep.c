/**
 * @file mock_beep.c
 * @brief Mock beep device implementation for testing beep application
 * @date 2026-05-06
 */

#include "mock_beep.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

mock_beep_dev_t* mock_beep_create(void) {
    mock_beep_dev_t* dev = calloc(1, sizeof(mock_beep_dev_t));
    if (!dev) {
        return NULL;
    }

    snprintf(dev->temp_path, sizeof(dev->temp_path), "/tmp/mock_beep_%d", getpid());

    dev->fd = open(dev->temp_path, O_RDWR | O_CREAT, 0666);
    if (dev->fd < 0) {
        free(dev);
        return NULL;
    }

    dev->beep_state = false;
    write(dev->fd, "1", 1);
    lseek(dev->fd, 0, SEEK_SET);

    dev->open_count = 1;
    dev->write_count = 0;
    dev->read_count = 0;

    return dev;
}

void mock_beep_destroy(mock_beep_dev_t* dev) {
    if (!dev) {
        return;
    }

    if (dev->fd >= 0) {
        close(dev->fd);
    }

    unlink(dev->temp_path);

    free(dev);
}

int mock_beep_get_fd(mock_beep_dev_t* dev) {
    return dev ? dev->fd : -1;
}

const char* mock_beep_get_path(mock_beep_dev_t* dev) {
    return dev ? dev->temp_path : NULL;
}

bool mock_beep_get_state(mock_beep_dev_t* dev) {
    return dev ? dev->beep_state : false;
}

void mock_beep_get_stats(mock_beep_dev_t* dev, int* open_count, int* write_count, int* read_count) {
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

void mock_beep_reset_stats(mock_beep_dev_t* dev) {
    if (!dev) {
        return;
    }

    dev->open_count = 0;
    dev->write_count = 0;
    dev->read_count = 0;
}