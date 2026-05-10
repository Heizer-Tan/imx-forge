/**
 * @file mock_mutex_demo.h
 * @brief Mock mutex demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_MUTEX_DEMO_H
#define MOCK_MUTEX_DEMO_H

/**
 * @brief Mock mutex device handle
 */
typedef struct mock_mutex_dev {
    int fd;                 // File descriptor for the mock device
    char temp_path[256];    // Path to temporary file
    int shared_data;        // Current shared data value
    int open_count;         // Number of times opened
    int write_count;        // Number of writes performed
    int read_count;         // Number of reads performed
} mock_mutex_dev_t;

/**
 * @brief Create a mock mutex character device
 * @return Pointer to mock device, or NULL on failure
 */
mock_mutex_dev_t* mock_mutex_create(void);

/**
 * @brief Destroy a mock mutex character device
 * @param dev Mock device to destroy
 */
void mock_mutex_destroy(mock_mutex_dev_t* dev);

/**
 * @brief Get the file descriptor for the mock device
 * @param dev Mock device
 * @return File descriptor, or -1 if invalid
 */
int mock_mutex_get_fd(mock_mutex_dev_t* dev);

/**
 * @brief Get the path to the mock device file
 * @param dev Mock device
 * @return Path string, or NULL if invalid
 */
const char* mock_mutex_get_path(mock_mutex_dev_t* dev);

/**
 * @brief Get the current shared data value
 * @param dev Mock device
 * @return Current shared data value
 */
int mock_mutex_get_shared_data(mock_mutex_dev_t* dev);

/**
 * @brief Set the shared data value (simulates device behavior)
 * @param dev Mock device
 * @param value New shared data value
 */
void mock_mutex_set_shared_data(mock_mutex_dev_t* dev, int value);

/**
 * @brief Get statistics about mock device operations
 * @param dev Mock device
 * @param open_count Output: number of opens (can be NULL)
 * @param write_count Output: number of writes (can be NULL)
 * @param read_count Output: number of reads (can be NULL)
 */
void mock_mutex_get_stats(mock_mutex_dev_t* dev, int* open_count,
                          int* write_count, int* read_count);

/**
 * @brief Reset mock device statistics
 * @param dev Mock device
 */
void mock_mutex_reset_stats(mock_mutex_dev_t* dev);

#endif // MOCK_MUTEX_DEMO_H
