# Kubernetes demo — deploy sandboxed agents on K8s

Deploy a sandboxed AI agent workspace as a Kubernetes pod with defense-in-depth:
Pod SecurityContext, NetworkPolicy, seccomp, bwrap, Landlock, and sbx shell enforcement.

## Prerequisites

- Kubernetes 1.25+ cluster
- `kubectl` configured
- Container image built and available (see `demos/container/`)
- seccomp profile installed on nodes (see below)

## Quick start

```bash
# Build and push the image first
cd demos/container
docker build -t your-registry/sbx-agent:latest -f Dockerfile ../..
docker push your-registry/sbx-agent:latest

# Update the image reference in deployment.yaml, then:
kubectl apply -k demos/kubernetes/
```

## Install seccomp profile

The seccomp profile must be installed on each node at the path referenced
in the Deployment's `seccompProfile.localhostProfile`. The default path is
`profiles/sbx-seccomp.json` relative to the kubelet's seccomp root
(typically `/var/lib/kubelet/seccomp/`).

```bash
# On each node (or via DaemonSet):
sudo mkdir -p /var/lib/kubelet/seccomp/profiles
sudo cp seccomp-profile.json /var/lib/kubelet/seccomp/profiles/sbx-seccomp.json
```

## Verify

```bash
kubectl exec -it deploy/sbx-agent -- bash tests/verify.sh
```

## Platform compatibility

| Platform | bwrap | Landlock FS | Landlock Net | Notes |
|----------|-------|-------------|-------------|-------|
| **GKE Autopilot** | Yes | Yes (COS 109+) | No (kernel < 6.7) | Unprivileged userns enabled by default |
| **GKE Standard** | Yes | Yes | Kernel-dependent | Full control over node OS |
| **EKS EC2** | Yes | Yes (AL2023) | Kernel-dependent | Custom seccomp profile required |
| **EKS Fargate** | No | No (kernel 5.10) | No | Shell-only enforcement |
| **AKS** | Yes | Yes (kernel 5.15+) | Kernel-dependent | Ubuntu nodes recommended |
| **kind / minikube** | Yes | Host kernel-dependent | Host kernel-dependent | Good for local testing |

## What's in the manifests

### deployment.yaml

- `runAsNonRoot: true` / `runAsUser: 1000` — agent never runs as root
- `readOnlyRootFilesystem: true` — container root is immutable
- `allowPrivilegeEscalation: false` — cannot gain new privileges
- `capabilities: drop ALL, add SYS_ADMIN` — minimal caps for bwrap
- `seccompProfile: Localhost` — custom syscall allowlist
- `emptyDir` volumes for workspace (5Gi) and /tmp (1Gi) with size limits
- Resource limits: 2 CPU, 2Gi memory, 5Gi ephemeral storage

### networkpolicy.yaml

- Default deny all ingress and egress
- Allow DNS (UDP/TCP 53) for name resolution
- Optional: separate policy for `network=unrestricted` mode (label-selected)

### configmap.yaml

- `policy.toml` and `requisites.txt` as ConfigMap data
- Mounted read-only into the pod

### kustomization.yaml

- Ties all manifests together for `kubectl apply -k`

## Customization

**Change the policy**: Edit `configmap.yaml` and re-apply.

**Allow network egress**: Add `sbx-network: unrestricted` label to the pod
and apply the second NetworkPolicy in `networkpolicy.yaml`.

**Use a different image registry**: Update `deployment.yaml` image field.

**Adjust resources**: Edit the `resources` section in `deployment.yaml`.
