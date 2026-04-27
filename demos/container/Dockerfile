# =============================================================================
# agent-sbx container — Chainguard Wolfi-based sandboxed agent runtime
# =============================================================================
# Multi-stage build:
#   Stage 1 (builder): install tools, bake symlink farm with agent-sbx prepare
#   Stage 2 (landlock): build sbx-landlock Go helper
#   Stage 3 (runtime): minimal image with pre-baked sandbox artifacts
#
# Build:  docker build -t agent-sbx .
# Run:    docker run --rm -it --security-opt seccomp=seccomp-profile.json agent-sbx
# =============================================================================

# ── Stage 1: build sandbox artifacts ────────────────────────────────────────

FROM cgr.dev/chainguard/wolfi-base:latest AS builder

RUN apk add --no-cache \
    bash coreutils findutils grep sed gawk diffutils \
    git jq python3 bubblewrap

WORKDIR /app

# Copy sbx tool and config
COPY ../../sbx/sbx /usr/local/bin/sbx
COPY requisites.txt policy.toml ./

# Bake the sandbox artifacts
RUN chmod +x /usr/local/bin/sbx && agent-sbx prepare

# ── Stage 2: build sbx-landlock ─────────────────────────────────────────────

FROM cgr.dev/chainguard/go:latest AS landlock-builder

WORKDIR /src
COPY ../../sbx/sbx-landlock/ ./
RUN CGO_ENABLED=0 go build -o /sbx-landlock .

# ── Stage 3: runtime image ──────────────────────────────────────────────────

FROM cgr.dev/chainguard/wolfi-base:latest AS runtime

RUN apk add --no-cache \
    bash coreutils findutils grep sed gawk diffutils \
    git jq python3 bubblewrap

# Non-root user for defense-in-depth
RUN adduser -D -u 1000 agent
WORKDIR /app

# Copy pre-baked sandbox from builder
COPY --from=builder /app/.sandbox/ .sandbox/
COPY --from=builder /app/requisites.txt /app/policy.toml ./
COPY --from=landlock-builder /sbx-landlock /usr/local/bin/sbx-landlock
COPY ../../sbx/sbx /usr/local/bin/sbx
COPY ../../tests/ /app/tests/

RUN chmod +x /usr/local/bin/sbx /usr/local/bin/sbx-landlock

# Fix ownership
RUN chown -R agent:agent /app

USER agent

# agent-sbx elevate re-execs the shell under bwrap + Landlock
ENTRYPOINT ["sbx", "elevate"]
