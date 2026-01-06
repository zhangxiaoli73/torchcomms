// Copyright (c) Meta Platforms, Inc. and affiliates.
// GPU abstraction layer implementation

#include "comms/ctran/utils/GpuWrap.h"
#include "comms/utils/logger/LogUtils.h"

#include <mutex>

#ifdef CTRAN_USE_SYCL
// For SYCL, we don't have direct CUDA equivalents
// We'll provide stub implementations that return "not supported"
#else
#include "comms/ctran/utils/CudaWrap.h"
#endif

namespace ctran::utils {

#ifdef CTRAN_USE_SYCL

// SYCL implementations - mostly stubs for now
// Transport on Intel GPU will work without GPU Direct RDMA initially

static std::once_flag gpuLibraryInitFlag;
static commResult_t gpuLibraryInitResult = commSystemError;

static commResult_t initGpuLibraryOnce_() {
    // For SYCL, we don't need special initialization
    // The SYCL runtime is initialized by PyTorch
    CLOGF_SUBSYS(INFO, INIT, "SYCL GPU library initialized (no-op)");
    gpuLibraryInitResult = commSuccess;
    return commSuccess;
}

commResult_t commGpuLibraryInit() {
    std::call_once(gpuLibraryInitFlag, initGpuLibraryOnce_);
    return gpuLibraryInitResult;
}

bool isCommGpuLibraryInited() {
    return gpuLibraryInitResult == commSuccess;
}

commResult_t dmaBufDriverSupport(int gpuDev) {
    // DMA-BUF support for Intel GPU is not yet implemented
    // This will require Level Zero or SYCL extensions
    CLOGF_SUBSYS(WARN, INIT, "DMA-BUF not yet supported on Intel GPU/SYCL");
    return commInternalError;
}

int getCuMemDmaBufFd(
    const void* buf,
    const size_t len,
    bool dataDirectPci) {
    // Not supported on SYCL yet
    return -1;
}

bool gpuDirectRdmaWithCudaVmmSupported(const int gpuDev) {
    // GPU Direct RDMA not yet supported on Intel GPU
    // Will need Level Zero extensions
    return false;
}

bool getCuMemSysSupported() {
    return false;
}

bool isCuMemSupported() {
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

