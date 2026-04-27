# =============================================================================
# agent-sbx Coder workspace — Chainguard Wolfi-based sandboxed agent runtime
# =============================================================================
# Single-stage build. Sandbox artifacts are prepared at workspace startup
# via the Coder agent startup_script, not baked at image build time.
#
# Build context is ../.. (repo root) — set by main.tf docker_image resource.
# =============================================================================

FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache \
    bash coreutils findutils grep sed gawk diffutils \
    git jq python3 bubblewrap curl

# Non-root user for defense-in-depth
RUN adduser -D -u 1000 agent

WORKDIR /home/agent

# Copy agent-sbx tool
COPY agent-sbx/agent-sbx /usr/local/bin/agent-sbx
RUN chmod +x /usr/local/bin/agent-sbx

# Copy policy and requisites
COPY demos/coder/policy.toml demos/coder/requisites.txt ./

# Copy test suite for verification
COPY tests/ /home/agent/tests/

# Fix ownership
RUN chown -R agent:agent /home/agent

USER agent
