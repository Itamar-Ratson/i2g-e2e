# Docker-in-Docker base (required for KinD)
FROM docker:27-dind

ENV KIND_VERSION="v0.27.0"
ENV KUBECTL_VERSION="v1.32.0"
ENV GO_VERSION="1.23.4"
ENV BATS_VERSION="v1.11.1"

# Install packages
RUN apk add --no-cache bash curl git make ncurses jq

# Install Go
RUN curl -Lo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" && \
  tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

# Install kubectl
RUN curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
  chmod +x /usr/local/bin/kubectl

# Install KinD
RUN curl -Lo /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" && \
  chmod +x /usr/local/bin/kind

# Install BATS
RUN git clone --depth 1 --branch ${BATS_VERSION} https://github.com/bats-core/bats-core.git /tmp/bats && \
  /tmp/bats/install.sh /usr/local && rm -rf /tmp/bats

WORKDIR /workspace

# Clone ingress2gateway
RUN git clone --depth 1 https://github.com/kubernetes-sigs/ingress2gateway.git

# Clone user's e2e test repo
RUN git clone --depth 1 https://github.com/Itamar-Ratson/i2g-e2e.git

# Build ingress2gateway
RUN cd ingress2gateway && go build -o /usr/local/bin/ingress2gateway .

# Pre-download manifests to speed up first start
RUN mkdir -p /opt/manifests && \
  curl -sLo /opt/manifests/gateway-api.yaml https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml && \
  curl -sLo /opt/manifests/envoy-gateway.yaml https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
