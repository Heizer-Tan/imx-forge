/**
 * @file mock_spinlock_demo.h
 * @brief Mock spinlock demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_SPINLOCK_DEMO_H
#define MOCK_SPINLOCK_DEMO_H

/**
 * @brief Mock spinlock device handle
 */
typedef struct mock_spinlock_dev {
    int fd;                 // File descriptor for the mock device
    char temp_path[256];    // Path to temporary file
    int protected_counter;  // Current protected counter value
    int unprotected_counter; // Current unprotected counter value
    int open_count;         // Number of times opened
    int write_count;        // Number of writes performed
    int read_count;         // Number of reads performed
} mock_spinlock_dev_t;

/**
 * @brief Create a mock spinlock character device
 * @return Pointer to mock device, or NULL on failure
 */
mock_spinlock_dev_t* mock_spinlock_create(void);

/**
 * @brief Destroy a mock spinlock character device
 * @param dev Mock device to destroy
 */
void mock_spinlock_destroy(mock_spinlock_dev_t* dev);

/**
 * @brief Get the file descriptor for the mock device
 * @param dev Mock device
 * @return File descriptor, or -1 if invalid
 */
int mock_spinlock_get_fd(mock_spinlock_dev_t* dev);

/**
 * @brief Get the path to the mock device file
 * @param dev Mock device
 * @return Path string, or NULL if invalid
 */
const char* mock_spinlock_get_path(mock_spinlock_dev_t* dev);

/**
 * @brief Get the current protected counter value
 * @param dev Mock device
 * @return Current protected counter value
 */
int mock_spinlock_get_protected_counter(mock_spinlock_dev_t* dev);

/**
 * @brief Get the current unprotected counter value
 * @param dev Mock device
 * @return Current unprotected counter value
 */
int mock_spinlock_get_unprotected_counter(mock_spinlock_dev_t* dev);

/**
 * @brief Get statistics about mock device operations
 * @param dev Mock device
 * @param open_count Output: number of opens (can be NULL)
 * @param write_count Output: number of writes (can be NULL)
 * @param read_count Output: number of reads (can be NULL)
 */
void mock_spinlock_get_stats(mock_spinlock_dev_t* dev, int* open_count,
                              int* write_count, int* read_count);

/**
 * @brief Reset mock device statistics
 * @param dev Mock device
 */
void mock_spinlock_reset_stats(mock_spinlock_dev_t* dev);

#endif // MOCK_SPINLOCK_DEMO_H
