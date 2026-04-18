/**
 * @file mock_chardev.h
 * @brief Mock character device for testing LED control application
 * @date 2026-04-18
 */

#ifndef MOCK_CHARDEV_H
#define MOCK_CHARDEV_H

#include <stddef.h>
#include <stdbool.h>

/**
 * @brief Mock LED device handle
 */
typedef struct mock_led_dev {
    int fd;                 /**< File descriptor for the mock device */
    char temp_path[256];    /**< Path to temporary file */
    bool led_state;         /**< Current LED state (true=on, false=off) */
    int open_count;         /**< Number of times opened */
    int write_count;        /**< Number of writes performed */
    int read_count;         /**< Number of reads performed */
} mock_led_dev_t;

/**
 * @brief Create a mock LED character device
 * @return Pointer to mock device, or NULL on failure
 */
mock_led_dev_t* mock_led_create(void);

/**
 * @brief Destroy a mock LED character device
 * @param dev Mock device to destroy
 */
void mock_led_destroy(mock_led_dev_t* dev);

/**
 * @brief Get the file descriptor for the mock device
 * @param dev Mock device
 * @return File descriptor, or -1 if invalid
 */
int mock_led_get_fd(mock_led_dev_t* dev);

/**
 * @brief Get the path to the mock device file
 * @param dev Mock device
 * @return Path string, or NULL if invalid
 */
const char* mock_led_get_path(mock_led_dev_t* dev);

/**
 * @brief Get the current LED state
 * @param dev Mock device
 * @return true if LED is on, false if off
 */
bool mock_led_get_state(mock_led_dev_t* dev);

/**
 * @brief Get statistics about mock device operations
 * @param dev Mock device
 * @param open_count Output: number of opens (can be NULL)
 * @param write_count Output: number of writes (can be NULL)
 * @param read_count Output: number of reads (can be NULL)
 */
void mock_led_get_stats(mock_led_dev_t* dev, int* open_count, int* write_count, int* read_count);

/**
 * @brief Reset mock device statistics
 * @param dev Mock device
 */
void mock_led_reset_stats(mock_led_dev_t* dev);

#endif /* MOCK_CHARDEV_H */
