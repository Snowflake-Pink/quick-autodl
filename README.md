# Quick AutoDL

AutoDL/云主机一键初始化脚本。完成 conda 初始化、缓存与环境目录重定向、镜像加速（仅 conda/pip）、以及 GNU screen 的 UTF-8 编码修复。

## 功能

- **缓存与目录重定向**：将 `~/.cache`、conda 的 `envs` 与 `pkgs` 迁移至 `/root/autodl-tmp` 下，节省系统盘并提高 I/O 性能。
- **Shell 环境注入**：向 `~/.bashrc`、`~/.zshrc` 追加必要的环境变量（`XDG_CACHE_HOME`、`CONDA_ENVS_DIRS`、`CONDA_PKGS_DIRS`）。
- **conda 初始化**：检测并执行 `conda init`（bash、zsh）。
- **镜像加速（chsrc）**：自动安装 `chsrc`，仅切换 conda 与 pip 的镜像源。
- **screen 编码修复**：向 `~/.screenrc` 追加 UTF-8 设置，避免乱码：
  - `defutf8 on`
  - `defencoding utf8`
  - `encoding UTF-8 UTF-8`

## 一键使用

需要 root 权限执行（脚本会检测），执行完毕后请关闭并重新打开终端。

镜像：

```bash
curl -fsSL https://raw.gitmirror.com/Snowflake-Pink/quick-autodl/main/quick-autodl.sh -o /tmp/quick-autodl.sh \
  && sudo bash /tmp/quick-autodl.sh -y
```

或：

```bash
curl -fsSL https://raw.githubusercontent.com/Snowflake-Pink/quick-autodl/main/quick-autodl.sh -o /tmp/quick-autodl.sh \
  && sudo bash /tmp/quick-autodl.sh -y
```

## 手动使用

1. 克隆仓库（或手动下载脚本）：
   ```bash
   git clone https://github.com/Snowflake-Pink/quick-autodl
   cd quick-autodl
   ```
2. 以 root 执行脚本（可加 `-y` 跳过确认）：
   ```bash
   sudo bash quick-autodl.sh -y
   ```

## 注意

- 运行完成后请新开一个终端，使环境变量与初始化生效。

## Thanks

* [chsrc](https://github.com/RubyMetric/chsrc)
