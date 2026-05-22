# Graphify 一键安装脚本
# 用法: .\setup-graphify.ps1 [项目路径]
# 默认使用当前目录

param(
    [string]$ProjectPath = "."
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path $ProjectPath
$HookDir = Join-Path $ProjectRoot ".git" "hooks"
$ClaudeMdPath = Join-Path $ProjectRoot "CLAUDE.md"
$TemplatePath = Join-Path $PSScriptRoot "CLAUDE.md.template"

Write-Host "====================================="
Write-Host "  Graphify 自动安装脚本"
Write-Host "  项目路径: $ProjectRoot"
Write-Host "====================================="
Write-Host ""

# --------------------------------------------------
# 第一步：检查/安装 graphify
# --------------------------------------------------
Write-Host "[1/5] 检查 graphify Python 包..." -ForegroundColor Cyan

$foundPython = $null
# uv
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $uvDir = (uv tool dir 2>$null).Trim()
    if ($uvDir) {
        $py = Join-Path $uvDir "graphifyy\Scripts\python.exe"
        if (Test-Path $py) {
            & $py -c "import graphify" 2>$null
            if ($LASTEXITCODE -eq 0) { $foundPython = $py }
        }
    }
}
# pipx
if (-not $foundPython -and (Get-Command pipx -ErrorAction SilentlyContinue)) {
    $venvs = (pipx environment --value PIPX_LOCAL_VENVS 2>$null).Trim()
    if ($venvs) {
        $py = Join-Path $venvs "graphifyy\Scripts\python.exe"
        if (Test-Path $py) {
            & $py -c "import graphify" 2>$null
            if ($LASTEXITCODE -eq 0) { $foundPython = $py }
        }
    }
}
# pip
if (-not $foundPython) {
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pyCmd) {
        & $pyCmd.Source -c "import graphify" 2>$null
        if ($LASTEXITCODE -eq 0) { $foundPython = (& $pyCmd.Source -c "import sys; print(sys.executable)").Trim() }
    }
}

if (-not $foundPython) {
    Write-Host "  未检测到 graphify，正在安装..." -ForegroundColor Yellow
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        uv tool install --upgrade graphifyy -q
    } elseif (Get-Command pipx -ErrorAction SilentlyContinue) {
        pipx install graphifyy -q
    } else {
        pip install graphifyy -q
    }
    Write-Host "  安装完成！" -ForegroundColor Green
} else {
    Write-Host "  ✓ graphify 已安装" -ForegroundColor Green
}

# --------------------------------------------------
# 第二步：安装/追加 CLAUDE.md 规则
# --------------------------------------------------
Write-Host ""
Write-Host "[2/5] 配置 CLAUDE.md 自动化规则..." -ForegroundColor Cyan

if (-not (Test-Path $ClaudeMdPath)) {
    Copy-Item $TemplatePath $ClaudeMdPath
    Write-Host "  ✓ 已创建 CLAUDE.md（从模板）" -ForegroundColor Green
} else {
    $existing = Get-Content $ClaudeMdPath -Raw
    if ($existing -match "Graphify 自动化规则") {
        Write-Host "  - CLAUDE.md 已有 Graphify 规则，跳过" -ForegroundColor Yellow
    } else {
        $template = Get-Content $TemplatePath -Raw
        Add-Content $ClaudeMdPath "`n$template"
        Write-Host "  ✓ 已将 Graphify 规则追加到 CLAUDE.md" -ForegroundColor Green
    }
}

# --------------------------------------------------
# 第三步：安装 git post-commit hook
# --------------------------------------------------
Write-Host ""
Write-Host "[3/5] 安装 git post-commit hook..." -ForegroundColor Cyan

if (Test-Path (Join-Path $ProjectRoot ".git")) {
    $hookFile = Join-Path $HookDir "post-commit"

    $hookContent = @'
#!/bin/sh
# Graphify auto-update hook
# 每次 commit 后自动重建图（仅代码文件，不消耗 LLM Token）

GRAPHIFY_OUT=".git/../graphify-out"
GRAPHIFY_PYTHON=""

# 检测 graphify Python 路径
if command -v uv >/dev/null 2>&1; then
    UV_DIR=$(uv tool dir 2>/dev/null)
    if [ -n "$UV_DIR" ] && [ -f "$UV_DIR/graphifyy/Scripts/python.exe" ]; then
        GRAPHIFY_PYTHON="$UV_DIR/graphifyy/Scripts/python.exe"
    fi
fi
if [ -z "$GRAPHIFY_PYTHON" ] && command -v pipx >/dev/null 2>&1; then
    VENVS=$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)
    if [ -n "$VENVS" ] && [ -f "$VENVS/graphifyy/Scripts/python.exe" ]; then
        GRAPHIFY_PYTHON="$VENVS/graphifyy/Scripts/python.exe"
    fi
fi
if [ -z "$GRAPHIFY_PYTHON" ]; then
    GRAPHIFY_PYTHON=$(command -v python 2>/dev/null)
fi

