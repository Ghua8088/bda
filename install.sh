#!/usr/bin/env bash
# ==============================================================================
# BDA Environment One-Click Installer
# Works on Linux, macOS (Apple Silicon / Intel), and Windows (WSL2)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_BDA_DIR="${SCRIPT_DIR}/docker-bda"
BIN_DIR="${HOME}/.local/bin"

echo "======================================================================"
echo "          Big Data Analytics (BDA) Environment Setup                 "
echo "        Apache Hadoop, HDFS, YARN, Hive, Pig & HBase (Docker)         "
echo "======================================================================"
echo ""

# 1. Check Docker prerequisite
echo "[1/5] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
  echo "[-] ERROR: 'docker' is not installed or not in PATH."
  echo "    Please install Docker Desktop or Docker Engine first:"
  echo "    - Ubuntu/Debian: sudo apt update && sudo apt install -y docker.io docker-compose-v2"
  echo "    - macOS/Windows: Install Docker Desktop from https://www.docker.com/"
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "[-] ERROR: Docker daemon is not running or current user does not have permissions."
  echo "    Please start Docker, or run: sudo usermod -aG docker \$USER && newgrp docker"
  exit 1
fi

# Detect docker compose command
if docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
else
  echo "[-] ERROR: Neither 'docker compose' nor 'docker-compose' was found."
  exit 1
fi
echo "[+] Docker and ${COMPOSE_CMD} detected."

# 2. Install CLI wrappers into ~/.local/bin
echo ""
echo "[2/5] Installing CLI tools into ${BIN_DIR}..."
mkdir -p "${BIN_DIR}"

cat << 'EOF' > "${BIN_DIR}/hadoop"
#!/usr/bin/env bash
# Global Apache Hadoop CLI launcher
if [ -t 0 ]; then
  docker exec -it bda-hadoop hadoop "$@"
else
  docker exec -i bda-hadoop hadoop "$@"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/hdfs"
#!/usr/bin/env bash
# Global HDFS CLI launcher
if [ -t 0 ]; then
  docker exec -it bda-hadoop hdfs "$@"
else
  docker exec -i bda-hadoop hdfs "$@"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/hive"
#!/usr/bin/env bash
# Global Apache Hive CLI launcher
if [ -t 0 ]; then
  docker exec -it bda-hadoop hive "$@"
else
  docker exec -i bda-hadoop hive "$@"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/pig"
#!/usr/bin/env bash
# Global Apache Pig launcher
HAS_EXECTYPE=false
for arg in "$@"; do
  if [[ "$arg" == "-x" || "$arg" == -x* ]]; then
    HAS_EXECTYPE=true
    break
  fi
done

if [ "$HAS_EXECTYPE" = false ]; then
  FINAL_ARGS=("-x" "local" "$@")
else
  FINAL_ARGS=("$@")
fi

if [ -t 0 ]; then
  docker exec -it bda-hadoop pig "${FINAL_ARGS[@]}"
else
  docker exec -i bda-hadoop pig "${FINAL_ARGS[@]}"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/hbase"
#!/usr/bin/env bash
# Global Apache HBase shell launcher
if [ -t 0 ]; then
  docker exec -it bda-hbase hbase shell "$@"
else
  docker exec -i bda-hbase hbase shell "$@"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/enter-hadoop"
#!/usr/bin/env bash
# Open an interactive bash terminal inside bda-hadoop
if [ -t 0 ]; then
  docker exec -it bda-hadoop bash "$@"
else
  docker exec -i bda-hadoop bash "$@"
fi
EOF

cat << 'EOF' > "${BIN_DIR}/enter-hbase"
#!/usr/bin/env bash
# Open an interactive bash terminal inside bda-hbase
if [ -t 0 ]; then
  docker exec -it bda-hbase bash "$@"
else
  docker exec -i bda-hbase bash "$@"
fi
EOF

cat << EOF > "${BIN_DIR}/bda-status"
#!/usr/bin/env bash
# Status check for BDA cluster
echo "=== BDA Docker Containers ==="
docker ps --filter "name=bda-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
if docker ps --filter "name=bda-hadoop" --filter "status=running" -q | grep -q .; then
  echo "=== Hadoop JVM Processes (jps) ==="
  docker exec bda-hadoop jps
  echo ""
  echo "=== HDFS Safe Mode ==="
  docker exec bda-hadoop hdfs dfsadmin -safemode get 2>/dev/null || true
