/**
 * @file mock_timer_demo.h
 * @brief Mock timer demo device for testing
 * @date 2026-05-10
 */

#ifndef MOCK_TIMER_DEMO_H
#define MOCK_TIMER_DEMO_H

typedef struct mock_timer_dev {
    int fd;
    char temp_path[256];
    int running;
    int tick_count;
    int open_count;
    int write_count;
    int read_count;
} mock_timer_dev_t;

mock_timer_dev_t* mock_timer_create(void);
void mock_timer_destroy(mock_timer_dev_t* dev);
int mock_timer_get_fd(mock_timer_dev_t* dev);
const char* mock_timer_get_path(mock_timer_dev_t* dev);
int mock_timer_get_tick_count(mock_timer_dev_t* dev);
int mock_timer_is_running(mock_timer_dev_t* dev);
void mock_timer_set_running(mock_timer_dev_t* dev, int running);
void mock_timer_get_stats(mock_timer_dev_t* dev, int* open_count,
                          int* write_count, int* read_count);
void mock_timer_reset_stats(mock_timer_dev_t* dev);

#endif // MOCK_TIMER_DEMO_H
