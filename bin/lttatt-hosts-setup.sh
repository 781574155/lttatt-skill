#!/usr/bin/env bash
set -euo pipefail

hosts_file="/c/Windows/System32/drivers/etc/hosts"
hosts_tmp_file="$(mktemp)"
trap 'rm -f "$hosts_tmp_file"' EXIT

if grep -q '^# Add by lttatt$' "$hosts_file"; then
  sed -i '/^# Add by lttatt$/,/^# End of section$/d' "$hosts_file"
fi

awk '
  {
    lines[NR] = $0
  }
  END {
    last = NR
    while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
      last--
    }

    for (i = 1; i <= last; i++) {
      print lines[i]
    }

    print ""
  }
' "$hosts_file" > "$hosts_tmp_file"
cat "$hosts_tmp_file" > "$hosts_file"

cat >> "$hosts_file" << EOF
# Add by lttatt
127.0.0.1   mysql
127.0.0.1   postgres
127.0.0.1   redis
127.0.0.1   rabbitmq
127.0.0.1   mongodb
127.0.0.1   minio
127.0.0.1   neo4j
127.0.0.1   elasticsearch
127.0.0.1   emqx
127.0.0.1   kafka
192.168.2.10 metabase.openai36.com
192.168.2.10 plane.openai36.com
192.168.2.10 n8n.openai36.com
192.168.2.10 langfuse.openai36.com
# End of section
EOF
