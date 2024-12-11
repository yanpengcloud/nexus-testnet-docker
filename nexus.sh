#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # 无色

# 设置变量
NEXUS_HOME="$HOME/.nexus"
PROVER_ID_FILE="$NEXUS_HOME/prover-id"
SESSION_NAME="nexus-prover"
PROGRAM_DIR="$NEXUS_HOME/src/generated"
ARCH=$(uname -m)  # 获取系统架构
OS=$(uname -s)  # 获取操作系统类型
REPO_BASE="https://github.com/nexus-xyz/network-api/raw/refs/tags/0.4.2/clients/cli"  # GitHub 仓库地址

# 检查 OpenSSL 版本
check_openssl_version() {
    # 仅在 Linux 系统下检查 OpenSSL 版本
    if [ "$OS" = "Linux" ]; then
        if ! command -v openssl &> /dev/null; then
            echo -e "${RED}未安装 OpenSSL${NC}"
            return 1
        fi

        local version=$(openssl version | cut -d' ' -f2)
        local major_version=$(echo $version | cut -d'.' -f1)

        # 检查 OpenSSL 版本是否小于 3
        if [ "$major_version" -lt "3" ]; then
            if command -v apt &> /dev/null; then
                echo -e "${YELLOW}当前 OpenSSL 版本过低，正在升级...${NC}"
                sudo apt update
                sudo apt install -y openssl
                if [ $? -ne 0 ]; then
                    echo -e "${RED}OpenSSL 升级失败，请手动升级至 3.0 或更高版本${NC}"
                    return 1
                fi
            elif command -v yum &> /dev/null; then
                echo -e "${YELLOW}当前 OpenSSL 版本过低，正在升级...${NC}"
                sudo yum update -y openssl
                if [ $? -ne 0 ]; then
                    echo -e "${RED}OpenSSL 升级失败，请手动升级至 3.0 或更高版本${NC}"
                    return 1
                fi
            else
                echo -e "${RED}请手动升级 OpenSSL 至 3.0 或更高版本${NC}"
                return 1
            fi
        fi
        echo -e "${GREEN}OpenSSL 版本检查通过${NC}"
    fi
    return 0
}

# 设置程序目录
setup_directories() {
    mkdir -p "$PROGRAM_DIR"
    ln -sf "$PROGRAM_DIR" "$NEXUS_HOME/src/generated"
}

# 检查依赖
check_dependencies() {
    # 检查 OpenSSL
    check_openssl_version || exit 1

    # 检查 tmux 是否安装
    if ! command -v tmux &> /dev/null; then
        echo -e "${YELLOW}tmux 未安装, 正在安装...${NC}"
        if [ "$OS" = "Darwin" ]; then
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}请先安装 Homebrew: https://brew.sh${NC}"
                exit 1
            fi
            brew install tmux
        elif [ "$OS" = "Linux" ]; then
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y tmux
            elif command -v yum &> /dev/null; then
                sudo yum install -y tmux
            else
                echo -e "${RED}未能识别的包管理器，请手动安装 tmux${NC}"
                exit 1
            fi
        fi
    fi
}

# 下载程序文件
download_program_files() {
    local files="cancer-diagnostic fast-fib"

    # 下载程序文件列表中的每一个文件
    for file in $files; do
        local target_path="$PROGRAM_DIR/$file"
        if [ ! -f "$target_path" ]; then
            echo -e "${YELLOW}下载 $file...${NC}"
            curl -L "$REPO_BASE/src/generated/$file" -o "$target_path"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}$file 下载完成${NC}"
                chmod +x "$target_path"
            else
                echo -e "${RED}$file 下载失败${NC}"
            fi
        fi
    done
}

# 下载 Prover 文件
download_prover() {
    local prover_path="$NEXUS_HOME/prover"
    if [ ! -f "$prover_path" ]; then
        # 根据操作系统和架构选择下载的 Prover 文件
        if [ "$OS" = "Darwin" ]; then
            if [ "$ARCH" = "x86_64" ]; then
                echo -e "${YELLOW}下载 macOS Intel 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-macos-amd64" -o "$prover_path"
            elif [ "$ARCH" = "arm64" ]; then
                echo -e "${YELLOW}下载 macOS ARM64 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-arm64" -o "$prover_path"
            else
                echo -e "${RED}不支持的 macOS 架构: $ARCH${NC}"
                exit 1
            fi
        elif [ "$OS" = "Linux" ]; then
            if [ "$ARCH" = "x86_64" ]; then
                echo -e "${YELLOW}下载 Linux AMD64 架构 Prover...${NC}"
                curl -L "https://github.com/qzz0518/nexus-run/releases/download/v0.4.2/prover-amd64" -o "$prover_path"
            else
                echo -e "${RED}不支持的 Linux 架构: $ARCH${NC}"
                exit 1
            fi
        else
            echo -e "${RED}不支持的操作系统: $OS${NC}"
            exit 1
        fi
        chmod +x "$prover_path"
        echo -e "${GREEN}Prover 下载完成${NC}"
    fi
}

# 下载所有需要的文件
download_files() {
    download_prover
    download_program_files
}

# 启动 Prover
start_prover() {
    # 检查 Prover 是否已经在运行
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Prover 已在运行中，请选择2查看运行日志${NC}"
        return
    fi

    cd "$NEXUS_HOME" || exit

    # 检查 Prover ID 是否存在
    if [ ! -f "$PROVER_ID_FILE" ]; then
        echo -e "${YELLOW}请输入您的 Prover ID${NC}"
        read -p "Prover ID > " input_id

        if [ -n "$input_id" ]; then
            echo "$input_id" > "$PROVER_ID_FILE"
            echo -e "${GREEN}已保存 Prover ID: $input_id${NC}"
        else
            echo -e "${RED}Prover ID 不能为空，请重新输入${NC}"
            exit 1
        fi
    fi

    # 使用 tmux 启动 Prover 会话
    tmux new-session -d -s "$SESSION_NAME" "cd '$NEXUS_HOME' && ./prover beta.orchestrator.nexus.xyz"
    echo -e "${GREEN}Prover 已启动，选择2可查看运行日志${NC}"
}

# 主菜单，只保留安装并启动功能
echo -e "\n${YELLOW}=== Nexus Prover 安装与启动 ===${NC}"
echo "1. 安装并启动 Nexus"

read -p "请选择操作 [1]: " choice
if [ "$choice" -eq 1 ]; then
    setup_directories
    check_dependencies
    download_files
    start_prover
else
    echo -e "${RED}无效的选择${NC}"
    exit 1
fi
