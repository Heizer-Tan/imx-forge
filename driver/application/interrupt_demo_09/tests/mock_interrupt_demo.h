/**
 * @file mock_interrupt_demo.h
 * @brief Mock interrupt demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_INTERRUPT_DEMO_H
#define MOCK_INTERRUPT_DEMO_H

typedef struct mock_interrupt_dev {
    int fd;
    char temp_path[256];
    int press_count;
    int release_count;
    int open_count;
    int read_count;
} mock_interrupt_dev_t;

mock_interrupt_dev_t* mock_interrupt_create(void);
void mock_interrupt_destroy(mock_interrupt_dev_t* dev);
int mock_interrupt_get_fd(mock_interrupt_dev_t* dev);
const char* mock_interrupt_get_path(mock_interrupt_dev_t* dev);
int mock_interrupt_get_press_count(mock_interrupt_dev_t* dev);
int mock_interrupt_get_release_count(mock_interrupt_dev_t* dev);
void mock_interrupt_get_stats(mock_interrupt_dev_t* dev, int* open_count,
                               int* read_count);
void mock_interrupt_reset_stats(mock_interrupt_dev_t* dev);

#endif // MOCK_INTERRUPT_DEMO_H
