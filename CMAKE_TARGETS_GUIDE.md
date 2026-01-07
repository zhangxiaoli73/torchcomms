# CMake Modern Targets Guide

本文档说明如何在 torchcomms 项目中使用现代 CMake targets 来管理依赖项。

## 概述

项目已更新为使用 CMake 的 `find_package(CONFIG)` 和 imported targets，而不是直接使用 `-lglog` 等链接标志。

## 主要变更

### 1. 在主 CMakeLists.txt 中查找依赖包

```cmake
# Find dependencies using CONFIG mode for modern CMake targets
find_package(glog CONFIG)
find_package(gflags CONFIG)
find_package(fmt CONFIG)
```

### 2. 使用 CMake Targets 链接库

**旧方式（已弃用）：**
```cmake
target_link_libraries(torchcomms PRIVATE "-lglog" "-lgflags" "-lfmt")
```

**新方式（推荐）：**
```cmake
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
```

## 优势

1. **自动处理依赖关系**：CMake targets 会自动包含必要的头文件路径和链接标志
2. **更好的可移植性**：不需要手动指定库路径
3. **类型安全**：CMake 可以在配置时检查 target 是否存在
4. **传递依赖**：自动处理库的传递依赖关系

## 已更新的文件

- `CMakeLists.txt` - 主配置文件
- `comms/torchcomms/ncclx/CMakeLists.txt` - NCCLX 模块
- `comms/torchcomms/gloo/CMakeLists.txt` - Gloo 模块
- `comms/torchcomms/transport/CMakeLists.txt` - Transport 模块

## 环境要求

确保 `CMAKE_PREFIX_PATH` 包含依赖库的安装路径，或者设置 `CONDA_PREFIX` 环境变量：

```bash
export CONDA_PREFIX=/path/to/conda/env
```

CMake 会自动将 `CONDA_PREFIX` 添加到 `CMAKE_PREFIX_PATH`。

## 常见 CMake Targets

| 库名 | CMake Target | 说明 |
|------|--------------|------|
| glog | `glog::glog` | Google Logging Library |
| gflags | `gflags::gflags` | Google Flags Library |
| fmt | `fmt::fmt` | Modern C++ formatting library |
| CUDA | `CUDA::cudart` | CUDA Runtime |

## 调试

如果 CMake 找不到某个包，可以设置详细输出：

```bash
cmake -DCMAKE_FIND_DEBUG_MODE=ON ..
```

或者手动指定包的位置：

```bash
cmake -Dglog_DIR=/path/to/glog/lib/cmake/glog \
      -Dgflags_DIR=/path/to/gflags/lib/cmake/gflags \
      -Dfmt_DIR=/path/to/fmt/lib/cmake/fmt \
      ..
```

## 向后兼容

代码保持了向后兼容性：如果 CMake 找不到 CONFIG 包，会回退到使用传统的 `-l` 链接方式。

