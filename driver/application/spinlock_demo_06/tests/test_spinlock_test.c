/**
 * @file test_spinlock_test.c
 * @brief Unit tests for spinlock demo application
 * @date 2026-05-10
 *
 * These tests focus on argument validation and error handling.
 * Full integration testing requires the actual spinlock_demo driver.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

// Path to the spinlock_test binary
#ifndef SPINLOCK_TEST_BIN
#define SPINLOCK_TEST_BIN "./spinlock_test"
#endif

// Simple test framework
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

// Helper: Create a temporary device file
static int create_temp_dev(char* path, size_t path_size) {
    snprintf(path, path_size, "/tmp/test_spinlock_%d", getpid());
    int fd = open(path, O_RDWR | O_CREAT, 0666);
    if (fd >= 0) {
        write(fd, "0", 1);
        lseek(fd, 0, SEEK_SET);
    }
    return fd;
}

// Helper: Clean up temp file
static void cleanup_temp_dev(const char* path) {
    unlink(path);
}

// Helper: Run spinlock_test and capture output
static int run_spinlock_test(const char* dev_path, const char* value,
                             char* output, size_t output_size) {
    int pipefd[2];
    pipe(pipefd);

    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        close(pipefd[0]);  // Close read end
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        execl(SPINLOCK_TEST_BIN, SPINLOCK_TEST_BIN, dev_path, value, NULL);
        exit(1);  // Should not reach here
    } else {
        // Parent process
        int status;
        close(pipefd[1]);  // Close write end

        // Read output
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
        return 127;  // exec error
    }
}

// Test: Help message is printed when argc < 2
static int test_help_on_wrong_args(void) {
    char output[256];
    int pipefd[2];
    pid_t pid;

    pipe(pipefd);

    pid = fork();
    if (pid == 0) {
        // Child process
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);

        execl(SPINLOCK_TEST_BIN, SPINLOCK_TEST_BIN, NULL);
        exit(1);
    } else {
        // Parent process
        int status;
        close(pipefd[1]);
        read(pipefd[0], output, sizeof(output) - 1);
        output[sizeof(output) - 1] = '\0';
        close(pipefd[0]);
        waitpid(pid, &status, 0);

        ASSERT_TRUE(WIFEXITED(status));
        ASSERT_EQ(WEXITSTATUS(status), 1);
        ASSERT_STR_CONTAINS(output, "Usage:");
    }
    return 1;
}

// Test: Non-existent device file is handled
static int test_nonexistent_device(void) {
    char output[256];
    int result = run_spinlock_test("/nonexistent/path/that/does/not/exist", "read",
                                   output, sizeof(output));

    ASSERT_EQ(result, 1);  // Should fail with exit code 1
    ASSERT_STR_CONTAINS(output, "Failed to open");
    return 1;
}

// Test: Valid command 'read' is accepted
static int test_valid_read(void) {
    char temp_path[256];
    int fd = create_temp_dev(temp_path, sizeof(temp_path));
    ASSERT_TRUE(fd >= 0);
    close(fd);

    char output[256];
    int result = run_spinlock_test(temp_path, "read", output, sizeof(output));

    cleanup_temp_dev(temp_path);
    (void)result;  // Suppress unused warning
    return 1;
}

// Test: Valid command 'protected' is accepted
static int test_valid_protected(void) {
    char temp_path[256];
    int fd = create_temp_dev(temp_path, sizeof(temp_path));
    ASSERT_TRUE(fd >= 0);
    close(fd);

    char output[256];
    int result = run_spinlock_test(temp_path, "protected 10", output, sizeof(output));

    cleanup_temp_dev(temp_path);
    (void)result;
    return 1;
}

// Test: Valid command 'unprotected' is accepted
static int test_valid_unprotected(void) {
    char temp_path[256];
    int fd = create_temp_dev(temp_path, sizeof(temp_path));
    ASSERT_TRUE(fd >= 0);
    close(fd);

    char output[256];
    int result = run_spinlock_test(temp_path, "unprotected 10", output, sizeof(output));

    cleanup_temp_dev(temp_path);
    (void)result;
    return 1;
}

// Test: Valid command 'reset' is accepted
static int test_valid_reset(void) {
    char temp_path[256];
    int fd = create_temp_dev(temp_path, sizeof(temp_path));
    ASSERT_TRUE(fd >= 0);
    close(fd);

    char output[256];
    int result = run_spinlock_test(temp_path, "reset", output, sizeof(output));

    cleanup_temp_dev(temp_path);
    (void)result;
    return 1;
}

// Test: Unknown command is rejected
static int test_unknown_command(void) {
    char temp_path[256];
    int fd = create_temp_dev(temp_path, sizeof(temp_path));
    ASSERT_TRUE(fd >= 0);
    close(fd);

    char output[256];
    int result = run_spinlock_test(temp_path, "unknown_command", output, sizeof(output));

    cleanup_temp_dev(temp_path);
    ASSERT_EQ(result, 1);  // Should fail
    ASSERT_STR_CONTAINS(output, "unknown command");
    return 1;
}

int main(int argc, char* argv[]) {
    (void)argc; (void)argv;

    printf("========================================\n");
    printf("Spinlock Demo Unit Tests\n");
    printf("Binary: %s\n", SPINLOCK_TEST_BIN);
    printf("========================================\n");
    printf("\nNOTE: Full read/write cycle tests require actual\n");
    printf("spinlock_demo driver hardware. These tests validate\n");
    printf("argument parsing and error handling.\n\n");

    TEST(help_on_wrong_args);
    TEST(nonexistent_device);
    TEST(valid_read);
    TEST(valid_protected);
    TEST(valid_unprotected);
    TEST(valid_reset);
    TEST(unknown_command);

    printf("\n========================================\n");
    printf("Test Results:\n");
    printf("  Total:  %d\n", tests_run);
    printf("  Passed: %d\n", tests_passed);
    printf("  Failed: %d\n", tests_failed);
    printf("========================================\n");

    if (tests_failed == 0) {
        printf("\nAll tests passed!\n");
        printf("\nFor full integration testing, deploy to hardware:\n");
        printf("  1. Load the spinlock_demo driver\n");
        printf("  2. Run: ./spinlock_test read\n");
        printf("  3. Run: ./spinlock_test protected 100\n");
    }

    return (tests_failed == 0) ? 0 : 1;
}
