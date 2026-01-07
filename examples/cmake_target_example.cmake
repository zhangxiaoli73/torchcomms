# CMake Modern Targets Example
# 
# This file demonstrates how to use modern CMake targets for common dependencies
# in the torchcomms project.

cmake_minimum_required(VERSION 3.22)
project(cmake_target_example)

# ============================================================================
# Step 1: Set up CMAKE_PREFIX_PATH to find packages
# ============================================================================

# Add CONDA_PREFIX to CMAKE_PREFIX_PATH if it's set
if(DEFINED ENV{CONDA_PREFIX})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
    message(STATUS "Added CONDA_PREFIX to CMAKE_PREFIX_PATH: $ENV{CONDA_PREFIX}")
endif()

# You can also manually add paths
# list(APPEND CMAKE_PREFIX_PATH "/path/to/custom/install")

# ============================================================================
# Step 2: Find packages using CONFIG mode
# ============================================================================

# Find glog with CONFIG mode (looks for glogConfig.cmake or glog-config.cmake)
find_package(glog CONFIG)
if(glog_FOUND)
    message(STATUS "Found glog using CONFIG mode")
    message(STATUS "  glog version: ${glog_VERSION}")
else()
    message(STATUS "glog not found using CONFIG mode, will use fallback")
endif()

# Find gflags with CONFIG mode
find_package(gflags CONFIG)
if(gflags_FOUND)
    message(STATUS "Found gflags using CONFIG mode")
    message(STATUS "  gflags version: ${gflags_VERSION}")
else()
    message(STATUS "gflags not found using CONFIG mode, will use fallback")
endif()

# Find fmt with CONFIG mode
find_package(fmt CONFIG)
if(fmt_FOUND)
    message(STATUS "Found fmt using CONFIG mode")
    message(STATUS "  fmt version: ${fmt_VERSION}")
else()
    message(STATUS "fmt not found using CONFIG mode, will use fallback")
endif()

# ============================================================================
# Step 3: Create a library target
# ============================================================================

# Example: Create a library that uses these dependencies
add_library(example_lib SHARED
    # Your source files here
    # example.cpp
)

target_compile_features(example_lib PRIVATE cxx_std_20)

# ============================================================================
# Step 4: Link dependencies using modern targets with fallback
# ============================================================================

# Method 1: Link glog
if(TARGET glog::glog)
    # Use the modern CMake target
    # This automatically adds include directories and link flags
    target_link_libraries(example_lib PRIVATE glog::glog)
    message(STATUS "Linking example_lib with glog::glog target")
else()
    # Fallback to traditional linking
    target_link_directories(example_lib PRIVATE ${CONDA_LIB})
    target_link_libraries(example_lib PRIVATE "-lglog")
    message(STATUS "Linking example_lib with -lglog (fallback)")
endif()

# Method 2: Link gflags
if(TARGET gflags::gflags)
    target_link_libraries(example_lib PRIVATE gflags::gflags)
    message(STATUS "Linking example_lib with gflags::gflags target")
else()
    target_link_directories(example_lib PRIVATE ${CONDA_LIB})
    target_link_libraries(example_lib PRIVATE "-lgflags")
    message(STATUS "Linking example_lib with -lgflags (fallback)")
endif()

# Method 3: Link fmt
if(TARGET fmt::fmt)
    target_link_libraries(example_lib PRIVATE fmt::fmt)
    message(STATUS "Linking example_lib with fmt::fmt target")
else()
    target_link_directories(example_lib PRIVATE ${CONDA_LIB})
    target_link_libraries(example_lib PRIVATE "-lfmt")
    message(STATUS "Linking example_lib with -lfmt (fallback)")
endif()

# ============================================================================
# Alternative: Using fmt header-only mode
# ============================================================================

# Some projects prefer to use fmt as header-only
if(TARGET fmt::fmt-header-only)
    # This is what RCCL uses
    target_link_libraries(example_lib PRIVATE fmt::fmt-header-only)
    message(STATUS "Using fmt::fmt-header-only target")
endif()

# ============================================================================
# Step 5: Print diagnostic information
# ============================================================================

# Helper function to check if a target exists and print its properties
function(print_target_info target_name)
    if(TARGET ${target_name})
        message(STATUS "Target ${target_name} exists:")
        
        # Try to get include directories
        get_target_property(inc_dirs ${target_name} INTERFACE_INCLUDE_DIRECTORIES)
        if(inc_dirs)
            message(STATUS "  Include directories: ${inc_dirs}")
        endif()
        
        # Try to get link libraries
        get_target_property(link_libs ${target_name} INTERFACE_LINK_LIBRARIES)
        if(link_libs)
            message(STATUS "  Link libraries: ${link_libs}")
        endif()
    else()
        message(STATUS "Target ${target_name} does not exist")
    endif()
endfunction()

# Print information about the targets
message(STATUS "")
message(STATUS "=== Target Information ===")
print_target_info(glog::glog)
print_target_info(gflags::gflags)
print_target_info(fmt::fmt)
print_target_info(fmt::fmt-header-only)

# ============================================================================
# Notes:
# ============================================================================
# 
# 1. Always use CONFIG mode for find_package when looking for modern targets
# 2. Always check if the target exists before using it
# 3. Provide a fallback mechanism for compatibility
# 4. Modern targets automatically handle:
#    - Include directories
#    - Compile definitions
#    - Link flags
#    - Transitive dependencies
# 5. No need to manually call target_include_directories for these libraries

