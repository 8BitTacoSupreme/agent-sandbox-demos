# Coder workspace template — sandboxed AI agent environment
#
# Provisions a Docker-based workspace with agent-sbx baked in.
# The startup script runs `agent-sbx prepare` so the sandbox is ready
# before the agent's first command.
#
# Usage:
#   coder template push demos/coder
#   coder create sandbox-test --template demos/coder
#   coder ssh sandbox-test

terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "coder" {}
provider "docker" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  startup_script = <<-EOT
    # Prepare sandbox artifacts on workspace start
    agent-sbx prepare
  EOT

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
  }
}

resource "docker_image" "workspace" {
  name = "agent-sbx-coder:latest"

  build {
    context    = "../.."
    dockerfile = "demos/coder/Dockerfile"
  }
}

resource "docker_container" "workspace" {
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image = docker_image.workspace.image_id

  # Security posture: drop everything, add only what bwrap needs
  capabilities {
    add  = ["SYS_ADMIN"]
    drop = ["ALL"]
  }

  read_only = true

  # Writable scratch space
  tmpfs = {
    "/tmp" = "size=100M,noexec,nosuid"
  }

  # Inject Coder agent
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  command = [
    "sh", "-c",
    coder_agent.main.init_script,
  ]

  volumes {
    host_path      = ""
    container_path = "/home/agent/workspace"
  }
}

resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
}
