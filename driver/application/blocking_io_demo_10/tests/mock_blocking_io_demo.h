/**
 * @file mock_blocking_io_demo.h
 * @brief Mock blocking I/O demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_BLOCKING_IO_DEMO_H
#define MOCK_BLOCKING_IO_DEMO_H

typedef struct mock_blocking_io_dev {
    int fd;
    char temp_path[256];
    char buffer[16];
    int head;
    int tail;
    int count;
    int open_count;
    int write_count;
    int read_count;
} mock_blocking_io_dev_t;

mock_blocking_io_dev_t* mock_blocking_io_create(void);
void mock_blocking_io_destroy(mock_blocking_io_dev_t* dev);
int mock_blocking_io_get_fd(mock_blocking_io_dev_t* dev);
const char* mock_blocking_io_get_path(mock_blocking_io_dev_t* dev);
int mock_blocking_io_get_buffer_count(mock_blocking_io_dev_t* dev);
void mock_blocking_io_get_stats(mock_blocking_io_dev_t* dev, int* open_count,
                                 int* write_count, int* read_count);
void mock_blocking_io_reset_stats(mock_blocking_io_dev_t* dev);

#endif // MOCK_BLOCKING_IO_DEMO_H
