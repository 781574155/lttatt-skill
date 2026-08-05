#!/usr/bin/env bash

cat > ~/.codex/.env << EOF
HTTP_PROXY="http://127.0.0.1:7897"
HTTPS_PROXY="http://127.0.0.1:7897"
NO_PROXY="localhost,127.0.0.1,::1"
EOF