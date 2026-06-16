#!/bin/bash
# Install Wywy-CI-CD — bare-metal Go + Astro test orchestration service.
# Idempotent: safe to re-run. Existing state is never damaged.
set -euo pipefail

# Self-elevate: re-exec with sudo if not already root.
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

CONTROL_DIR="${CONTROL_DIR:-/etc/Wywy-Website-Control}"
REPO_DIR="/usr/local/Wywy-Website/Wywy-CI"
LOG_DIR="/var/log/Wywy-Website/ci-cd/runs"
DATA_DIR="/var/lib/Wywy-Website/ci-cd"
WYWY_CODES_ASTRO="/usr/local/Wywy-Website/Wywy-Codes/apps/astro"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
GID=2523
GO_VERSION="1.24.0"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"

echo "=== Wywy-CI-CD Installation ==="

# ── 1. Environment ──────────────────────────────────────────────────
set -a
source "$CONTROL_DIR/config/ci-cd/.env"
set +a

# ── 2. Go runtime (idempotent) ─────────────────────────────────────
# Determine target user's home (preserve SUDO_USER for .bashrc edits)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

if command -v go &>/dev/null; then
    echo "Go already installed: $(go version)"
else
    echo "Installing Go ${GO_VERSION}..."
    wget -q "https://go.dev/dl/${GO_TARBALL}" -O "/tmp/${GO_TARBALL}"
    tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
    rm -f "/tmp/${GO_TARBALL}"
    if ! grep -qxF 'export PATH=$PATH:/usr/local/go/bin' "${USER_HOME}/.bashrc"; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> "${USER_HOME}/.bashrc"
        echo "Added Go to PATH in ${USER_HOME}/.bashrc (run 'source ~/.bashrc' or open a new shell)"
    fi
    export PATH="$PATH:/usr/local/go/bin"
    echo "Go installed: $(go version)"
fi

# ── 3. Node.js ──────────────────────────────────────────────────────
# Under sudo, nvm-managed node is not on PATH. Search common locations.

