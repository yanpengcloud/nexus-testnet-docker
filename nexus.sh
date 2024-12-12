#!/bin/bash

# 定义颜色变量，用于输出不同颜色的提示信息
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # 关闭颜色格式

# 设置一些环境变量和目录路径
NEXUS_HOME="$HOME/.nexus"
PROVER_ID_FILE="$NEXUS_HOME/prover-id"
SESSION_NAME="nexus-prover"
PROGRAM_DIR="$NEXUS_HOME/src/generated"
ARCH=$(uname -m)  # 获取当前架构（如 x86_64）
OS=$(uname -s)    # 获取操作系统（如 Linux 或 Darwin）
REPO_BASE="https://github.com/nexus-xyz/network-api/raw/refs/tags/0.4.2/clients/cli"

# 确保 NEXUS_HOME 目录存在
mkdir -p "$NEXUS_HOME"  # 创建 Nexus 目录

# 检查curl是否安装
check_curl_installed() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl 未安装，请安装curl后再运行脚本${NC}"
        exit 1
    fi
}

# 检查OpenSSL版本（仅适用于Linux）
check_openssl_version() {
    if [ "$OS" = "Linux" ]; then
        if ! command -v openssl &> /dev/null; then
            echo -e "${RED}未安装 OpenSSL${NC}"
            return 1
        fi

        local version=$(openssl version | cut -d' ' -f2)
        local major_version=$(echo $version | cut -d'.' -f1)

        # 如果OpenSSL版本低于3，尝试升级
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

# 设置所需的目录
setup_directories() {
    mkdir -p "$PROGRAM_DIR"  # 创建程序目录
    ln -sf "$PROGRAM_DIR" "$NEXUS_HOME/src/generated"  # 创建符号链接
}

# 检查依赖项（包括OpenSSL和tmux）
check_dependencies() {
    check_curl_installed   # 检查curl是否安装
    check_openssl_version || exit 1  # 检查OpenSSL版本

    # 如果tmux未安装，尝试安装tmux
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

# 下载必要的程序文件
download_program_files() {
    local files="cancer-diagnostic fast-fib"

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

# 下载Prover文件
download_prover() {
    local prover_path="$NEXUS_HOME/prover"
    if [ ! -f "$prover_path" ]; then
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

# 启动Prover
start_prover() {
    # 检查是否已在tmux会话中运行
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Prover 已在运行中，请选择 2 查看运行日志${NC}"
        return
    fi

    cd "$NEXUS_HOME" || exit

    # 检查Prover ID文件是否存在，如果不存在则要求用户输入Prover ID
    cp $HOME/nexus/prover-id $HOME/.nexus/prover-id
    if [ ! -f "$PROVER_ID_FILE" ]; then
        echo -e "${YELLOW}请输入您的 Prover ID${NC}"
        echo -e "${YELLOW}如果您还没有 Prover ID，直接按回车将自动生成${NC}"
        read -p "Prover ID > " input_id

        if [ -n "$input_id" ]; then
            echo "$input_id" > "$PROVER_ID_FILE"
            echo -e "${GREEN}已保存 Prover ID: $input_id${NC}"
        else
            echo -e "${YELLOW}将自动生成新的 Prover ID...${NC}"
        fi
    fi

    # 启动tmux会话并运行Prover
    tmux new-session -d -s "nexus-node-1" "cd '$NEXUS_HOME' && ./prover beta.orchestrator.nexus.xyz"
    echo -e "${GREEN}Prover 已启动，运行：tmux attach-session -t "nexus-prover 查看日志"${NC}"
}


# 主流程
check_dependencies
setup_directories
download_files
start_prover
