# Copyright (c) Meta Platforms, Inc. and affiliates.

cmake_minimum_required(VERSION 3.22)
project(torchcomms_ncclx)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(FETCHCONTENT_BASE_DIR "build/fetchcontent")

# Options
option(USE_NCCL "Whether to build NCCL or not" ON)
option(USE_NCCLX "Whether to build NCCLX or not" ON)
option(USE_GLOO "Whether to build Gloo or not" ON)
option(USE_RCCL "Whether to build RCCL or not" OFF)
option(USE_RCCLX "Whether to build RCCLX or not" OFF)
option(USE_XCCL "Whether to build XCCL or not" OFF)
option(USE_TRANSPORT "Whether to build TRANSPORT or not" ON)
message(STATUS "  USE_NCCL : ${USE_NCCL}")
message(STATUS "  USE_NCCLX : ${USE_NCCLX}")
message(STATUS "  USE_GLOO  : ${USE_GLOO}")
message(STATUS "  USE_RCCL  : ${USE_RCCL}")
message(STATUS "  USE_RCCLX  : ${USE_RCCLX}")
message(STATUS "  USE_XCCL  : ${USE_XCCL}")
message(STATUS "  USE_TRANSPORT  : ${USE_TRANSPORT}")

if(NOT DEFINED ENV{TORCH_CUDA_ARCH_LIST})
    set(TORCH_CUDA_ARCH_LIST "9.0")
else()
    set(TORCH_CUDA_ARCH_LIST $ENV{TORCH_CUDA_ARCH_LIST})
endif()
message(STATUS "TORCH_CUDA_ARCH_LIST : ${TORCH_CUDA_ARCH_LIST}")

# Find Python and PyTorch
find_package(Python3 COMPONENTS Interpreter Development.Module REQUIRED)
find_package(Torch REQUIRED)

# Find dependencies using CONFIG mode for modern CMake targets
# Set CMAKE_PREFIX_PATH to include CONDA_PREFIX for finding packages
if(DEFINED ENV{CONDA_PREFIX})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
    # Also add common CMake config locations
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/lib64/cmake")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/share/cmake")
endif()

# Try to find packages using CONFIG mode (looks for *Config.cmake files)
# QUIET means don't error if not found, we'll handle it gracefully
find_package(glog CONFIG QUIET)
find_package(gflags CONFIG QUIET)
find_package(fmt CONFIG QUIET)

# If CONFIG mode fails, try to create imported targets manually
# This handles cases where conda packages don't provide CMake config files
if(NOT TARGET glog::glog AND DEFINED ENV{CONDA_PREFIX})
    find_library(GLOG_LIBRARY NAMES glog PATHS "$ENV{CONDA_PREFIX}/lib" NO_DEFAULT_PATH)
    find_path(GLOG_INCLUDE_DIR NAMES glog/logging.h PATHS "$ENV{CONDA_PREFIX}/include" NO_DEFAULT_PATH)

    if(GLOG_LIBRARY AND GLOG_INCLUDE_DIR)
        add_library(glog::glog UNKNOWN IMPORTED)
        set_target_properties(glog::glog PROPERTIES
            IMPORTED_LOCATION "${GLOG_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GLOG_INCLUDE_DIR}"
        )
        message(STATUS "Created glog::glog imported target from: ${GLOG_LIBRARY}")
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
        message(STATUS "Created gflags::gflags imported target from: ${GFLAGS_LIBRARY}")
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
        message(STATUS "Created fmt::fmt imported target from: ${FMT_LIBRARY}")
    endif()
endif()

# Print what we found
if(TARGET glog::glog)
    message(STATUS "✓ glog::glog target is available")
else()
    message(STATUS "✗ glog::glog target not available, will use fallback")
endif()

if(TARGET gflags::gflags)
    message(STATUS "✓ gflags::gflags target is available")
else()
    message(STATUS "✗ gflags::gflags target not available, will use fallback")
endif()

if(TARGET fmt::fmt)
    message(STATUS "✓ fmt::fmt target is available")
else()
    message(STATUS "✗ fmt::fmt target not available, will use fallback")
endif()


# Helper to glob sources
file(GLOB TORCHCOMMS_SOURCES "comms/torchcomms/*.cpp")
file(GLOB TORCHCOMMS_PYTHON_SOURCES "comms/torchcomms/*Py.cpp")
list(REMOVE_ITEM TORCHCOMMS_SOURCES ${TORCHCOMMS_PYTHON_SOURCES})

# Set include directories
set(ROOT ${CMAKE_CURRENT_SOURCE_DIR})

set(USE_SYSTEM_LIBS $ENV{USE_SYSTEM_LIBS})

