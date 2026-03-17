#!/bin/bash
export PATH="$HOME/.pyenv/shims:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd /Users/oca/BoxPwnr-Infra
python3 - << 'EOF'
import sys, os
sys.path.insert(0, '.')
for envfile in ['.env', '../BoxPwnr/.env']:
    if os.path.isfile(envfile):
        with open(envfile) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, _, v = line.partition('=')
                    k = k.strip()
                    if k not in os.environ:
                        os.environ[k] = v.strip().strip('"').strip("'")
from launch_benchmark import push_claude_usage, push_codex_usage
bucket = os.environ.get('DASHBOARD_BUCKET', '')
push_claude_usage(bucket)
push_codex_usage(bucket)
EOF
