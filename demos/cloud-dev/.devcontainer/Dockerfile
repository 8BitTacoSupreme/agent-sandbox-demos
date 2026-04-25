# Devcontainer for Codespaces / Gitpod — extends the sbx container image
# with dev tooling for a comfortable editing experience.

FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache \
    bash coreutils findutils grep sed gawk diffutils \
    git jq python3 bubblewrap \
    vim less

# Non-root user
RUN adduser -D -u 1000 agent

WORKDIR /app

# Copy sbx tool
COPY sbx/sbx /usr/local/bin/sbx
COPY sbx/sbx-landlock/ /tmp/sbx-landlock-src/

# Copy demo config
COPY demos/cloud-dev/requisites.txt demos/cloud-dev/policy.toml ./

# Copy tests for verification
COPY tests/ /app/tests/

RUN chmod +x /usr/local/bin/sbx && \
    chown -R agent:agent /app

USER agent
