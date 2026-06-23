# Project Version Decision

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:tzin1401/yas-cd.git`
- CD sync branch: `main`
- Migration branch: `lab2/task/tri-xuan`
- Java/Spring decision: keep Java 25 and Spring Boot 4.0.2 from the current fork unless the team updates this decision explicitly.
- Runtime target: one Google Cloud Compute Engine VM with 32 GB RAM, Ubuntu 24.04 LTS, `k3s` single-node Kubernetes.
- Network: no Tailscale; use VM external IP, GCP firewall, hosts-file DNS for demo names, and SSH tunnels or admin-IP allowlisting for admin UIs.
