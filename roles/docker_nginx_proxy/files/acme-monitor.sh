#!/bin/sh

# ACME companion retry monitor script
# Watches the nginx-proxy-acme container logs for retryafter=86400 issues
# and cleans up certificates before restarting the container

set -e

ACME_CONTAINER_NAME="${ACME_CONTAINER_NAME:-nginx-proxy-acme}"
WAIT_TIME="${WAIT_TIME:-900}"  # 15 minutes default
CERTS_DIR="/etc/nginx/certs"
ACME_DIR="/etc/acme.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cleanup_certs() {
    log "Starting certificate cleanup..."

    # Remove all certificate files
    if [ -d "$CERTS_DIR" ]; then
        rm -rf "${CERTS_DIR:?}"/*
        log "Cleaned up $CERTS_DIR"
    else
        log "Warning: $CERTS_DIR directory not found"
    fi

    # Remove acme.sh data
    if [ -d "$ACME_DIR" ]; then
        rm -rf "${ACME_DIR:?}"/*
        log "Cleaned up $ACME_DIR"
    else
        log "Warning: $ACME_DIR directory not found"
    fi
}

restart_acme_container() {
    log "Restarting ACME container: $ACME_CONTAINER_NAME"

    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log "Error: Docker command not found"
        return 1
    fi

    # Check if container exists
    if ! docker inspect "$ACME_CONTAINER_NAME" >/dev/null 2>&1; then
        log "Error: Container '$ACME_CONTAINER_NAME' not found"
        return 1
    fi

    # Restart the container
    if docker restart "$ACME_CONTAINER_NAME"; then
        log "Successfully restarted $ACME_CONTAINER_NAME"
    else
        log "Error: Failed to restart $ACME_CONTAINER_NAME"
        return 1
    fi
}

monitor_logs() {
    log "Starting ACME log monitor for container: $ACME_CONTAINER_NAME"
    log "Wait time configured: ${WAIT_TIME}s"

    while true; do
        # Follow logs and look for the retry pattern
        docker logs -f "$ACME_CONTAINER_NAME" 2>&1 | while read -r line; do
            echo "$line"  # Forward the log line

            # Check for the problematic retry pattern
            if echo "$line" | grep -q "retryafter=86400.*value is too large"; then
                log "DETECTED: ACME retry issue - retryafter=86400 value too large"
                log "Waiting ${WAIT_TIME} seconds before cleanup and restart..."

                sleep "$WAIT_TIME"

                cleanup_certs
                restart_acme_container

                log "Cleanup and restart completed. Resuming log monitoring..."
                break  # Break from the logs loop to restart monitoring
            fi
        done

        # If we get here, the docker logs command exited
        log "Log monitoring stopped, waiting 10 seconds before restarting..."
        sleep 10
    done
}

# Install required packages
log "Installing required packages..."
apk add --no-cache docker-cli

# Main monitoring loop
log "Starting ACME retry monitor..."
while true; do
    # Check if the ACME container is running
    if docker inspect "$ACME_CONTAINER_NAME" >/dev/null 2>&1; then
        if [ "$(docker inspect -f '{{.State.Running}}' "$ACME_CONTAINER_NAME")" = "true" ]; then
            monitor_logs
        else
            log "ACME container '$ACME_CONTAINER_NAME' is not running, waiting..."
            sleep 30
        fi
    else
        log "ACME container '$ACME_CONTAINER_NAME' not found, waiting..."
        sleep 30
    fi
done
