# Intel GPU Build 修复说明

## 问题

在Intel GPU模式下构建transport时遇到错误：
```
CMake Error: Specify CUDA_TOOLKIT_ROOT_DIR
Call Stack: comms/utils/CMakeLists.txt:3 (find_package)
```

## 根本原因

`comms/utils/CMakeLists.txt`无条件地要求CUDA toolkit，即使在Intel GPU模式下也是如此。

## 解决方案

修改了`comms/utils/CMakeLists.txt`，使其在Intel GPU模式下：
1. 不要求CUDA toolkit
2. 排除CUDA特定的源文件
3. 不添加CUDA include目录

## 修改的文件

### 1. `comms/utils/CMakeLists.txt`

**修改前**:
```cmake
find_package(CUDA REQUIRED)

file(GLOB_RECURSE UTILS_SOURCES "*.cc")
list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*/tests/.*")

target_include_directories(utils PUBLIC
    ${ROOT}
    ${CONDA_INCLUDE}
    ${CUDA_INCLUDE_DIRS}
)
```

**修改后**:
```cmake
# Only require CUDA if not using Intel GPU
if(NOT USE_INTEL_GPU)
    find_package(CUDA REQUIRED)
endif()

file(GLOB_RECURSE UTILS_SOURCES "*.cc")
list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*/tests/.*")

# Exclude CUDA-specific files when building for Intel GPU
if(USE_INTEL_GPU)
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaRAII\\.cc$")
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaEventPool\\.cc$")
    list(FILTER UTILS_SOURCES EXCLUDE REGEX ".*CudaWaitEvent\\.cc$")
    message(STATUS "Excluding CUDA-specific files from utils for Intel GPU build")
endif()

target_include_directories(utils PUBLIC
    ${ROOT}
    ${CONDA_INCLUDE}
)

# Add CUDA include directories only if using CUDA
if(NOT USE_INTEL_GPU)
    target_include_directories(utils PUBLIC ${CUDA_INCLUDE_DIRS})
endif()
```

## 排除的CUDA特定文件

在Intel GPU模式下，以下文件被排除（因为它们直接使用CUDA API）：

1. **`comms/utils/CudaRAII.cc`** - CUDA RAII包装器
   - `DeviceBuffer` - cudaMalloc/cudaFree
   - `CudaStream` - cudaStreamCreate/cudaStreamDestroy
   - `CudaEvent` - cudaEventCreate/cudaEventDestroy

2. **`comms/utils/colltrace/CudaEventPool.cc`** - CUDA事件池
   - 使用`CudaEvent`类

3. **`comms/utils/colltrace/CudaWaitEvent.cc`** - CUDA等待事件
   - 使用CUDA事件API

**注意**: 这些功能在Intel GPU上不需要，因为：
- PyTorch XPU提供了自己的内存管理
- Intel GPU使用不同的事件和同步机制
- Transport层不直接依赖这些CUDA特定的工具类

## 验证

现在可以成功构建：

```bash
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

pip install --no-build-isolation -v -e .
```

预期输出应包含：
```
-- Building transport with Intel GPU/SYCL support
-- Building ctran with Intel GPU/SYCL support
-- Excluding CUDA-specific files from utils for Intel GPU build
-- Found Level Zero headers: /usr/include
-- Found Level Zero library: /usr/lib/x86_64-linux-gnu/libze_loader.so
```

## 完整的修改列表

所有Intel GPU支持相关的修改：

1. ✅ `comms/ctran/utils/LevelZeroWrap.h` - Level Zero API封装
2. ✅ `comms/ctran/utils/LevelZeroWrap.cc` - Level Zero实现
3. ✅ `comms/ctran/utils/GpuWrap.h` - GPU抽象层（CUDA/SYCL）
4. ✅ `comms/ctran/utils/GpuWrap.cc` - SYCL实现
5. ✅ `comms/ctran/CMakeLists.txt` - ctran构建配置
6. ✅ `comms/torchcomms/transport/CMakeLists.txt` - transport构建配置
7. ✅ **`comms/utils/CMakeLists.txt`** - utils构建配置（本次修复）

## 测试

```bash
# 1. 清理之前的构建
rm -rf build/
python setup.py clean --all

# 2. 构建
pip install --no-build-isolation -v -e .

# 3. 验证
python -c "from torchcomms import _transport; print('✓ Transport loaded')"
```

## 故障排查

如果仍然遇到CUDA相关错误：

1. **确保环境变量正确设置**:
   ```bash
   echo $USE_INTEL_GPU  # 应该是 1
   echo $USE_XCCL       # 应该是 ON
   ```

2. **清理CMake缓存**:
   ```bash
   rm -rf build/ CMakeCache.txt CMakeFiles/
   ```

3. **检查CMake输出**:
   应该看到 "Building transport with Intel GPU/SYCL support"

4. **检查是否有其他CUDA依赖**:
   ```bash
   grep -r "find_package(CUDA" comms/
   ```

## 相关文档

- `BUILD_STATUS.md` - 构建状态总结
- `INTEL_GPU_BUILD_CHECKLIST.md` - 详细检查清单
- `INTEL_GPU_RDMA_SETUP.md` - 完整设置指南

