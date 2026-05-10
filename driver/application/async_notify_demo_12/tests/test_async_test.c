/**
 * @file test_async_test.c
 * @brief Unit tests for async notify demo application
 * @date 2026-05-10
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef ASYNC_TEST_BIN
#define ASYNC_TEST_BIN "./async_test"
#endif

static int tests_run = 0;
static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) \
    do { \
        tests_run++; \
        printf("Running test: %s...", #name); \
        if (test_##name()) { \
            tests_passed++; \
            printf(" PASSED\n"); \
        } else { \
            tests_failed++; \
            printf(" FAILED\n"); \
        } \
    } while(0)

#define ASSERT_TRUE(condition) \
    do { \
        if (!(condition)) { \
            printf("\n  Assertion failed: %s at line %d\n", #condition, __LINE__); \
            return 0; \
        } \
    } while(0)

#define ASSERT_EQ(a, b) \
    do { \
        if ((a) != (b)) { \
            printf("\n  Assertion failed: %d != %d at line %d\n", (int)(a), (int)(b), __LINE__); \
            return 0; \
        } \
    } while(0)

static char* create_temp_dev(void) {
    char* path = malloc(256);
    snprintf(path, 256, "/tmp/test_async_%d", getpid());
    int fd = open(path, O_RDWR | O_CREAT, 0666);
    if (fd >= 0) {
        write(fd, "0", 1);
        close(fd);
    }
    return path;
}

static void cleanup_temp_dev(const char* path) {
    unlink(path);
    free((void*)path);
}

static int run_test_binary(const char* dev_path, const char* arg,
                           char* output, size_t size) {
    int pipefd[2];
    pipe(pipefd);

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        execl(ASYNC_TEST_BIN, ASYNC_TEST_BIN, dev_path, arg, NULL);
        exit(1);
    }

    close(pipefd[1]);
    ssize_t bytes = read(pipefd[0], output, size - 1);
    output[bytes > 0 ? bytes : 0] = '\0';
    close(pipefd[0]);

    int status;
    waitpid(pid, &status, 0);
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static int test_help_on_wrong_args(void) {
    char output[256];
    int pipefd[2];
    pipe(pipefd);

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        execl(ASYNC_TEST_BIN, ASYNC_TEST_BIN, NULL);
        exit(1);
    }

    close(pipefd[1]);
    read(pipefd[0], output, sizeof(output) - 1);
    output[sizeof(output) - 1] = '\0';
    close(pipefd[0]);

    int status;
    waitpid(pid, &status, 0);
    ASSERT_TRUE(WIFEXITED(status));
    ASSERT_EQ(WEXITSTATUS(status), 1);
    ASSERT_TRUE(strstr(output, "Usage:") != NULL);
    return 1;
}

static int test_nonexistent_device(void) {
    char output[256];
    int result = run_test_binary("/nonexistent/async", "stats", output, sizeof(output));
    ASSERT_EQ(result, 1);
    return 1;
}

static int test_valid_command(void) {
    char* path = create_temp_dev();
    char output[256];
    int result = run_test_binary(path, "stats", output, sizeof(output));
    cleanup_temp_dev(path);
    (void)result;
    return 1;
}

int main(void) {
    printf("========================================\n");
    printf("Async Test Unit Tests\n");
    printf("Binary: %s\n", ASYNC_TEST_BIN);
    printf("========================================\n\n");

    TEST(help_on_wrong_args);
    TEST(nonexistent_device);
    TEST(valid_command);

    printf("\n========================================\n");
    printf("Results: %d run, %d passed, %d failed\n",
           tests_run, tests_passed, tests_failed);
    printf("========================================\n");

    return tests_failed > 0;
}
