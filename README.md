# Graphify Auto Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Graphify Auto Setup** 是一个开箱即用的模板工具，让你在 Claude Code 中自动使用知识图谱节省 Token。

## 它能做什么

只需运行一条命令，你的项目就会获得：

| 功能 | 说明 |
|------|------|
| **自动建图** | 进入新项目时自动评估并构建知识图谱（小型直接建，大型询问你） |
| **自动查图** | 回答架构问题时自动查图，不再重复读取源文件 |
| **Git Hook** | 每次 `git commit` 后自动重建图（代码变更 0 Token 消耗） |
| **文件监听** | 代码变更自动 AST 重建，无需 LLM 参与 |

## 效果对比

| 场景 | 无 Graphify | 用 Graphify |
|------|:-----------:|:-----------:|
| 首次理解项目 | 全部读取（几千~几十万 Token） | 一次性建图，后续 0 Token |
| "A 模块和 B 模块什么关系？" | 重新读取相关文件 | 图查询，几十 Token |
| 改了几个文件 | 重新全量读取 | 增量更新，只处理变更 |
| 跨会话提问 | 每次都重读 | graph.json 持久化，直接查 |

## 使用方法

### 方式一：快速开始（推荐）

```powershell
# 将此仓库克隆到你的项目根目录
cd 你的项目目录
git clone https://github.com/Cheng-Jing1/graphify-auto-setup.git .graphify-setup

# 运行一键安装
powershell -ExecutionPolicy Bypass -File ".graphify-setup\setup-graphify.ps1"

# 清理安装文件（可选）
rm -rf .graphify-setup
```

### 方式二：手动集成

1. 将 `CLAUDE.md.template` 的内容复制到你的项目 `CLAUDE.md` 中
2. 安装 Graphify：`pip install graphifyy` 或 `uv tool install graphifyy`
3. 运行 `/graphify` 建图
4. 安装 post-commit hook（见 `setup-graphify.ps1`）

### 方式三：作为子模块

```bash
git submodule add https://github.com/Cheng-Jing1/graphify-auto-setup.git .graphify-setup
git submodule update --init
powershell -ExecutionPolicy Bypass -File ".graphify-setup\setup-graphify.ps1"
```

## 前置条件

- [Claude Code](https://claude.ai/code) 已安装
- Python 3.9+（安装 Graphify 用）
- Git（安装 hook 用）
- 操作系统：Windows（PowerShell）/ macOS / Linux

## 文件结构

```
graphify-auto-setup/
├── CLAUDE.md.template     # → 复制到项目 CLAUDE.md
├── setup-graphify.ps1     # → 一键安装脚本
├── README.md              # 本文件
└── .gitignore
```

## 安装后的效果

安装完成后，在你的 Claude Code 会话中：

1. **第一次打开项目** → 自动检测项目大小，小项目直接建图，大项目询问你
2. **日常开发中** → 修改代码后 commit，git hook 自动更新图
3. **问架构问题** → "这个项目的模块依赖是什么？" → 自动查图回答
4. **长期使用** → graph.json 持久化，跨会话复用，Token 持续节省

## 常见问题

### Q: 建图消耗多少 Token？
首次建图取决于文件数量。对于一个 100 文件的项目，大约需要 10,000-30,000 Token 的语义提取。后续查询每个问题只需要几十到几百 Token。

### Q: 纯代码修改为什么要 0 Token？
因为代码文件的结构提取（导入、函数调用、类继承）通过 AST 解析完成，不需要 LLM 参与。

### Q: 只对 Claude Code 有效吗？
是的。CLAUDE.md 规则只对 Claude Code 生效。其他 AI 工具不会自动执行这些规则。

### Q: 可以团队共享吗？
可以。把 `CLAUDE.md.template` 的规则写入项目根目录的 `CLAUDE.md`，提交到 Git 仓库后，整个团队的 Claude Code 都会自动使用图。

## 许可

MIT License
