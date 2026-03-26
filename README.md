# BoxPwnr-Infra

Infrastructure, benchmarking, and real-time dashboard for [BoxPwnr](https://github.com/0ca/BoxPwnr) — an automated security testing platform that uses LLMs to solve CTF challenges and penetration testing labs.

## Dashboard

Real-time monitoring of benchmark runs across multiple EC2 runners.

![BoxPwnr Benchmark Dashboard](docs/dashboard.png)

Features: per-runner progress bars, cumulative solve/cost charts, system resource monitoring (RAM/disk/CPU), Claude & Codex usage limits, auto-refresh.

## Architecture

```
                    ┌─────────────────┐
                    │  launch_bench-  │
                    │  mark.py (local)│
                    └────────┬────────┘
                             │ Terraform + rsync + SSH
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Runner 1 │   │ Runner 3 │   │ Runner N │   EC2 instances
        │ (HTB)    │   │ (picoCTF)│   │ (THM)    │   running BoxPwnr
        └────┬─────┘   └────┬─────┘   └────┬─────┘
             │              │              │
             └──────────────┼──────────────┘
                            ▼ push_runner_stats.py (cron, every 1m)
                    ┌───────────────┐
                    │  S3 Bucket    │
                    │  (dashboard)  │
                    └───────────────┘
```

- **Shared infra**: ECR repo, IAM roles, security groups (one Terraform state)
- **Per-runner**: EC2 instance with separate Terraform state in `infra/runner-N/`
- **Dashboard**: Static HTML on S3, runners push JSON stats every minute
- **Docker**: Shared ECR image tagged by Dockerfile hash, S3 cache for fast loading
- **Golden AMI**: Pre-baked AMI with Docker + uv + image loaded (saves ~5min/runner)

## Quick Start

### Prerequisites

- AWS CLI configured, Terraform, Docker
- A sibling `BoxPwnr/` checkout (or set `BOXPWNR_ROOT` env var)

```bash
# Create .env with your dashboard bucket
echo "DASHBOARD_BUCKET='boxpwnr-runners-dashboard'" > .env
```

### Launch a benchmark

```bash
python launch_benchmark.py \
  --runner 1 \
  --key-path "~/.ssh/key.pem" \
  --model claude-sonnet-4-20250514 \
  --solver single_loop \
  --platform htb \
  --targets "Lame,Jerry,Shocker" \
  --max-turns 80 --max-cost 2.0 --max-time 60
```

### Manage runners

```bash
python launch_benchmark.py --list                        # List all runners
python launch_benchmark.py --ssh --runner 1              # SSH to runner
python launch_benchmark.py --tmux --runner 1             # Attach tmux session
python launch_benchmark.py --stats --runner 1            # Benchmark stats
python launch_benchmark.py --rsync --runner 1            # Download results
python launch_benchmark.py --exec 'df -h' --runner 1     # Run command
python launch_benchmark.py --start --runner 1            # Start stopped instance
python launch_benchmark.py --stop --runner 1             # Stop (restartable)
python launch_benchmark.py --clear --runner 1            # Delete traces
python launch_benchmark.py --destroy --runner 1          # Destroy infra
```

### Combine actions

Multiple actions execute left to right:

```bash
python launch_benchmark.py --rsync --stop --runner 1         # Download then stop
python launch_benchmark.py --rsync --clear --runner 1        # Download then clear
python launch_benchmark.py --start --rsync --stop --runner 1 # Start, download, stop
```

### Dashboard

```bash
python launch_benchmark.py --push-dashboard              # Manual stats push
```

## Repository Structure

```
.
├── launch_benchmark.py      # Main orchestration script
├── build_push_docker.sh     # Docker image build & ECR push
├── build_ami.sh             # Golden AMI builder
├── push_claude_usage.sh     # Claude/Codex usage push (macOS cron)
├── dashboard/
│   ├── index.html           # Static S3-hosted dashboard
│   └── push_runner_stats.py # Stats collector (runner cron)
├── infra/
│   ├── main.tf              # Shared Terraform resources
│   ├── templates/           # Per-runner EC2 templates
│   └── runner-N/            # Per-runner state (gitignored)
└── .env                     # DASHBOARD_BUCKET (gitignored)
```
