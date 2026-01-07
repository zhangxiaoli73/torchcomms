# pip 构建清理指南

## 问题说明

当使用 `pip install` 构建时，构建产物不在项目的 `build/` 目录中，而是在：
- 临时构建目录（通常在 `/tmp/pip-*` 或类似位置）
- Python 包安装目录（site-packages）
- 项目根目录的一些缓存文件

## 快速清理方法

### 方法 1: 使用提供的脚本（推荐）

```bash
chmod +x clean_pip_build.sh
./clean_pip_build.sh
```

### 方法 2: 手动清理步骤

```bash
# 1. 卸载已安装的包
pip uninstall -y torchcomms

# 2. 清理 Python 构建产物
rm -rf build/ dist/ *.egg-info .eggs/
find . -type f -name '*.pyc' -delete
find . -type d -name '__pycache__' -delete
find . -type f -name '*.so' -delete
find . -type f -name '*.o' -delete

# 3. 清理 CMake 缓存
rm -rf CMakeFiles/ CMakeCache.txt cmake_install.cmake Makefile

# 4. 清理 pip 缓存
pip cache remove torchcomms

# 5. 设置环境变量
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1
export TEST_BACKEND=xccl
export TEST_DEVICE=xpu
export GLOG_minloglevel=0
export GLOG_logtostderr=1

# 6. 加载 Intel oneAPI 环境
source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

# 7. 重新构建和安装
pip install --no-build-isolation -v . 2>&1 | tee pip_build.log
```

## 详细说明

### 为什么没有 build 目录？

使用 `pip install` 时：
- pip 会在临时目录创建构建环境
- 构建完成后，临时目录会被清理
- 只有编译好的 `.so` 文件会被安装到 Python 的 site-packages

### 如何查看构建过程？

```bash
# 使用 -v 参数查看详细输出
pip install --no-build-isolation -v .

# 保存构建日志
pip install --no-build-isolation -v . 2>&1 | tee build.log
```

### 如何保留构建目录进行调试？

如果你想保留构建目录以便调试，可以使用：

```bash
# 方法 1: 使用 pip install -e (editable mode)
pip install --no-build-isolation -v -e .

# 方法 2: 手动使用 setup.py
python setup.py build_ext --inplace

# 方法 3: 直接使用 CMake（不通过 pip）
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_INTEL_GPU=ON -DUSE_XCCL=ON
cmake --build . -j$(nproc)
```

## 针对 glog 错误的清理步骤

由于我们修改了：
- `CMakeLists.txt` - 添加了 `GLOG_NO_ABBREVIATED_SEVERITIES`
- `comms/torchcomms/TorchCommLogging.hpp` - 修改了 glog 包含方式

**必须完全清理后重新构建**：

```bash
# 完整的清理和重建流程
pip uninstall -y torchcomms
rm -rf build/ dist/ *.egg-info .eggs/
find . -type f -name '*.so' -delete
find . -type f -name '*.o' -delete
rm -rf CMakeFiles/ CMakeCache.txt

# 设置环境
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1
export TEST_BACKEND=xccl
export TEST_DEVICE=xpu
export GLOG_minloglevel=0
export GLOG_logtostderr=1

source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

# 重新构建
pip install --no-build-isolation -v . 2>&1 | tee pip_build.log
```

## 验证安装

```bash
# 检查包是否安装
pip list | grep torchcomms

# 检查安装位置
pip show torchcomms

# 测试导入
python -c "import torchcomms; print(torchcomms.__version__)"

# 检查编译的 .so 文件
python -c "import torchcomms; import os; print(os.path.dirname(torchcomms.__file__))"
ls -lh $(python -c "import torchcomms; import os; print(os.path.dirname(torchcomms.__file__))")
```

## 常见问题

### Q: pip install 后在哪里可以找到编译的文件？
A: 在 Python 的 site-packages 目录中：
```bash
python -c "import site; print(site.getsitepackages())"
```

### Q: 如何强制重新编译？
A: 先卸载，清理缓存，然后重新安装：
```bash
pip uninstall -y torchcomms
pip cache remove torchcomms
pip install --no-build-isolation -v --force-reinstall --no-cache-dir .
```

### Q: 构建失败后如何查看详细错误？
A: 查看保存的日志文件：
```bash
pip install --no-build-isolation -v . 2>&1 | tee build.log
# 然后查看 build.log 文件
less build.log
# 或搜索错误
grep -i error build.log
```

### Q: 如何只编译不安装？
A: 使用 setup.py：
```bash
python setup.py build_ext --inplace
```

## 调试技巧

### 查看 pip 使用的临时构建目录

```bash
# 在构建过程中，打开另一个终端
watch -n 1 'ls -lh /tmp/pip-* 2>/dev/null'
```

### 保留临时构建目录

```bash
# 设置环境变量保留临时目录
export TMPDIR=/tmp/my-pip-build
mkdir -p $TMPDIR
pip install --no-build-isolation -v .
# 构建失败后，可以在 /tmp/my-pip-build 中查看
```

### 使用 editable 模式进行开发

```bash
# 安装为可编辑模式，修改代码后无需重新安装
pip install --no-build-isolation -v -e .
```

## 推荐的开发工作流

```bash
# 1. 首次安装
pip install --no-build-isolation -v -e .

# 2. 修改代码后
# 如果只修改了 Python 代码，无需重新编译
# 如果修改了 C++ 代码或 CMakeLists.txt：
pip uninstall -y torchcomms
rm -rf build/ *.egg-info
pip install --no-build-isolation -v -e .

# 3. 测试
python -m pytest tests/
```

