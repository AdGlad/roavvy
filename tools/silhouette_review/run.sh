#!/bin/bash
# Start the Silhouette Review Tool and open in browser.
# Run from anywhere inside the repo.
set -e
cd "$(dirname "$0")"
echo "Starting Silhouette Review Tool at http://localhost:8765"
python3 server.py &
SERVER_PID=$!
sleep 1.5
open "http://localhost:8765" 2>/dev/null || echo "Open http://localhost:8765 in your browser"
wait $SERVER_PID