message(STATUS "Python3_ROOT_DIR : ${Python3_ROOT_DIR}")

# Find CONDA_PREFIX
if(DEFINED ENV{BUILD_PREFIX})
    set(CONDA_PREFIX $ENV{PREFIX})
elseif(DEFINED ENV{CONDA_PREFIX})
  set(CONDA_PREFIX $ENV{CONDA_PREFIX})
else()
  set(CONDA_PREFIX "${ROOT}/build/conda")
  set(ENV{CONDA_PREFIX} "${CONDA_PREFIX}")
endif()

# Set LIB_SUFFIX (default to "lib", can be overridden by environment)
if(DEFINED ENV{LIB_SUFFIX})
  set(LIB_SUFFIX $ENV{LIB_SUFFIX})
else()
  set(LIB_SUFFIX "lib")
endif()

set(CONDA_LIB "${CONDA_PREFIX}/${LIB_SUFFIX}")
set(CONDA_INCLUDE "${CONDA_PREFIX}/include")
set(TORCH_PYTHON_LIB "${TORCH_INSTALL_PREFIX}/lib/libtorch_python.so")

# Core libtorchcomms
add_library(torchcomms SHARED ${TORCHCOMMS_SOURCES})
set_target_properties(torchcomms PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/comms/torchcomms"
)

target_include_directories(torchcomms PRIVATE
    ${ROOT}
    ${CONDA_INCLUDE}
    ${Python3_INCLUDE_DIRS}
)
target_compile_features(torchcomms PRIVATE cxx_std_20)
target_compile_definitions(torchcomms PRIVATE
    GLOG_NO_ABBREVIATED_SEVERITIES
    GLOG_USE_GLOG_EXPORT
)
target_link_libraries(torchcomms PRIVATE ${TORCH_LIBRARIES})

# Link dependencies using modern CMake targets
if(USE_SYSTEM_LIBS)
    # Use shared libraries with CMake targets
    if(TARGET glog::glog)
        target_link_libraries(torchcomms PRIVATE glog::glog)
    else()
        target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
        target_link_libraries(torchcomms PRIVATE "-lglog")
    endif()

    if(TARGET gflags::gflags)
        target_link_libraries(torchcomms PRIVATE gflags::gflags)
    else()
        target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
        target_link_libraries(torchcomms PRIVATE "-lgflags")
    endif()

    if(TARGET fmt::fmt)
        target_link_libraries(torchcomms PRIVATE fmt::fmt)
    else()
        target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
        target_link_libraries(torchcomms PRIVATE "-lfmt")
    endif()
else()
    # Use static libraries
    target_include_directories(torchcomms PRIVATE
        ${ROOT}/third-party/fmt/include
    )
    target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
    target_link_libraries(torchcomms PRIVATE
        "-l:libglog.a"
        "-l:libgflags.a"
        "-l:libfmt.a"
    )
endif()

# Extension: torchcomms._comms
add_library(torchcomms_comms MODULE ${TORCHCOMMS_PYTHON_SOURCES})
set_target_properties(torchcomms_comms PROPERTIES
    PREFIX ""  # No 'lib' prefix for Python extension
    OUTPUT_NAME "_comms"
    SUFFIX ".${Python3_SOABI}.so"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/comms/torchcomms"
)
target_include_directories(torchcomms_comms PRIVATE
    ${ROOT}
    ${CONDA_INCLUDE}
    ${Python3_INCLUDE_DIRS}
)
target_compile_features(torchcomms_comms PRIVATE cxx_std_20)
target_link_directories(torchcomms_comms PRIVATE ${CONDA_LIB})
target_link_libraries(torchcomms_comms PRIVATE
    ${TORCH_LIBRARIES}
    ${TORCH_PYTHON_LIB}
    torchcomms
)

if (USE_NCCL)
    include(comms/torchcomms/nccl/CMakeLists.txt)
endif()
if (USE_NCCLX)
    include(comms/torchcomms/ncclx/CMakeLists.txt)
endif()
if (USE_GLOO)
    include(comms/torchcomms/gloo/CMakeLists.txt)
endif()
if (USE_RCCL)
    include(comms/torchcomms/rccl/CMakeLists.txt)
endif()
if (USE_RCCLX)
    include(comms/torchcomms/rcclx/CMakeLists.txt)
endif()
if (USE_XCCL)
    include(comms/torchcomms/xccl/CMakeLists.txt)
endif()
if (USE_TRANSPORT)
    include(comms/torchcomms/transport/CMakeLists.txt)
endif()

# Install targets to Python package structure
install(TARGETS torchcomms
    LIBRARY DESTINATION .
)
install(TARGETS torchcomms_comms
    LIBRARY DESTINATION .
)
