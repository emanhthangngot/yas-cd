# Project Version Decision

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`
- CD sync branch: `main`
- Historical migration branch: `lab2/task/tri-xuan`
- Current runtime policy branch work has been merged into CD `main` through PR #11, PR #12, PR #13, and PR #14.
- Java/Spring decision: keep Java 25 and Spring Boot 4.0.2 from the current fork unless the team updates this decision explicitly.
- Runtime target: one Google Cloud Compute Engine VM with 32 GB RAM, Ubuntu 24.04 LTS, `k3s` single-node Kubernetes.
- Network: no Tailscale; use VM external IP, GCP firewall, hosts-file DNS for demo names, and SSH tunnels or admin-IP allowlisting for admin UIs.
- Active environments: `dev` and `staging` run in parallel; `developer` stays dormant to keep the single-node VM usable.
- Staging release policy: immutable `vX.Y.Z` tags only.
- App repo main pipeline selects release/dev behavior by `TAG_NAME` and `BRANCH_NAME`; developer preview is separated into `Jenkinsfile.developer-build`.
