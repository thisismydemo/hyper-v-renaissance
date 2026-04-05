# WAC, SCOM, Azure Monitor, Or Prometheus?

Use this quick filter when choosing the monitoring path:

- Choose WAC plus PowerShell when you want low cost and direct operational visibility.
- Choose SCOM when you already run System Center and want alerting, management packs, and enterprise operational workflow.
- Choose Azure Monitor when you already invest in Log Analytics and Azure-native alerting.
- Choose Prometheus plus Grafana when your team prefers open tooling, dashboards as code, and simple pull-based metrics.

The practical pattern for many readers in this series is hybrid:

- WAC for day-to-day platform operations.
- PowerShell for scheduled health audits and reporting.
- SCOM or Azure Monitor for alerting if you already own the ecosystem.
- Prometheus/Grafana for custom dashboards or DevOps-oriented teams.
