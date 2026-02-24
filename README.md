# EC2 Secrets – Infrastructure as Code Deployment

## Overview 

This project demonstrates provisioning cloud infrastructure using Terraform and deploying a containerized Node.js API with optional monitoring via Prometheus.


The objective was to:

Provision AWS infrastructure using Terraform

* Deploy an EC2 instance in a public subnet
* Configure networking (VPC, route table, Internet Gateway)
* Configure security groups
* Deploy a Dockerized REST API
* Expose the API on port 8080
* Integrate Prometheus monitoring

## Project Structure

```
EC2-SECRETS/
│
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
│
├── infra/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
├── prometheus/
│   └── prometheus.yml
│
├── docker-compose.yml
└── .gitignore
```

## Infrastructure (Terraform)

Terraform provisions:

* VPC
* Public Subnet
* Internet Gateway
* Route Table
* Security Groups
* EC2 Instance

Example route:

```
0.0.0.0/0 → Internet Gateway
```

Security Group:

* TCP 8080 (API)
* TCP 9090 (Prometheus)
* TCP 3000 (Grafana)

## Application Layer

The API is containerized using Docker.

```server.js``` exposes ```GET /whoami```

Application binds to:

```0.0.0.0:8080```

so it can receive external traffic.

## Monitoring 

Prometheus configured via: 

```prometheus/prometheus.yml```

Monitoring endpoints can be scraped from the running container.

## Deployment Flow

1. ```terraform.init```
2. ```terraform.apply```
3. SSH or Session Manager into instance
4. ```docker-compose up -d```
5. Access:
   * API → http://<public-ip>:8080
   * Prometheus → :9090
   * Grafana → :3000
  
## Security Considerations

* Infrastructure provisioned declaratively via Terraform
* Ports restricted to specific IPs when applicable
* IAM role recommended for Session Manager access
* Instance terminated after testing to avoid cost

## Lessons Learned

* Public vs private subnet design
* Security Group vs Network ACL
* Containerized deployment on EC2
* Binding services to 0.0.0.0
* Infrastructure as Code workflows
* Debugging remote connectivity issues
