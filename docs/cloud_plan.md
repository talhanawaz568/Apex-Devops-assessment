# Cost-Aware Cloud Hosting Proposal

## 1. Objective

Propose a practical and cost-conscious path for hosting
the Apex Operations API in AWS.

No paid cloud infrastructure is provisioned as part
of this assessment.

## 2. Recommended Initial Architecture

For a small, non-critical workload, I recommend a
single EC2 instance running Docker Compose.

Architecture:

Internet
    |
    v
HTTPS Reverse Proxy
    |
    v
EC2 Instance
    |
    +-- FastAPI Container
    |
    +-- PostgreSQL Container
            |
            v
       Persistent EBS Storage

## 3. AWS Components

### Amazon EC2

Hosts Docker Engine and the application containers.

A small instance should be selected based on measured
CPU, memory, and workload requirements.

### Amazon EBS

Provides persistent block storage for application
and database data.

### Security Groups

Restrict network access.

Required public access:

- HTTPS: TCP 443

Optional:

- HTTP: TCP 80 for redirecting to HTTPS

Administrative access should use an appropriately
restricted mechanism, such as AWS Systems Manager
Session Manager.

Database port 5432 should not be publicly exposed.

### IAM

Use least-privilege IAM policies for AWS access.

Avoid storing long-lived AWS credentials inside
containers or GitHub repositories.

### DNS and TLS

Use a suitable domain and TLS certificate to provide
encrypted application access.

## 4. Deployment Process

1. Merge approved application code.
2. GitHub Actions runs quality and security checks.
3. CI publishes a verified container image.
4. Deployment retrieves the selected image.
5. Docker Compose recreates the API service.
6. Smoke tests validate the deployment.
7. The previous verified image remains available
   for rollback.

## 5. Cost Considerations

Major cost drivers:

- EC2 instance size and running hours
- EBS storage capacity
- Backup storage
- Network data transfer
- Public IPv4 address charges
- Logging and monitoring
- DNS and other optional services

The initial design minimizes the number of managed
services but increases operational responsibility.

Pricing must be checked using the official AWS Pricing
Calculator before any real deployment.

## 6. Production Limitations

A single EC2 instance creates a single point of failure.

Running PostgreSQL on the same instance as the API
also creates availability and recovery risks.

Additional limitations:

- No automatic multi-instance failover
- Maintenance can cause downtime
- Database backups require additional implementation
- Manual scaling
- Limited operational resilience

## 7. Production Evolution

For more critical workloads, consider:

- Amazon ECS for container orchestration
- Amazon RDS for managed PostgreSQL
- AWS Secrets Manager for credentials
- Application Load Balancer for traffic management
- CloudWatch for infrastructure observability
- Managed backup and recovery services
- Multiple availability zones where justified

## 8. Technology Decision

I selected Docker Compose for the initial design
because the workload is small and predictable.

Kubernetes would add infrastructure complexity and
operational overhead that is not justified by the
assessment's requirements.

## 9. Recommendation

Begin with a simple deployment architecture and
evolve toward managed services as availability,
security, scaling, and business requirements increase.

This assessment does not deploy to AWS because its
conditions prohibit paid cloud resources.
