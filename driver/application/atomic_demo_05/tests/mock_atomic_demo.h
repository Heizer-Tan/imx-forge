/**
 * @file mock_atomic_demo.h
 * @brief Mock atomic demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_ATOMIC_DEMO_H
#define MOCK_ATOMIC_DEMO_H

/**
 * @brief Mock atomic device handle
 */
typedef struct mock_atomic_dev {
    int fd;                 // File descriptor for the mock device
    char temp_path[256];    // Path to temporary file
    int counter;            // Current counter value
    int open_count;         // Number of times opened
    int write_count;        // Number of writes performed
    int read_count;         // Number of reads performed
} mock_atomic_dev_t;

/**
 * @brief Create a mock atomic character device
 * @return Pointer to mock device, or NULL on failure
 */
mock_atomic_dev_t* mock_atomic_create(void);

/**
 * @brief Destroy a mock atomic character device
 * @param dev Mock device to destroy
 */
void mock_atomic_destroy(mock_atomic_dev_t* dev);

/**
 * @brief Get the file descriptor for the mock device
 * @param dev Mock device
 * @return File descriptor, or -1 if invalid
 */
int mock_atomic_get_fd(mock_atomic_dev_t* dev);

/**
 * @brief Get the path to the mock device file
 * @param dev Mock device
 * @return Path string, or NULL if invalid
 */
const char* mock_atomic_get_path(mock_atomic_dev_t* dev);

/**
 * @brief Get the current counter value
 * @param dev Mock device
 * @return Current counter value
 */
int mock_atomic_get_counter(mock_atomic_dev_t* dev);

/**
 * @brief Set the counter value (simulates device behavior)
 * @param dev Mock device
 * @param value New counter value
 */
void mock_atomic_set_counter(mock_atomic_dev_t* dev, int value);

/**
 * @brief Get statistics about mock device operations
 * @param dev Mock device
 * @param open_count Output: number of opens (can be NULL)
 * @param write_count Output: number of writes (can be NULL)
 * @param read_count Output: number of reads (can be NULL)
 */
void mock_atomic_get_stats(mock_atomic_dev_t* dev, int* open_count,
                           int* write_count, int* read_count);

/**
 * @brief Reset mock device statistics
 * @param dev Mock device
 */
void mock_atomic_reset_stats(mock_atomic_dev_t* dev);

#endif // MOCK_ATOMIC_DEMO_H
