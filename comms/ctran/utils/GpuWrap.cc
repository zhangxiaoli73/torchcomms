// Copyright (c) Meta Platforms, Inc. and affiliates.
// GPU abstraction layer implementation

#include "comms/ctran/utils/GpuWrap.h"
#include "comms/utils/logger/LogUtils.h"

#include <mutex>

#ifdef CTRAN_USE_SYCL
// For SYCL/Intel GPU, use Level Zero for DMA-BUF support
#include "comms/ctran/utils/LevelZeroWrap.h"
#else
#include "comms/ctran/utils/CudaWrap.h"
#endif

namespace ctran::utils {

#ifdef CTRAN_USE_SYCL

// SYCL/Intel GPU implementations using Level Zero

static std::once_flag gpuLibraryInitFlag;
static commResult_t gpuLibraryInitResult = commSystemError;

static commResult_t initGpuLibraryOnce_() {
    // Initialize Level Zero for DMA-BUF support
    commResult_t result = levelZeroLibraryInit();
    if (result == commSuccess) {
        CLOGF_SUBSYS(INFO, INIT, "Intel GPU library initialized with Level Zero");
    } else {
        CLOGF_SUBSYS(WARN, INIT, "Failed to initialize Level Zero, DMA-BUF support unavailable");
    }
    gpuLibraryInitResult = result;
    return result;
}

commResult_t commGpuLibraryInit() {
    std::call_once(gpuLibraryInitFlag, initGpuLibraryOnce_);
    return gpuLibraryInitResult;
}

bool isCommGpuLibraryInited() {
    return gpuLibraryInitResult == commSuccess;
}

commResult_t dmaBufDriverSupport(int gpuDev) {
    // Check DMA-BUF support via Level Zero
    return levelZeroDmaBufSupport(gpuDev);
}

int getCuMemDmaBufFd(
    const void* buf,
    const size_t len,
    bool dataDirectPci) {
    // Export DMA-BUF file descriptor via Level Zero
    // Note: dataDirectPci is NVIDIA-specific, ignored for Intel GPU

    // Try to get device ID from Level Zero memory properties
    // If that fails, use device 0 as default
    int deviceId = 0;

    auto& ctx = LevelZeroContext::getInstance();
    if (ctx.isInitialized()) {
        ze_memory_allocation_properties_t memProps = {
            ZE_STRUCTURE_TYPE_MEMORY_ALLOCATION_PROPERTIES,
            nullptr};
        ze_device_handle_t allocDevice = nullptr;

        ze_result_t result = zeMemGetAllocProperties(
            ctx.getContext(),
            buf,
            &memProps,
            &allocDevice);

        if (result == ZE_RESULT_SUCCESS && allocDevice) {
            // Find device index
            for (int i = 0; i < ctx.getDeviceCount(); i++) {
                if (ctx.getDevice(i) == allocDevice) {
                    deviceId = i;
                    break;
                }
            }
        }
    }

    return getLevelZeroDmaBufFd(buf, len, deviceId);
}

bool gpuDirectRdmaWithCudaVmmSupported(const int gpuDev) {
    // Check GPU Direct RDMA support via Level Zero
    return levelZeroGpuDirectRdmaSupported(gpuDev);
}

bool getCuMemSysSupported() {
    // Intel GPU uses different memory management
    // Return false to use standard allocation paths
    return false;
}

bool isCuMemSupported() {
    // Intel GPU uses different memory management
    return false;
}

#else

// CUDA/HIP implementations - delegate to CudaWrap
// Note: These functions are already declared in CudaWrap.h
// We just provide wrapper implementations here for consistency

commResult_t commGpuLibraryInit() {
    return commCudaLibraryInit();
}

bool isCommGpuLibraryInited() {
    return isCommCudaLibraryInited();
}

// dmaBufDriverSupport, getCuMemDmaBufFd, gpuDirectRdmaWithCudaVmmSupported,
// getCuMemSysSupported, and isCuMemSupported are already implemented in CudaWrap.cc
// and declared in CudaWrap.h, so we don't need to redefine them here.

#endif

} // namespace ctran::utils

