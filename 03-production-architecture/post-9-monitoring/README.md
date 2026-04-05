# Post 9: Monitoring and Observability

This folder contains the practical companion artifacts for Post 9.

## Contents

- `scripts/Collect-HyperVObservabilityBaseline.ps1` gathers a baseline of host, cluster, counter, and event data.
- `templates/prometheus/windows_exporter.hyperv.yml` is a starter scrape configuration for Windows Exporter on Hyper-V hosts.
- `dashboards/grafana-hyperv-overview.json` is a starter dashboard you can import into Grafana.
- `guides/wac-scom-prometheus-guide.md` explains when to use WAC, SCOM, Azure Monitor, or Prometheus/Grafana.

## Recommended Use

1. Run the baseline script against each host or cluster node.
2. Decide whether your primary monitoring path is WAC plus PowerShell, SCOM, Azure Monitor, or Prometheus/Grafana.
3. Use the Prometheus and Grafana artifacts only after Windows Exporter is installed and reachable.

## Scope

These files are meant to give readers a starting point they can adapt, not a full observability platform in a box.
