FROM docker:27-dind

# ARG allows you to pass your repo URL during build time
ARG MY_TEST_REPO_URL

# Install dependencies (Go, Git, Make, Bash, Curl, Tools for compilation)
RUN apk add --no-cache \
  go \
  git \
  make \
  bash \
  curl \
  ncurses \
  build-base \
  openssl

# --- TOOL INSTALLATION ---

# 1. Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
  chmod +x kubectl && \
  mv kubectl /usr/local/bin/

# 2. Install KinD
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64 && \
  chmod +x ./kind && \
  mv ./kind /usr/local/bin/kind

# 3. Install BATS
RUN git clone https://github.com/bats-core/bats-core.git && \
  cd bats-core && \
  ./install.sh /usr/local

# --- PROJECT SETUP ---

WORKDIR /workspace

# 4. Clone ingress2gateway (Upstream) - Depth 1
RUN git clone --depth 1 https://github.com/kubernetes-sigs/ingress2gateway.git

# 5. Build ingress2gateway and set PATH
WORKDIR /workspace/ingress2gateway
RUN make build
ENV PATH="/workspace/ingress2gateway:${PATH}"
ENV PATH="/workspace/ingress2gateway/bin:${PATH}"

# 6. Clone YOUR Test Repo
WORKDIR /workspace
RUN if [ -z "$MY_TEST_REPO_URL" ]; then \
  echo "WARNING: No test repo provided via --build-arg"; \
  else \
  git clone "$MY_TEST_REPO_URL" my-tests; \
  fi
