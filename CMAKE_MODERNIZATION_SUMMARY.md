# CMake 现代化改造总结

## 改造目标

将项目从使用传统的 `-lglog`、`-lgflags`、`-lfmt` 链接方式升级为使用现代 CMake targets（如 `glog::glog`、`gflags::gflags`、`fmt::fmt`）。

## 已完成的更改

### 1. 主 CMakeLists.txt

**文件**: `CMakeLists.txt`

**添加的内容**:
```cmake
# Find dependencies using CONFIG mode for modern CMake targets
# Set CMAKE_PREFIX_PATH to include CONDA_PREFIX for finding packages
if(DEFINED ENV{CONDA_PREFIX})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
endif()

# Find glog, gflags, and fmt using CONFIG mode
find_package(glog CONFIG)
find_package(gflags CONFIG)
find_package(fmt CONFIG)
```

**修改的链接方式**:
```cmake
# 旧方式
target_link_libraries(torchcomms PRIVATE "-lglog" "-lgflags" "-lfmt")

# 新方式（带回退机制）
if(TARGET glog::glog)
    target_link_libraries(torchcomms PRIVATE glog::glog)
else()
    target_link_directories(torchcomms PRIVATE ${CONDA_LIB})
    target_link_libraries(torchcomms PRIVATE "-lglog")
endif()
# ... 对 gflags 和 fmt 做同样的处理
```

### 2. NCCLX 模块

**文件**: `comms/torchcomms/ncclx/CMakeLists.txt`

- 在 `USE_SYSTEM_LIBS` 分支中使用 `fmt::fmt` target
- 保持静态链接分支不变（使用 `-l:libfmt.a`）

### 3. Gloo 模块

**文件**: `comms/torchcomms/gloo/CMakeLists.txt`

- 在 `USE_SYSTEM_LIBS` 分支中使用 `fmt::fmt` target
- 保持静态链接分支不变

### 4. Transport 模块

**文件**: `comms/torchcomms/transport/CMakeLists.txt`

- 在 `USE_SYSTEM_LIBS` 分支中使用 `glog::glog`、`gflags::gflags`、`fmt::fmt` targets
- 保持静态链接分支不变

## 设计原则

### 1. 向后兼容
所有更改都包含回退机制：
```cmake
if(TARGET glog::glog)
    # 使用现代 target
    target_link_libraries(... glog::glog)
else()
    # 回退到传统方式
    target_link_libraries(... "-lglog")
endif()
```

### 2. 仅影响 USE_SYSTEM_LIBS 模式
- 静态链接模式（`USE_SYSTEM_LIBS=OFF`）保持不变
- 系统库模式（`USE_SYSTEM_LIBS=ON`）使用现代 targets

### 3. 自动路径发现
通过将 `CONDA_PREFIX` 添加到 `CMAKE_PREFIX_PATH`，CMake 可以自动找到安装在 conda 环境中的包。

## 优势

1. **自动依赖管理**: CMake targets 自动包含头文件路径和链接标志
2. **更好的可移植性**: 不需要硬编码库路径
3. **类型安全**: 编译时检查 target 是否存在
4. **传递依赖**: 自动处理库的传递依赖
5. **IDE 友好**: 现代 IDE 可以更好地理解 CMake targets

## 未修改的文件

以下文件不需要修改，因为它们：
- 不直接链接 glog/gflags/fmt（如 `comms/ctran/CMakeLists.txt`、`comms/utils/CMakeLists.txt`）
- 已经使用现代 targets（如 `comms/rcclx/develop/CMakeLists.txt` 使用 `fmt::fmt-header-only`）
- 是独立的子项目（如 RCCL）

## 测试建议

### 使用系统库构建
```bash
export USE_SYSTEM_LIBS=1
export CONDA_PREFIX=/path/to/conda/env
cmake -B build -S .
cmake --build build
```

### 使用静态库构建
```bash
unset USE_SYSTEM_LIBS
cmake -B build -S .
cmake --build build
```

## 相关文档

- `CMAKE_TARGETS_GUIDE.md` - 详细的使用指南
- CMake 官方文档: https://cmake.org/cmake/help/latest/command/find_package.html

## 常见问题

**Q: 如果 CMake 找不到 glog::glog 怎么办？**

A: 系统会自动回退到传统的 `-lglog` 方式。你也可以手动指定：
```bash
cmake -Dglog_DIR=/path/to/glog/lib/cmake/glog ...
```

**Q: 这会影响现有的构建吗？**

A: 不会。所有更改都有回退机制，确保向后兼容。

**Q: 为什么静态链接模式不使用 CMake targets？**

A: 静态链接模式使用特定的 `.a` 文件，需要精确控制链接顺序和符号重命名，因此保持原有方式。

