/**
 * @file mock_beep.h
 * @brief Mock beep device for testing beep application
 * @date 2026-05-06
 */

#ifndef MOCK_BEEP_H
#define MOCK_BEEP_H

#include <stddef.h>
#include <stdbool.h>

/**
 * @brief Mock beep device handle
 */
typedef struct mock_beep_dev {
    int fd;
    char temp_path[256];
    bool beep_state;
    int open_count;
    int write_count;
    int read_count;
} mock_beep_dev_t;

mock_beep_dev_t* mock_beep_create(void);

void mock_beep_destroy(mock_beep_dev_t* dev);

int mock_beep_get_fd(mock_beep_dev_t* dev);

const char* mock_beep_get_path(mock_beep_dev_t* dev);

bool mock_beep_get_state(mock_beep_dev_t* dev);

void mock_beep_get_stats(mock_beep_dev_t* dev, int* open_count, int* write_count, int* read_count);

void mock_beep_reset_stats(mock_beep_dev_t* dev);

#endif /* MOCK_BEEP_H */