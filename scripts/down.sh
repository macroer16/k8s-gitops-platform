#!/usr/bin/env bash
# Deletes the local cluster. Your sealed-secrets key backup is kept.
set -euo pipefail
k3d cluster delete platform