fi
EOF

cat << EOF > "${BIN_DIR}/bda-stop"
#!/usr/bin/env bash
cd "${DOCKER_BDA_DIR}" && ${COMPOSE_CMD} stop
echo "BDA services stopped."
EOF

cat << EOF > "${BIN_DIR}/bda-start"
#!/usr/bin/env bash
cd "${DOCKER_BDA_DIR}" && ${COMPOSE_CMD} up -d
echo "BDA services started."
EOF

chmod +x "${BIN_DIR}/hadoop" \
         "${BIN_DIR}/hdfs" \
         "${BIN_DIR}/hive" \
         "${BIN_DIR}/pig" \
         "${BIN_DIR}/hbase" \
         "${BIN_DIR}/enter-hadoop" \
         "${BIN_DIR}/enter-hbase" \
         "${BIN_DIR}/bda-status" \
         "${BIN_DIR}/bda-stop" \
         "${BIN_DIR}/bda-start"

echo "[+] CLI wrappers installed: hadoop, hdfs, hive, pig, hbase, enter-hadoop, enter-hbase, bda-status, bda-start, bda-stop"

# 3. Add to PATH in shell configuration files
echo ""
echo "[3/5] Configuring PATH environment variable..."
PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'

update_shell_rc() {
  local rc_file="$1"
  if [ -f "$rc_file" ]; then
    if ! grep -q 'PATH="$HOME/.local/bin' "$rc_file" 2>/dev/null && ! grep -q "PATH=.*\.local/bin" "$rc_file" 2>/dev/null; then
      echo "" >> "$rc_file"
      echo "# BDA Environment CLI tools" >> "$rc_file"
      echo "$PATH_EXPORT" >> "$rc_file"
      echo "    Added to $rc_file"
    else
      echo "    Already present in $rc_file"
    fi
  fi
}

update_shell_rc "${HOME}/.bashrc"
update_shell_rc "${HOME}/.zshrc"
update_shell_rc "${HOME}/.profile"
export PATH="${BIN_DIR}:${PATH}"

# 4. Start Docker containers
echo ""
echo "[4/5] Launching BDA cluster with Docker..."
(cd "${DOCKER_BDA_DIR}" && ${COMPOSE_CMD} up -d)

# 5. Wait for cluster initialization and safemode exit
echo ""
echo "[5/5] Waiting for Hadoop services to initialize and leave safe mode..."
MAX_WAIT=90
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if docker exec bda-hadoop hdfs dfsadmin -safemode get 2>/dev/null | grep -q "Safe mode is OFF"; then
    echo "[+] HDFS is READY (Safe mode is OFF)!"
    break
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  echo -n "."
done
echo ""

echo ""
echo "======================================================================"
echo "          🎉 BDA Environment Successfully Configured!               "
echo "======================================================================"
echo ""
echo "CLI Commands (run directly from anywhere in your terminal):"
echo "  • hadoop version               Check Hadoop version"
echo "  • hdfs dfs -ls /               List HDFS root files"
echo "  • hdfs dfs -put <file> /       Upload file to HDFS"
echo "  • pig -x local <file.pig>      Run Pig Latin script"
echo "  • hive -e 'SHOW DATABASES;'    Run HiveQL query"
echo "  • hbase                        Open Apache HBase interactive shell"
echo "  • enter-hadoop                 Interactive bash inside Hadoop container"
echo "  • enter-hbase                  Interactive bash inside HBase container"
echo "  • bda-status                   Check cluster and container status"
echo ""
echo "Web Interfaces:"
echo "  • HDFS NameNode:      http://localhost:50070"
echo "  • YARN ResourceManager: http://localhost:8088"
echo "  • HBase Master:       http://localhost:16010"
echo "  • HiveServer2 UI:     http://localhost:10002"
echo ""
echo "Note: If running in a new terminal window, ensure PATH is reloaded by running:"
echo "      source ~/.bashrc   (or restart terminal)"
echo "======================================================================"
