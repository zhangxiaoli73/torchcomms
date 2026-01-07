# 清理和重新构建指南

## 快速清理方法

### 方法 1: 完全清理（推荐）

```bash
# 删除整个 build 目录
rm -rf build

# 重新构建
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_INTEL_GPU=ON -DUSE_XCCL=ON
cmake --build . -j$(nproc)
```

### 方法 2: 使用提供的脚本

```bash
# 给脚本添加执行权限
chmod +x clean_and_rebuild.sh

# 运行脚本
./clean_and_rebuild.sh
```

### 方法 3: 只清理编译产物（保留 CMake 缓存）

```bash
cd build
cmake --build . --target clean
cmake --build . -j$(nproc)
```

## 针对不同场景的清理策略

### 场景 1: 修改了 CMakeLists.txt 或添加了新的源文件
**推荐**: 完全删除 build 目录
```bash
rm -rf build
```

### 场景 2: 只修改了源代码（.cpp, .hpp 文件）
**推荐**: 使用 make clean 或直接重新编译
```bash
cd build
make clean  # 或 cmake --build . --target clean
make -j$(nproc)
```

### 场景 3: 修改了编译选项或环境变量
**推荐**: 完全删除 build 目录
```bash
rm -rf build
```

### 场景 4: 遇到奇怪的编译错误
**推荐**: 完全删除 build 目录，并清理 CMake 缓存
```bash
rm -rf build
rm -rf CMakeFiles
rm -f CMakeCache.txt
```

## 清理其他构建产物

### 清理 Python 构建产物
```bash
# 清理 Python 编译的文件
find . -type f -name "*.pyc" -delete
find . -type d -name "__pycache__" -delete
rm -rf *.egg-info
rm -rf dist
```

### 清理所有构建相关文件
```bash
# 清理所有构建目录和缓存
rm -rf build
rm -rf build_*
rm -rf .cmake
rm -rf CMakeFiles
rm -f CMakeCache.txt
rm -f cmake_install.cmake
rm -f Makefile
```

## 验证清理是否成功

```bash
# 检查 build 目录是否存在
ls -la build  # 应该显示 "No such file or directory"

# 检查是否有残留的编译产物
find . -name "*.o" -o -name "*.so" -o -name "*.a" | grep -v third-party
```

## 重新构建的完整流程

```bash
# 1. 清理
rm -rf build

# 2. 创建构建目录
mkdir -p build
cd build

# 3. 配置 CMake（根据你的需求调整选项）
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_INTEL_GPU=ON \
  -DUSE_XCCL=ON \
  -DCMAKE_VERBOSE_MAKEFILE=ON  # 可选：显示详细编译命令

# 4. 构建
cmake --build . -j$(nproc)

# 5. 验证构建结果
ls -lh comms/torchcomms/*.so
```

## 常见问题

### Q: 删除 build 目录会影响源代码吗？
A: 不会。build 目录只包含编译产物，删除它不会影响源代码。

### Q: 需要清理第三方库吗？
A: 通常不需要。第三方库在 `third-party/` 目录下，除非你修改了它们的构建配置。

### Q: 如何只重新编译某个特定的目标？
A: 使用以下命令：
```bash
cd build
cmake --build . --target torchcomms
# 或
make torchcomms
```

### Q: 清理后重新构建需要多长时间？
A: 完全重新构建通常需要几分钟到十几分钟，取决于你的机器性能和项目大小。

## 针对当前 glog 错误的建议

由于你遇到了 glog 相关的编译错误，并且我们已经修改了：
- `CMakeLists.txt`
- `comms/torchcomms/TorchCommLogging.hpp`

**强烈建议使用完全清理的方法**：

```bash
# 从项目根目录执行
rm -rf build
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_INTEL_GPU=ON -DUSE_XCCL=ON
cmake --build . -j$(nproc) 2>&1 | tee build.log
```

最后一行命令会将构建输出保存到 `build.log` 文件中，方便查看错误信息。