find_node() {
    # 1. Already on PATH
    if command -v node &>/dev/null; then
        command -v node
        return 0
    fi
    # 2. nvm — check invoking user's home (preserved via SUDO_USER)
    local nvm_dir="${HOME}/.nvm/versions/node"
    if [ -n "${SUDO_USER:-}" ]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        nvm_dir="${user_home}/.nvm/versions/node"
    fi
    if [ -d "$nvm_dir" ]; then
        local latest
        latest=$(ls -1 "$nvm_dir" 2>/dev/null | sort -V | tail -1)
        if [ -n "$latest" ] && [ -x "${nvm_dir}/${latest}/bin/node" ]; then
            echo "${nvm_dir}/${latest}/bin/node"
            return 0
        fi
    fi
    # 3. Common system paths
    for p in /usr/local/bin/node /usr/bin/node /opt/node/bin/node; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

NODE_PATH=$(find_node)
if [ -z "$NODE_PATH" ]; then
    echo "ERROR: Node.js >= 18 not found. Install via nvm or apt before continuing." >&2
    echo "  nvm: nvm install 18 && nvm alias default 18" >&2
    echo "  apt: sudo apt-get install -y nodejs npm" >&2
    exit 1
fi

# Add node/npm directory to PATH for this script
NODE_BIN_DIR=$(dirname "$NODE_PATH")
export PATH="${NODE_BIN_DIR}:${PATH}"

NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "ERROR: Node.js >= 18 required. Found: $(node --version)" >&2
    exit 1
fi
echo "Node.js OK: $(node --version) (via ${NODE_PATH})"

# ── 4. Directories ─────────────────────────────────────────────────
echo "Creating directories..."
sudo mkdir -p "$REPO_DIR"
sudo mkdir -p "$LOG_DIR"
sudo mkdir -p "$DATA_DIR"

sudo chown "$USER_ID:$GID" "$REPO_DIR"
sudo chown "$USER_ID:$GID" "$LOG_DIR"
sudo chown "$USER_ID:$GID" "$DATA_DIR"

sudo chmod 750 "$REPO_DIR"
sudo chmod 750 "$LOG_DIR"
sudo chmod 750 "$DATA_DIR"

# ── 5. Go module (idempotent) ──────────────────────────────────────
cd "$REPO_DIR"

if [ ! -f go.mod ]; then
    echo "Initializing Go module..."
    go mod init wywy-website/ci-cd
else
    echo "Go module already initialized."
fi

echo "Installing Go dependencies..."
go mod tidy
go get modernc.org/sqlite@latest
go get github.com/coder/websocket@latest

echo "Go dependencies ready."

# ── 6. Astro project scaffolding (idempotent) ──────────────────────
ASTRO_DIR="$REPO_DIR/astro"

if [ ! -f "$ASTRO_DIR/package.json" ]; then
    echo "Scaffolding Astro project..."

    mkdir -p "$ASTRO_DIR/src"/{pages,styles,lib,components/{layout,ui,runs}}
    mkdir -p "$ASTRO_DIR/public"

    # package.json
    cat > "$ASTRO_DIR/package.json" << 'PKGJSON'
{
  "name": "wywy-ci-astro",
  "type": "module",
  "version": "0.0.0",
  "scripts": {
    "dev": "astro dev --port 3001",
    "build": "astro check && astro build",
    "preview": "astro preview"
  },
  "dependencies": {
    "@astrojs/react": "^4.0.0",
    "@radix-ui/react-slot": "^1.1.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "tailwind-merge": "^2.5.0"
  },
  "devDependencies": {
    "@astrojs/check": "^0.9.0",
    "@tailwindcss/vite": "^4.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "^5.0.0"
  }
}
PKGJSON

    # astro.config.mjs
    cat > "$ASTRO_DIR/astro.config.mjs" << 'ASTROCFG'
import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  output: "static",
  integrations: [react()],
  vite: {
    plugins: [tailwindcss()],
  },
});
ASTROCFG

    # tsconfig.json
    cat > "$ASTRO_DIR/tsconfig.json" << 'TSCONFIG'
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src"]
}
TSCONFIG

    # env.d.ts
    cat > "$ASTRO_DIR/src/env.d.ts" << 'ENVDTS'
/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_CI_API_HOST: string;
  readonly PUBLIC_CI_API_PORT: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
ENVDTS

    # src/styles/global.css — copy from Wywy-Codes
    if [ -f "$WYWY_CODES_ASTRO/src/styles/global.css" ]; then
        cp "$WYWY_CODES_ASTRO/src/styles/global.css" "$ASTRO_DIR/src/styles/global.css"
        echo "Copied global.css from Wywy-Codes."
    else
        cat > "$ASTRO_DIR/src/styles/global.css" << 'GLOBALCSS'
@import "tailwindcss";
GLOBALCSS
        echo "Wywy-Codes not found — created minimal global.css."
    fi

    # src/lib/utils.ts — copy from Wywy-Codes
    if [ -f "$WYWY_CODES_ASTRO/src/lib/utils.ts" ]; then
        cp "$WYWY_CODES_ASTRO/src/lib/utils.ts" "$ASTRO_DIR/src/lib/utils.ts"
        echo "Copied utils.ts from Wywy-Codes."
    else
        cat > "$ASTRO_DIR/src/lib/utils.ts" << 'UTILSTS'
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
UTILSTS
        echo "Wywy-Codes not found — created minimal utils.ts."
    fi

    # src/components/layout/layout.astro — copy from Wywy-Codes
    if [ -f "$WYWY_CODES_ASTRO/src/components/layout/layout.astro" ]; then
        cp "$WYWY_CODES_ASTRO/src/components/layout/layout.astro" "$ASTRO_DIR/src/components/layout/layout.astro"
        echo "Copied layout.astro from Wywy-Codes."
    else
        cat > "$ASTRO_DIR/src/components/layout/layout.astro" << 'LAYOUT'
