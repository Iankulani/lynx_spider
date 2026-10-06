# ============================================
# LYNX-SPIDER-V1 - Dockerfile
# Multi-stage build for optimal image size
# ============================================

# ============ STAGE 1: BUILDER ============
FROM python:3.11-slim-bookworm AS builder

LABEL maintainer="Ian Carter Kulani"
LABEL description="LYNX-SPIDER-V1 Cybersecurity Platform - Builder"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    libffi-dev \
    libssl-dev \
    libpcap-dev \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r /tmp/requirements.txt

# ============ STAGE 2: RUNTIME ============
FROM python:3.11-slim-bookworm AS runtime

LABEL maintainer="Ian Carter Kulani"
LABEL description="LYNX-SPIDER-V1 Cybersecurity Platform"
LABEL version="1.0.0"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PATH="/opt/venv/bin:$PATH" \
    LYNX_HOME=/app \
    LYNX_CONFIG_DIR=/app/.lynx_spider \
    LYNX_LOG_LEVEL=INFO \
    TZ=UTC

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Network tools
    iputils-ping \
    traceroute \
    nmap \
    netcat-openbsd \
    curl \
    wget \
    dnsutils \
    whois \
    net-tools \
    iproute2 \
    tcpdump \
    # Web tools
    nikto \
    whatweb \
    # SSH
    openssh-client \
    # Security tools
    hashcat \
    john \
    # Utilities
    bash \
    ca-certificates \
    tzdata \
    locales \
    procps \
    htop \
    vim \
    less \
    jq \
    git \
    # Libraries
    libpcap0.8 \
    libssl3 \
    libffi8 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create non-root user (optional - can run as root for network operations)
RUN groupadd -r lynx && useradd -r -g lynx -m -s /bin/bash lynx

# Create application directories
RUN mkdir -p /app/.lynx_spider/{payloads,workspaces,scans,reports,phishing_pages,phishing_templates,captured_credentials,ssh_keys,traffic_logs,nikto_results,web_templates,sessions,spear_phishing,email_templates,dos_logs,agents,c2_logs,modules,network_monitor,keylog_exfil,deployments,domain_hosting,cracking,docker_scans,reverse_engineering,metasploit,payload_generation,web_charts} \
    && mkdir -p /app/lynx_spider_reports \
    && mkdir -p /var/log/lynx_spider \
    && chown -R lynx:lynx /app /var/log/lynx_spider

# Set working directory
WORKDIR /app

# Copy application files
COPY --chown=lynx:lynx lynx_spider.py /app/
COPY --chown=lynx:lynx requirements.txt /app/
COPY --chown=lynx:lynx config/ /app/config/ 2>/dev/null || true
COPY --chown=lynx:lynx docker/ /app/docker/ 2>/dev/null || true

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
# 5000 - Web Dashboard
# 8080 - Phishing Server
# 8000-9000 - Domain Hosting
# 9090 - Prometheus Metrics
EXPOSE 5000 8080 8000-9000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/stats || exit 1

# Volume for persistent data
VOLUME ["/app/.lynx_spider", "/app/lynx_spider_reports", "/var/log/lynx_spider"]

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "-u", "lynx_spider.py"]
