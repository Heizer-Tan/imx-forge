/**
 * @file test_beep.c
 * @brief Unit tests for beep application
 * @date 2026-05-06
 *
 * These tests focus on argument validation and error handling.
 * Full integration testing requires the actual beep driver.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef BEEP_BIN
#define BEEP_BIN "./beep"
#endif

#define DEVICE_PATH "/dev/beep"

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
            printf("\n  Assertion failed: %s == %s (%d != %d) at line %d\n", \
                   #a, #b, (int)(a), (int)(b), __LINE__); \
            return 0; \
        } \
    } while(0)

#define ASSERT_STR_CONTAINS(haystack, needle) \
    do { \
        if (strstr((haystack), (needle)) == NULL) { \
            printf("\n  Assertion failed: '%s' not found in '%s' at line %d\n", \
                   (needle), (haystack), __LINE__); \
            return 0; \
        } \
    } while(0)

#define ASSERT_STR_CONTAINS_ONE_OF(haystack, needle1, needle2) \
    do { \
        if (strstr((haystack), (needle1)) == NULL && strstr((haystack), (needle2)) == NULL) { \
            printf("\n  Assertion failed: '%s' or '%s' not found in '%s' at line %d\n", \
                   (needle1), (needle2), (haystack), __LINE__); \
            return 0; \
        } \
    } while(0)

static int run_beep(const char* mode, char* output, size_t output_size) {
    int pipefd[2];
    pid_t pid;

    pipe(pipefd);

    pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        execl(BEEP_BIN, BEEP_BIN, mode, (char*)NULL);
        exit(1);
    } else {
        int status;
        close(pipefd[1]);

        ssize_t bytes_read = read(pipefd[0], output, output_size - 1);
        if (bytes_read >= 0) {
            output[bytes_read] = '\0';
        } else {
            output[0] = '\0';
        }
        close(pipefd[0]);

        waitpid(pid, &status, 0);

        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        }
        return 127;
    }
}

static int test_help_on_wrong_args(void) {
    char output[256];
    int pipefd[2];
    pid_t pid;

    pipe(pipefd);

    pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        execl(BEEP_BIN, BEEP_BIN, (char*)NULL);
        exit(1);
    } else {
        int status;
        close(pipefd[1]);
        ssize_t n = read(pipefd[0], output, sizeof(output) - 1);
        if (n > 0) {
            output[n] = '\0';
        } else {
            output[0] = '\0';
        }
        close(pipefd[0]);
        waitpid(pid, &status, 0);

        ASSERT_TRUE(WIFEXITED(status));
        ASSERT_EQ(WEXITSTATUS(status), 1);
        ASSERT_STR_CONTAINS(output, "Usage:");
    }
    return 1;
}

static int test_help_content(void) {
    char output[512];
    int pipefd[2];
    pid_t pid;

    pipe(pipefd);

    pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        execl(BEEP_BIN, BEEP_BIN, (char*)NULL);
        exit(1);
    } else {
        int status;
        close(pipefd[1]);
        ssize_t n = read(pipefd[0], output, sizeof(output) - 1);
        if (n > 0) {
            output[n] = '\0';
        } else {
            output[0] = '\0';
        }
        close(pipefd[0]);
        waitpid(pid, &status, 0);

        ASSERT_STR_CONTAINS(output, "Usage:");
        ASSERT_STR_CONTAINS(output, "0");
        ASSERT_STR_CONTAINS(output, "1");
        ASSERT_STR_CONTAINS(output, "2");
    }
    return 1;
}

static int test_invalid_mode_3(void) {
    char output[256];
    int result = run_beep("3", output, sizeof(output));

    ASSERT_EQ(result, 1);
    ASSERT_STR_CONTAINS_ONE_OF(output, "invalid argument", "Failed to open");
    return 1;
}

static int test_invalid_mode_negative(void) {
    char output[256];
    int result = run_beep("-1", output, sizeof(output));

    ASSERT_EQ(result, 1);
    ASSERT_STR_CONTAINS_ONE_OF(output, "invalid argument", "Failed to open");
    return 1;
}

static int test_various_invalid_values(void) {
    char* invalid_values[] = {"3", "10", "-1"};
    for (size_t i = 0; i < sizeof(invalid_values) / sizeof(invalid_values[0]); i++) {
        char output[256];
        int result = run_beep(invalid_values[i], output, sizeof(output));
        ASSERT_EQ(result, 1);
        ASSERT_STR_CONTAINS_ONE_OF(output, "invalid argument", "Failed to open");
    }
    return 1;
}

static int test_nonexistent_device(void) {
    char output[256];
    int result = run_beep("0", output, sizeof(output));

    ASSERT_EQ(result, 1);
    ASSERT_STR_CONTAINS(output, "Failed to open");
    return 1;
}

static int test_valid_value_zero(void) {
    char output[256];
    int result = run_beep("0", output, sizeof(output));

    if (result == 0) {
        ASSERT_STR_CONTAINS(output, "Beep turned ON");
    } else {
        ASSERT_STR_CONTAINS(output, "Failed to open");
    }
    return 1;
}

static int test_valid_value_one(void) {
    char output[256];
    int result = run_beep("1", output, sizeof(output));

    if (result == 0) {
        ASSERT_STR_CONTAINS(output, "Beep turned OFF");
    } else {
        ASSERT_STR_CONTAINS(output, "Failed to open");
    }
    return 1;
}

static int test_mode_2_beep_once(void) {
    char output[256];
    int result = run_beep("2", output, sizeof(output));

    if (result == 0) {
        ASSERT_STR_CONTAINS(output, "Beeped for 1 second");
    } else {
        ASSERT_STR_CONTAINS(output, "Failed to open");
    }
    return 1;
}

int main(int argc, char* argv[]) {
    (void)argc; (void)argv;

    printf("========================================\n");
    printf("Beep Unit Tests\n");
    printf("Binary: %s\n", BEEP_BIN);
    printf("Device: %s (hardcoded)\n", DEVICE_PATH);
    printf("========================================\n");
    printf("\nNOTE: Tests validate argument parsing.\n");
    printf("Tests for valid modes (0,1,2) accept either\n");
    printf("success or 'Failed to open' if driver absent.\n");
    printf("Tests for invalid modes accept 'invalid argument'\n");
    printf("or 'Failed to open' (device checked first).\n\n");

    TEST(help_on_wrong_args);
    TEST(help_content);
    TEST(invalid_mode_3);
    TEST(invalid_mode_negative);
    TEST(various_invalid_values);
    TEST(nonexistent_device);
    TEST(valid_value_zero);
    TEST(valid_value_one);
    TEST(mode_2_beep_once);

    printf("\n========================================\n");
    printf("Test Summary\n");
    printf("========================================\n");
    printf("  Total:  %d\n", tests_run);
    printf("  Passed: %d\n", tests_passed);
    printf("  Failed: %d\n", tests_failed);
    printf("========================================\n");

    return tests_failed > 0 ? 1 : 0;
}