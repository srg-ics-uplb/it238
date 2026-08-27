#!/bin/bash
#
# setup-it238.sh - IT 238 (Networking and Client-Server Computing) lab setup
#                  for Ubuntu 26.04 Desktop
# Usage: sudo ./setup-it238.sh
#
# IT 238 labs are Python 3 distributed-systems exercises:
#   Lab 1  sockets (stdlib only)
#   Lab 2  gRPC            -> grpcio, grpcio-tools
#   Lab 3  REST            -> fastapi, uvicorn, requests
#   Lab 4-10 clock sync, logical clocks, mutual exclusion, leader election,
#            replication, failure detection, 2PC  (stdlib only, plain Python)
# The build.sh scripts render the lab handouts to PDF with pandoc + XeLaTeX.
#
set -e

# =============================================================
# CONFIG - edit these
# =============================================================
USERNAME="it238"
PASSWORD="clientserver"

# --- System packages from the standard Ubuntu repositories -----------
# Check a name first with:  apt-cache show <pkg>
PACKAGES="
build-essential
gcc
g++
gdb
make
git
python3
python3-full
python3-dev
python3-pip
python3-venv
python3-setuptools
python3-wheel
docker.io
docker-compose-v2
docker-buildx
vim
nano
gedit
tmux
curl
wget
net-tools
iproute2
openssh-server
ca-certificates
"

# --- PDF authoring toolchain (build.sh: pandoc --pdf-engine=xelatex) --
PDF_PACKAGES="
pandoc
texlive-xetex
texlive-latex-recommended
texlive-latex-extra
texlive-fonts-recommended
texlive-fonts-extra
fonts-ibm-plex
fonts-liberation
librsvg2-bin
evince
"

# --- Python packages needed by the labs (installed system-wide) ------
# Ubuntu 24.04+ marks the system Python as "externally managed" (PEP 668),
# so pip needs --break-system-packages to install onto the system path.
# This box is a dedicated lab machine, which is exactly the case where that
# is acceptable; the labs tell students to run "pip install ..." globally.
PIP_PACKAGES="
grpcio
grpcio-tools
protobuf
fastapi
uvicorn[standard]
requests
httpx
pydantic
pytest
"

# Groups the user is added to. 'sudo' gives root access.
USER_GROUPS="sudo docker"

# =============================================================
# Setup
# =============================================================
if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0"
    exit 1
fi

# Suppress all prompts: debconf, config file conflicts, service restarts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
APT="apt-get -y -o Dpkg::Options::=--force-confold"

echo "==> Creating user $USERNAME"
if id "$USERNAME" >/dev/null 2>&1; then
    echo "    already exists, resetting password"
else
    useradd -m -s /bin/bash "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd

echo "==> Updating package lists"
$APT update

echo "==> Installing system packages"
for pkg in $PACKAGES; do
    echo "--- $pkg"
    $APT install "$pkg" || echo "    FAILED: $pkg"
done

echo "==> Installing PDF authoring toolchain (large, ~1-2 GB)"
for pkg in $PDF_PACKAGES; do
    echo "--- $pkg"
    $APT install "$pkg" || echo "    FAILED: $pkg"
done

echo "==> Installing Python lab dependencies (system-wide)"
PIP="pip3 install --break-system-packages --upgrade"
for pkg in $PIP_PACKAGES; do
    echo "--- $pkg"
    $PIP "$pkg" || echo "    FAILED: $pkg"
done

echo "==> Adding $USERNAME to groups"
for grp in $USER_GROUPS; do
    if getent group "$grp" >/dev/null; then
        usermod -aG "$grp" "$USERNAME"
        echo "    $grp"
    fi
done

echo "==> Enabling services"
systemctl enable --now docker || echo "    docker failed to start"
systemctl enable --now ssh    || echo "    ssh failed to start"

# =============================================================
# Check
# =============================================================
echo
echo "==> Command check"
for cmd in gcc make git python3 pip3 docker pandoc xelatex vim ssh; do
    if command -v "$cmd" >/dev/null; then
        echo "  ok       $cmd"
    else
        echo "  MISSING  $cmd"
    fi
done

echo
echo "==> Python import check"
for mod in socket grpc grpc_tools.protoc google.protobuf fastapi uvicorn requests httpx pydantic pytest; do
    if python3 -c "import $mod" 2>/dev/null; then
        echo "  ok       $mod"
    else
        echo "  MISSING  $mod"
    fi
done

echo
echo "==> Quick lab smoke tests (run as $USERNAME)"
if [ -d labs/02_grpc/solutions ]; then
    ( cd labs/02_grpc/solutions && \
      python3 -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. enrollment.proto \
      && echo "  ok       grpc_tools.protoc generated enrollment stubs" ) \
      || echo "  WARN     could not generate grpc stubs"
fi

echo
echo "==> Done. Log out and back in for group changes to apply."
echo "    User: $USERNAME  Password: $PASSWORD"
