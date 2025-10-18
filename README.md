# DevOps Automation Toolkit

A collection of CLI-based tools and templates designed to simplify and accelerate DevOps automation across multiple cloud environments.

---

## Features

- **Terraform modules** for AWS, Azure, and GCP  
- **Reusable GitLab workflows** for CI/CD pipelines  
- **Docker Compose templates** for common application stacks  
- **Kubernetes manifest generator** for streamlined deployments  
- **Shell and Python scripts** for everyday DevOps tasks  

---

## Purpose

This toolkit provides a unified, modular foundation for automating infrastructure provisioning, deployment pipelines, and environment management - helping teams deliver faster and with higher consistency.

---

## Structure

```
devops-automation-toolkit/
├── terraform/
├── gitlab-workflows/
├── docker/
├── kubernetes/
├── scripts/
│   ├── shell/
│   └── python/
└── README.md
```

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-org>/devops-automation-toolkit.git
   cd devops-automation-toolkit
   ```

2. Explore the modules:
   ```bash
   tree -L 2
   ```

3. Use any tool or module directly from CLI:
   ```bash
   ./scripts/shell/setup-env.sh
   ```

---

## License

This project is released under the [MIT License](LICENSE).
