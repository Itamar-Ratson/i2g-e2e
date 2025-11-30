FROM docker:27-dind

# ARG allows you to pass your repo URL during build time
ARG MY_TEST_REPO_URL

# Define the required Go version
ENV GO_VERSION 1.24.1

# Install dependencies needed by the project AND for Go installation
RUN apk add --no-cache \
  git \
  make \
  bash \
  curl \
  ncurses \
  build-base \
  openssl

# Manually install the required Go version (1.24.0 or greater)
RUN curl -LO https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
  tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
  rm go${GO_VERSION}.linux-amd64.tar.gz

# Update the PATH to include the new Go installation
ENV PATH="/usr/local/go/bin:${PATH}"

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

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the custom entrypoint
ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
