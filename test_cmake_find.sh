#!/bin/bash
# Quick test to see if CMake can find the dependencies

set -e

echo "=========================================="
echo "Testing CMake Dependency Detection"
echo "=========================================="

if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: CONDA_PREFIX is not set"
    echo "Please activate your conda environment first"
    exit 1
fi

echo "CONDA_PREFIX: $CONDA_PREFIX"
echo ""

# Create a minimal test CMakeLists.txt
cat > /tmp/test_cmake_find.cmake << 'EOF'
cmake_minimum_required(VERSION 3.22)
project(test_find)

# Add CONDA_PREFIX to search paths
if(DEFINED ENV{CONDA_PREFIX})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/lib64/cmake")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/share/cmake")
endif()

message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

# Try to find packages
find_package(glog CONFIG QUIET)
find_package(gflags CONFIG QUIET)
find_package(fmt CONFIG QUIET)

# If not found via CONFIG, try to create imported targets
if(NOT TARGET glog::glog AND DEFINED ENV{CONDA_PREFIX})
    find_library(GLOG_LIBRARY NAMES glog PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
    find_path(GLOG_INCLUDE_DIR NAMES glog/logging.h PATHS "$ENV{CONDA_PREFIX}/include" NO_DEFAULT_PATH)
    
    if(GLOG_LIBRARY AND GLOG_INCLUDE_DIR)
        add_library(glog::glog UNKNOWN IMPORTED)
        set_target_properties(glog::glog PROPERTIES
            IMPORTED_LOCATION "${GLOG_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GLOG_INCLUDE_DIR}"
        )
        message(STATUS "Created glog::glog from: ${GLOG_LIBRARY}")
    endif()
endif()

if(NOT TARGET gflags::gflags AND DEFINED ENV{CONDA_PREFIX})
    find_library(GFLAGS_LIBRARY NAMES gflags PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
    find_path(GFLAGS_INCLUDE_DIR NAMES gflags/gflags.h PATHS "$ENV{CONDA_PREFIX}/include" NO_DEFAULT_PATH)
    
    if(GFLAGS_LIBRARY AND GFLAGS_INCLUDE_DIR)
        add_library(gflags::gflags UNKNOWN IMPORTED)
        set_target_properties(gflags::gflags PROPERTIES
            IMPORTED_LOCATION "${GFLAGS_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GFLAGS_INCLUDE_DIR}"
        )
        message(STATUS "Created gflags::gflags from: ${GFLAGS_LIBRARY}")
    endif()
endif()

if(NOT TARGET fmt::fmt AND DEFINED ENV{CONDA_PREFIX})
    find_library(FMT_LIBRARY NAMES fmt PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
    find_path(FMT_INCLUDE_DIR NAMES fmt/core.h PATHS "$ENV{CONDA_PREFIX}/include" NO_DEFAULT_PATH)
    
    if(FMT_LIBRARY AND FMT_INCLUDE_DIR)
        add_library(fmt::fmt UNKNOWN IMPORTED)
        set_target_properties(fmt::fmt PROPERTIES
            IMPORTED_LOCATION "${FMT_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FMT_INCLUDE_DIR}"
        )
        message(STATUS "Created fmt::fmt from: ${FMT_LIBRARY}")
    endif()
endif()

# Report results
message(STATUS "")
message(STATUS "=== Results ===")
if(TARGET glog::glog)
    message(STATUS "✓ glog::glog target is available")
    get_target_property(GLOG_LOC glog::glog IMPORTED_LOCATION)
    message(STATUS "  Location: ${GLOG_LOC}")
else()
    message(STATUS "✗ glog::glog target NOT available")
endif()

if(TARGET gflags::gflags)
    message(STATUS "✓ gflags::gflags target is available")
    get_target_property(GFLAGS_LOC gflags::gflags IMPORTED_LOCATION)
    message(STATUS "  Location: ${GFLAGS_LOC}")
else()
    message(STATUS "✗ gflags::gflags target NOT available")
endif()

if(TARGET fmt::fmt)
    message(STATUS "✓ fmt::fmt target is available")
    get_target_property(FMT_LOC fmt::fmt IMPORTED_LOCATION)
    message(STATUS "  Location: ${FMT_LOC}")
else()
    message(STATUS "✗ fmt::fmt target NOT available")
endif()
EOF

# Run CMake with the test file
echo "Running CMake test..."
echo ""
cmake -P /tmp/test_cmake_find.cmake

echo ""
echo "=========================================="
echo "Test complete!"
echo "=========================================="