if [ -z "$GRAPHIFY_PYTHON" ]; then
    echo "[graphify] Python not found, skipping graph update"
    exit 0
fi

if [ ! -f "$GRAPHIFY_OUT/graph.json" ]; then
    echo "[graphify] No existing graph found, skipping"
    exit 0
fi

# 检测是否有代码文件变更
CHANGED_FILES=$(git diff-tree --no-commit-id -r HEAD --name-only --diff-filter=AM 2>/dev/null | grep -E '\.(py|ts|js|go|rs|java|cpp|c|rb|swift|kt|cs)$' || true)
if [ -n "$CHANGED_FILES" ]; then
    echo "[graphify] Code changes detected, rebuilding graph..."
    "$GRAPHIFY_PYTHON" -m graphify --update . --quiet 2>/dev/null || echo "[graphify] Update skipped (no graphifyy package?)"
fi
'@

    if (Test-Path $hookFile) {
        Write-Host "  - post-commit hook 已存在，追加 graphify 逻辑..." -ForegroundColor Yellow
        Add-Content $hookFile "`n# Graphify auto-update (added by setup-graphify.ps1)"
        Add-Content $hookFile $hookContent
    } else {
        Set-Content $hookFile $hookContent
        Write-Host "  ✓ 已创建 post-commit hook" -ForegroundColor Green
    }

    # Windows 上 git hook 不需要可执行权限，但 Cygwin/Git Bash 可能需要
    # 尝试设置可执行（在 Windows 上可能被忽略）
    try { & icacls $hookFile /grant "Everyone:RX" 2>$null } catch {}

    Write-Host "  ✓ Git hook 安装完成（每次 commit 后自动 AST 重建）" -ForegroundColor Green
} else {
    Write-Host "  - 未检测到 Git 仓库，跳过 hook 安装" -ForegroundColor Yellow
    Write-Host "  提示：运行 'git init' 后再执行此脚本，或手动安装 hook" -ForegroundColor Gray
}

# --------------------------------------------------
# 第四步：创建 graphify-out 目录
# --------------------------------------------------
Write-Host ""
Write-Host "[4/5] 创建 graphify-out 输出目录..." -ForegroundColor Cyan

$outDir = Join-Path $ProjectRoot "graphify-out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Write-Host "  ✓ 已创建 $outDir" -ForegroundColor Green

# --------------------------------------------------
# 第五步：可选 — 首次建图
# --------------------------------------------------
Write-Host ""
Write-Host "[5/5] 检查是否要首次建图..." -ForegroundColor Cyan

$graphFile = Join-Path $outDir "graph.json"
if (-not (Test-Path $graphFile)) {
    Write-Host "  未检测到现有图。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  是否现在对项目进行首次建图？" -ForegroundColor White
    Write-Host "  [Y] 是 — 立即建图（消耗 Token 但后续可节省）" -ForegroundColor Green
    Write-Host "  [N] 否 — 稍后手动运行 /graphify" -ForegroundColor Gray
    Write-Host "  [S] 跳过（小型项目自动建图）" -ForegroundColor Gray

    $choice = Read-Host "  请选择 (Y/N/S)"

    if ($choice -eq "Y" -or $choice -eq "y") {
        Write-Host "  正在建图..." -ForegroundColor Yellow
        # 这里会由 Claude Code 处理，不在脚本中直接运行
        Write-Host "  请在 Claude Code 中运行 /graphify 来完成建图" -ForegroundColor Cyan
    } elseif ($choice -eq "S" -or $choice -eq "s") {
        # 在 CLAUDE.md 中加入标记，让 Claude 自动建图
        $autoBuildMarker = "`n# graphify-auto: auto-build-on-init`n# 小型项目标记 - 下次 Claude 会话自动建图"
        Add-Content $ClaudeMdPath $autoBuildMarker
        Write-Host "  ✓ 已标记为自动建图，下次 Claude 会话将自动处理" -ForegroundColor Green
    } else {
        Write-Host "  - 跳过建图，可随时运行 /graphify 手动建图" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✓ 已有图文件 $graphFile" -ForegroundColor Green
    Write-Host "  提示：增量更新请运行 /graphify . --update" -ForegroundColor Gray
}

# --------------------------------------------------
# 完成
# --------------------------------------------------
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Graphify 安装完成！" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  已安装的项目: $ProjectRoot" -ForegroundColor White
Write-Host ""
Write-Host "  快速开始："
Write-Host "    1. 在 Claude Code 中打开此项目"
Write-Host "    2. 运行 /graphify 建图（如果尚未建图）"
Write-Host "    3. 之后 Claude 会自动查图回答架构问题"
Write-Host ""
Write-Host "  常用命令："
Write-Host "    /graphify                    - 建图"
Write-Host "    /graphify . --update         - 增量更新"
Write-Host "    /graphify . --watch          - 启动文件监听"
Write-Host "    /graphify query "问题"       - 查询图"
Write-Host "    /graphify path "A" "B"       - 查找概念路径"
Write-Host ""
Write-Host "  更多信息请查看 README.md"
Write-Host ""
