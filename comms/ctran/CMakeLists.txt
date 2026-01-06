# Copyright (c) Meta Platforms, Inc. and affiliates.

# Detect GPU backend
if(DEFINED ENV{USE_INTEL_GPU} OR USE_XCCL)
    set(USE_INTEL_GPU ON)
    message(STATUS "Building ctran with Intel GPU/SYCL support")
    add_compile_definitions(USE_INTEL_GPU CTRAN_USE_SYCL)
else()
    find_package(CUDA REQUIRED)
endif()

file(GLOB_RECURSE CTRAN_SOURCES
    "*.cc"
)
# Only include .cu files for CUDA/ROCm builds
if(NOT USE_INTEL_GPU)
    file(GLOB_RECURSE CTRAN_CU_SOURCES "*.cu")
    list(APPEND CTRAN_SOURCES ${CTRAN_CU_SOURCES})
endif()

list(FILTER CTRAN_SOURCES EXCLUDE REGEX ".*/tests/.*")
list(FILTER CTRAN_SOURCES EXCLUDE REGEX ".*/benchmarks/.*")
if (NOT DEFINED ENABLE_TCPDM)
    add_compile_definitions(CTRAN_DISABLE_TCPDM)
    list(FILTER CTRAN_SOURCES EXCLUDE REGEX ".*/ctran/backends/tcpdevmem/.*")
endif()

if(NOT USE_INTEL_GPU)
    list(FILTER CMAKE_CUDA_FLAGS EXCLUDE REGEX ".*arch=compute_50,code=sm_50")
    list(FILTER CMAKE_CUDA_FLAGS EXCLUDE REGEX ".*arch=compute_60,code=sm_60")
    list(FILTER CMAKE_CUDA_FLAGS EXCLUDE REGEX ".*arch=compute_70,code=sm_70")
    list(FILTER CMAKE_CUDA_FLAGS EXCLUDE REGEX ".*arch=compute_75,code=sm_75")

    message(status "CMAKE_CUDA_FLAGS: ${CMAKE_CUDA_FLAGS}")
endif()

# genctran.py generates source files (*.cu) for template instantiations across
# different algorithms, data types, and operations.
# Skip for Intel GPU builds as we don't have GPU kernels yet
if(NOT USE_INTEL_GPU)
    execute_process(
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/algos/genctran.py ${CMAKE_CURRENT_BINARY_DIR}/gensrc
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    file(GLOB CTRAN_GENSRC_FILES "${CMAKE_CURRENT_BINARY_DIR}/gensrc/*.cu")
else()
    set(CTRAN_GENSRC_FILES "")
endif()

add_library(ctran OBJECT
  ${CTRAN_GENSRC_FILES}
  ${CTRAN_SOURCES}
)

target_compile_features(ctran PRIVATE cxx_std_20)

target_compile_options(ctran PRIVATE
    -fPIC
)

if(NOT USE_INTEL_GPU)
    target_compile_options(ctran PRIVATE
        # copied from nccl
        $<$<COMPILE_LANGUAGE:CUDA>:--expt-extended-lambda -Xptxas -maxrregcount=96 -Xfatbin -compress-all>
    )
    if (NOT DEFINED ENABLE_TCPDM)
        target_compile_options(ctran PRIVATE
            # copied from nccl
            $<$<COMPILE_LANGUAGE:CUDA>:--compiler-options "-DCTRAN_DISABLE_TCPDM">
        )
    endif()

    set_target_properties(ctran PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
        POSITION_INDEPENDENT_CODE ON
    )
else()
    set_target_properties(ctran PROPERTIES
        POSITION_INDEPENDENT_CODE ON
    )
endif()

target_include_directories(ctran PRIVATE
    ${ROOT}
    ${CONDA_INCLUDE}
)

if(NOT USE_INTEL_GPU)
    target_include_directories(ctran PRIVATE ${CUDA_INCLUDE_DIRS})
else()
    # Find Level Zero headers for Intel GPU
    find_path(LEVEL_ZERO_INCLUDE_DIR
        NAMES level_zero/ze_api.h
        PATHS
            $ENV{LEVEL_ZERO_DIR}/include
            /usr/include
            /usr/local/include
    )
    if(LEVEL_ZERO_INCLUDE_DIR)
        message(STATUS "Found Level Zero headers for ctran: ${LEVEL_ZERO_INCLUDE_DIR}")
        target_include_directories(ctran PRIVATE ${LEVEL_ZERO_INCLUDE_DIR})
    endif()

    # Find and link Level Zero library
    find_library(LEVEL_ZERO_LIB
        NAMES ze_loader
        PATHS
            $ENV{LEVEL_ZERO_DIR}/lib
            /usr/lib
            /usr/local/lib
            /usr/lib/x86_64-linux-gnu
    )
    if(LEVEL_ZERO_LIB)
        message(STATUS "Found Level Zero library for ctran: ${LEVEL_ZERO_LIB}")
        target_link_libraries(ctran PRIVATE ${LEVEL_ZERO_LIB})
    else()
        message(WARNING "Level Zero library not found, GPU Direct RDMA will not work")
    endif()
endif()
