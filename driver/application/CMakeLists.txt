# Top-level CMakeLists.txt for driver applications
# Default: ARM cross-compilation for i.MX6ULL
# Use -DHOST_TEST=ON for native x86 builds (testing only)

cmake_minimum_required(VERSION 3.16)

# Enable testing (must be before project() or in subdirectories)
enable_testing()

# ================================================================
# Build Options
# ================================================================
option(HOST_TEST "Build for native x86 (host testing) instead of ARM cross-compile" OFF)
option(BUILD_SHARED_LIBS "Build shared libraries instead of static" OFF)
option(BUILD_TESTING "Build test programs" ON)
option(ENABLE_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)

# Selective build option (e.g., BUILD_APPS=led_control,motor_control)
set(BUILD_APPS "" CACHE STRING "Comma-separated list of apps to build (empty = all)")

# ================================================================
# Toolchain Configuration
# ================================================================
if(NOT HOST_TEST)
    # ARM cross-compilation (default)
    set(TOOLCHAIN_PREFIX arm-none-linux-gnueabihf-)

    # Find compilers in PATH
    find_program(CMAKE_C_COMPILER NAMES ${TOOLCHAIN_PREFIX}gcc)
    find_program(CMAKE_CXX_COMPILER NAMES ${TOOLCHAIN_PREFIX}g++)

    if(NOT CMAKE_C_COMPILER)
        message(FATAL_ERROR "ARM toolchain not found! Please ensure arm-none-linux-gnueabihf-gcc is in PATH.")
    endif()

    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_PROCESSOR arm)
    set(CMAKE_CROSSCOMPILING TRUE)

    # ARM Cortex-A7 specific flags
    set(CPU_FLAGS "-march=armv7-a -mtune=cortex-a7 -mfloat-abi=hard -mfpu=neon")
    set(CMAKE_C_FLAGS "${CPU_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CPU_FLAGS}")

    # Find root paths settings
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

    message(STATUS "ARM cross-compilation mode (default)")
    message(STATUS "  Compiler: ${CMAKE_C_COMPILER}")
else()
    # Native build for testing
    message(STATUS "Native build mode (HOST_TEST=ON, for testing only)")
endif()

# ================================================================
# Project Information
# ================================================================
project(driver_applications
    VERSION 1.0.0
    DESCRIPTION "i.MX6ULL driver applications"
    LANGUAGES C CXX
)

# ================================================================
# Output Directory Configuration
# ================================================================
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# ================================================================
# Common Compiler Flags
# ================================================================
if(HOST_TEST)
    # Native build flags
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(-Wall -Wextra)
    endif()
endif()

# ================================================================
# Application Subdirectories
# ================================================================
# Collect all application targets for install rules
set(ALL_APP_TARGETS "")

# Function to add an application subdirectory
function(add_app_subdirectory subdir)
    # Check if BUILD_APPS is specified and this app is not in the list
    if(BUILD_APPS)
        string(REPLACE "," ";" BUILD_APPS_LIST "${BUILD_APPS}")
        set(FOUND FALSE)
        foreach(app_name ${BUILD_APPS_LIST})
            string(STRIP "${app_name}" app_name)
            if("${subdir}" STREQUAL "${app_name}" OR
               "${subdir}" MATCHES "^${app_name}$")
                set(FOUND TRUE)
                break()
            endif()
        endforeach()
        if(NOT FOUND)
            return()
        endif()
    endif()

    add_subdirectory(${subdir})
    message(STATUS "Added application: ${subdir}")
endfunction()

# Function to collect all executable targets
function(collect_app_targets)
    # Use BUILDSYSTEM_TARGETS to get only targets created by this project
    get_cmake_property(all_targets BUILDSYSTEM_TARGETS)
    foreach(target ${all_targets})
        if(TARGET ${target})
            get_target_property(target_type ${target} TYPE)
            if("${target_type}" STREQUAL "EXECUTABLE")
                list(APPEND ALL_APP_TARGETS ${target})
            endif()
        endif()
    endforeach()
    set(ALL_APP_TARGETS "${ALL_APP_TARGETS}" PARENT_SCOPE)
endfunction()

# Automatically discover and add subdirectories with CMakeLists.txt
file(GLOB subdirs RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*")
foreach(subdir ${subdirs})
    if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${subdir} AND
       EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/CMakeLists.txt AND
       NOT ${subdir} MATCHES "^(cmake|build|build-.*|include|common|test)$")
        add_app_subdirectory(${subdir})
    endif()
endforeach()

# Collect all executable targets for install rules
collect_app_targets()

# ================================================================
# Install Rules
# ================================================================
install(DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
    DESTINATION usr/local/bin
    FILES_MATCHING PATTERN "*"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
                GROUP_EXECUTE GROUP_READ
                WORLD_EXECUTE WORLD_READ
)

# ================================================================
# Summary
# ================================================================
message(STATUS "")
message(STATUS "==============================================")
message(STATUS "Driver Applications Configuration Summary")
message(STATUS "==============================================")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Build mode: ${HOST_TEST}")
if(HOST_TEST)
    message(STATUS "  -> Native x86 (for testing)")
else()
    message(STATUS "  -> ARM cross-compile (i.MX6ULL)")
    message(STATUS "  -> Compiler: ${CMAKE_C_COMPILER}")
endif()
if(BUILD_APPS)
    message(STATUS "Build apps: ${BUILD_APPS}")
else()
    message(STATUS "Build apps: all")
endif()
message(STATUS "Output directory: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
message(STATUS "==============================================")
message(STATUS "")
