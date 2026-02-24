variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "allowed_cidr" {
  type        = string
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32"
}

variable "secret_arn" {
  type        = string
  description = "Full ARN of the Secrets Manager secret"
}

variable "secret_name" {
  type        = string
  description = "Name of the secret, e.g. devops-observability/demo-api"
}

variable "repo_url" {
  type        = string
  description = "Git repo URL (HTTPS). If private, you'll need a deploy key/token setup."
}

variable "instance_type" {
  type    = string
  default = "t4g.micro"
}