#!/usr/bin/env bash
# Shared helpers for the kafka-up scripts. Source me, don't run me.

set -euo pipefail

KAFKA_UP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export KAFKA_UP_DIR
COMPOSE_FILE="$KAFKA_UP_DIR/compose.yml"

# Container engine: podman by default. Override with KAFKA_UP_ENGINE=docker
# if you don't have podman installed.
: "${KAFKA_UP_ENGINE:=podman}"
export KAFKA_UP_ENGINE

# Service names are container-engine-agnostic. We always go through
# `$ENGINE compose -f compose.yml ...` so podman-compose and docker
# compose v2 both work.
compose() {
  "$KAFKA_UP_ENGINE" compose -f "$COMPOSE_FILE" "$@"
}

# Run a command inside a service container.
in_container() {
  local service="$1"; shift
  "$KAFKA_UP_ENGINE" exec "kafka-up-${service}" "$@"
}

# Container engine sanity check. Returns 0 if usable, 1 with a message
# otherwise. On macOS or Windows, automatically starts the podman
# machine if one exists and is not running. Linux podman has no VM,
# so the start step is skipped silently.
require_engine() {
  if ! command -v "$KAFKA_UP_ENGINE" >/dev/null 2>&1; then
    ui_err "container engine '$KAFKA_UP_ENGINE' not found in PATH"
    ui_hint "install podman (https://podman.io) or set KAFKA_UP_ENGINE=docker"
    return 1
  fi

  if [ "$KAFKA_UP_ENGINE" = "podman" ]; then
    if podman info >/dev/null 2>&1; then
      return 0
    fi
    # podman is installed but not reachable. On macOS/Windows that
    # usually means the VM is stopped. Try to bring it up.
    if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
      if podman machine list --format '{{.Running}}' 2>/dev/null | grep -qi true; then
        ui_err "podman machine is running but podman cannot reach it"
        ui_hint "try: podman machine stop && podman machine start"
        return 1
      fi
      ui_step "podman machine is stopped, starting it (10-20s)"
      if ! podman machine start >/dev/null 2>&1; then
        ui_err "failed to start podman machine"
        ui_hint "run manually and retry: podman machine start"
        return 1
      fi
      ui_ok "podman machine started"
      # Brief settle window: podman info can race the socket coming up.
      local i=0
      while (( i < 10 )); do
        if podman info >/dev/null 2>&1; then
          return 0
        fi
        sleep 1
        i=$((i+1))
      done
      ui_err "podman machine started but podman is still not reachable"
      ui_hint "check: podman machine list"
      return 1
    fi
    # No machine exists. On Linux this is normal, podman runs
    # daemonless, so check info one more time and report whatever
    # the real error is.
    if podman info >/dev/null 2>&1; then
      return 0
    fi
    if [ "$(uname -s)" = "Darwin" ] || uname -s | grep -qiE 'mingw|msys|cygwin'; then
      ui_err "no podman machine found"
      ui_hint "create one with: podman machine init && podman machine start"
    else
      ui_err "podman is installed but not reachable"
      ui_hint "check the podman daemon or socket configuration"
    fi
    return 1
  fi

  if ! "$KAFKA_UP_ENGINE" info >/dev/null 2>&1; then
    ui_err "$KAFKA_UP_ENGINE is installed but not reachable"
    ui_hint "on macOS, start Docker Desktop; on Linux, check the docker daemon"
    return 1
  fi
  return 0
}

# Translate a broker count into the env vars compose.yml expects.
# Sets:
#   KAFKA_UP_PROFILES    space-separated profile flags for compose
#   KAFKA_UP_RF          replication factor
#   KAFKA_UP_MIN_ISR     min in-sync replicas
#   KAFKA_UP_QUORUM_VOTERS
#   KAFKA_UP_BOOTSTRAP_INTERNAL        SR-style URL list
#   KAFKA_UP_BOOTSTRAP_INTERNAL_PLAIN  host:port list (Connect, UI)
#   KAFKA_UP_BOOTSTRAP_HOST            host-side bootstrap for the developer
configure_topology() {
  local brokers="$1"
  case "$brokers" in
    1)
      export KAFKA_UP_RF=1
      export KAFKA_UP_MIN_ISR=1
      export KAFKA_UP_QUORUM_VOTERS="1@kafka0:9090"
      export KAFKA_UP_BOOTSTRAP_INTERNAL="PLAINTEXT://kafka0:29092"
      export KAFKA_UP_BOOTSTRAP_INTERNAL_PLAIN="kafka0:29092"
      export KAFKA_UP_BOOTSTRAP_HOST="localhost:9092"
      KAFKA_UP_PROFILES=()
      ;;
    3)
      export KAFKA_UP_RF=3
      export KAFKA_UP_MIN_ISR=2
      export KAFKA_UP_QUORUM_VOTERS="1@kafka0:9090,2@kafka1:9090,3@kafka2:9090"
      export KAFKA_UP_BOOTSTRAP_INTERNAL="PLAINTEXT://kafka0:29092,PLAINTEXT://kafka1:29092,PLAINTEXT://kafka2:29092"
      export KAFKA_UP_BOOTSTRAP_INTERNAL_PLAIN="kafka0:29092,kafka1:29092,kafka2:29092"
      export KAFKA_UP_BOOTSTRAP_HOST="localhost:9092,localhost:9192,localhost:9292"
      KAFKA_UP_PROFILES=(--profile cluster)
      ;;
    *)
      ui_err "unsupported broker count: $brokers (expected 1 or 3)"
      return 1
      ;;
  esac
}

# Detect the topology the running cluster was started with by counting
# kafka-up-kafkaN containers. Used by kafka-down / kafka-status when
# the user didn't pass --brokers.
detect_topology() {
  local running
  running=$("$KAFKA_UP_ENGINE" ps --filter "name=kafka-up-kafka" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')
  case "$running" in
    3) echo 3 ;;
    *) echo 1 ;;
  esac
}

# Block until a service reports healthy (compose healthcheck). Polls
# `$ENGINE inspect` for the State.Health.Status field. Returns 0 on
# healthy, 1 on timeout. Quiet, caller draws the UI.
wait_healthy() {
  local service="$1" max="${2:-90}" i=0 status
  local container="kafka-up-${service}"
  while (( i < max )); do
    status=$("$KAFKA_UP_ENGINE" inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || true)
    if [ "$status" = "healthy" ]; then
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  return 1
}

# True when a kafka-up container with the given service suffix is running.
is_running() {
  local service="$1"
  "$KAFKA_UP_ENGINE" ps --filter "name=kafka-up-${service}" --format '{{.Names}}' 2>/dev/null \
    | grep -q "^kafka-up-${service}$"
}
