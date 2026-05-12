/**
 * @file mock_async_notify_demo.h
 * @brief Mock async notify demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_ASYNC_NOTIFY_DEMO_H
#define MOCK_ASYNC_NOTIFY_DEMO_H

typedef struct mock_async_notify_dev {
    int fd;
    char temp_path[256];
    int button_state;
    int press_count;
    int release_count;
    int notify_count;
    int open_count;
    int read_count;
} mock_async_notify_dev_t;

mock_async_notify_dev_t* mock_async_notify_create(void);
void mock_async_notify_destroy(mock_async_notify_dev_t* dev);
int mock_async_notify_get_fd(mock_async_notify_dev_t* dev);
const char* mock_async_notify_get_path(mock_async_notify_dev_t* dev);
int mock_async_notify_get_button_state(mock_async_notify_dev_t* dev);
void mock_async_notify_set_button_state(mock_async_notify_dev_t* dev, int state);
void mock_async_notify_get_stats(mock_async_notify_dev_t* dev, int* open_count,
                                 int* read_count);
void mock_async_notify_reset_stats(mock_async_notify_dev_t* dev);

#endif // MOCK_ASYNC_NOTIFY_DEMO_H
