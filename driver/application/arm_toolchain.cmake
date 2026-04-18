# CMake Toolchain file for i.MX6ULL ARM cross-compilation
# Target: NXP i.MX6ULL (ARM Cortex-A7, ARMv7-A)
# Toolchain: Arm GNU Toolchain 15.2.rel1
#
# Usage:
#   mkdir build-arm && cd build-arm
#   cmake -DCMAKE_TOOLCHAIN_FILE=../arm_toolchain.cmake ..

# ================================================================
# Target System Specification
# ================================================================
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

# ================================================================
# Toolchain Configuration
# ================================================================
# Use toolchain from PATH (assumes arm-none-linux-gnueabihf-gcc is available)
set(TOOLCHAIN_PREFIX arm-none-linux-gnueabihf-)

# Find compilers in PATH (assumes user has configured PATH)
find_program(CMAKE_C_COMPILER NAMES ${TOOLCHAIN_PREFIX}gcc)
find_program(CMAKE_CXX_COMPILER NAMES ${TOOLCHAIN_PREFIX}g++)
find_program(CMAKE_AR NAMES ${TOOLCHAIN_PREFIX}ar)
find_program(CMAKE_STRIP NAMES ${TOOLCHAIN_PREFIX}strip)
find_program(CMAKE_RANLIB NAMES ${TOOLCHAIN_PREFIX}ranlib)
find_program(CMAKE_OBJCOPY NAMES ${TOOLCHAIN_PREFIX}objcopy)
find_program(CMAKE_SIZE NAMES ${TOOLCHAIN_PREFIX}size)

# Verify toolchain is found
if(NOT CMAKE_C_COMPILER)
    message(FATAL_ERROR "ARM toolchain not found! Please ensure arm-none-linux-gnueabihf-gcc is in PATH.")
endif()

# ================================================================
# Cross-Compilation Settings
# ================================================================
set(CMAKE_CROSSCOMPILING TRUE)

# ARM Cortex-A7 specific flags (optimized for i.MX6ULL)
set(CPU_FLAGS "-march=armv7-a -mtune=cortex-a7 -mfloat-abi=hard -mfpu=neon")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CPU_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CPU_FLAGS}")

# Optimization flags for embedded target
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2 -DNDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O2 -DNDEBUG")

# ================================================================
# Find Root Paths
# ================================================================
# Prevent CMake from searching in host system directories
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# Prefer Config files over Find modules for cross-compilation
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)

# ================================================================
# Build Output Settings
# ================================================================
# RPATH settings to avoid hardcoded paths
set(CMAKE_SKIP_RPATH TRUE)
set(CMAKE_SKIP_BUILD_RPATH TRUE)
