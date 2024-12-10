# 使用最小基础镜像（Ubuntu）
FROM ubuntu:22.04

# 设置构建时的环境变量 PROVER_ID
ARG PROVER_ID

# 安装必要的依赖项
RUN apt-get update && apt-get install -y \
    build-essential \   # 构建工具
    pkg-config \        # pkg-config 工具
    libssl-dev \        # SSL 开发库
    git \               # Git
    curl \              # Curl
    protobuf-compiler \ # Protobuf 编译器
    cargo \             # Rust 包管理工具
    logrotate \         # 安装日志轮换工具
    && apt-get clean    # 清理缓存以减小镜像体积

# 安装 Rust（Nexus 节点所需）
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 设置 Rust 环境路径
ENV PATH="/root/.cargo/bin:${PATH}"

# 将构建时传递的 PROVER_ID 作为环境变量传递给容器
ENV PROVER_ID=${PROVER_ID}

# 配置日志轮换，限制日志文件大小，并设置定期清除
RUN echo "/var/log/*.log {" > /etc/logrotate.d/nexus-node && \
    echo "    size 10M" >> /etc/logrotate.d/nexus-node && \
    echo "    rotate 5" >> /etc/logrotate.d/nexus-node && \
    echo "    compress" >> /etc/logrotate.d/nexus-node && \
    echo "    missingok" >> /etc/logrotate.d/nexus-node && \
    echo "    notifempty" >> /etc/logrotate.d/nexus-node && \
    echo "    create 0644 root root" >> /etc/logrotate.d/nexus-node && \
    echo "}" >> /etc/logrotate.d/nexus-node

# 设置默认命令：运行 Nexus 节点安装脚本，并自动同意条款
CMD ["sh", "-c", "echo Y | curl https://cli.nexus.xyz/ | sh & tail -f /dev/null"]