---
import Nav from "./nav.astro";
import "../../styles/global.css";
---

<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Wywy-CI</title>
  </head>
  <body class="min-h-screen bg-gray-950 text-gray-100">
    <Nav />
    <main class="max-w-6xl mx-auto px-6 py-8">
      <slot />
    </main>
  </body>
</html>
LAYOUT
        echo "Wywy-Codes not found — created minimal layout.astro."
    fi

    # src/components/layout/nav.astro — CI-specific nav
    cat > "$ASTRO_DIR/src/components/layout/nav.astro" << 'NAVASTRO'
---
const currentPath = Astro.url.pathname;
---
<nav class="border-b border-gray-800 bg-gray-950/80 sticky top-0 z-10 backdrop-blur">
  <div class="max-w-6xl mx-auto px-6 py-3 flex items-center gap-6">
    <a href="/" class="font-semibold text-lg text-gray-100 hover:text-blue-400 transition-colors">
      Wywy-CI
    </a>
    <div class="flex gap-4 text-sm">
      <a
        href="/"
        class={`transition-colors ${currentPath === "/" ? "text-blue-400" : "text-gray-400 hover:text-gray-200"}`}
      >
        Dashboard
      </a>
      <a
        href="/runs/_spa/"
        class={`transition-colors ${currentPath.startsWith("/runs/") ? "text-blue-400" : "text-gray-400 hover:text-gray-200"}`}
      >
        Run Detail
      </a>
    </div>
  </div>
</nav>
NAVASTRO

    # Placeholder pages
    cat > "$ASTRO_DIR/src/pages/index.astro" << 'INDEXASTRO'
---
import Layout from "../components/layout/layout.astro";
---
<Layout>
  <h1 class="text-2xl font-bold mb-6">Test Runs</h1>
  <p class="text-gray-400">Dashboard coming soon.</p>
</Layout>
INDEXASTRO

    mkdir -p "$ASTRO_DIR/src/pages/runs"
    cat > "$ASTRO_DIR/src/pages/runs/[id].astro" << 'RUNASTRO'
---
export function getStaticPaths() {
  return [{ params: { id: "_spa" } }];
}

const { id } = Astro.params;
---
<p>Run: {id}</p>
RUNASTRO

    echo "Astro project scaffolded."
else
    echo "Astro project already exists — skipping scaffold."
fi

# ── 7. npm install (idempotent) ────────────────────────────────────
cd "$ASTRO_DIR"
echo "Installing npm dependencies..."
npm install

# ── 8. Register port in .env.network (idempotent) ─────────────────
PORT_ENTRY="CI_CD_PORT=2526"
if grep -qxF "$PORT_ENTRY" "$ENV_NETWORK"; then
    echo "Already registered in .env.network."
else
    echo "$PORT_ENTRY" | sudo tee -a "$ENV_NETWORK" > /dev/null
    echo "Added to .env.network: $PORT_ENTRY"
fi

# ── 9. Group permissions on repo ────────────────────────────────────
sudo chgrp -R "$GID" "$REPO_DIR"
chmod -R u+rw "$REPO_DIR" 2>/dev/null || true
chmod -R g=rX "$REPO_DIR" 2>/dev/null || true
sudo chmod g+s "$REPO_DIR"
sudo setfacl -R -d -m "g:${GID}:rx" "$REPO_DIR" 2>/dev/null || true
chmod -R o-rwx "$REPO_DIR" 2>/dev/null || true

# ── 10. Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Wywy-CI-CD installation complete ==="
echo "  Repo:     $REPO_DIR"
echo "  Logs:     $LOG_DIR"
echo "  Data:     $DATA_DIR"
echo "  Go:       $(go version)"
echo "  Node:     $(node --version)"
echo ""
echo "Next steps:"
echo "  export PATH=\$PATH:/usr/local/go/bin  # if not already sourced"
echo "  cd $REPO_DIR"
echo "  # Run TDD cycles per plan at $CONTROL_DIR/internal/implementation-plans/wywy-ci.md"
