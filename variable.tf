variable "aws_access_key" {
  type        = string
  default     = "<AWS ACCESS KEY>"
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = string
  default     = "<AWS SECRET KEY>"
  description = "AWS Secret Key"
}

variable "aws_region" {
  type        = string
  default     = "ap-northeast-2"
  description = "AWS Region"
}

variable "github_repo_url" {
  type        = string
  default     = "<GITHUB REPOSITORY URL>"
  description = "URL of the GitHub repository where Atlantis will be configured"
}

variable "github_user" {
  type        = string
  default     = "<GITHUB USER NAME>"
  description = "GitHub user name for authentication"
}

variable "github_token" {
  type        = string
  default     = "<GITHUB TOKEN>"
  description = "GitHub token for authentication"
}

variable "github_webhook_secret" {
  type        = string
  default     = "<GITHUB WEBHOOK SECRET>"
  description = "GitHub webhook secret for Atlantis"
}

variable "github_repo_name" {
  type        = string
  default     = "<GITHUB REPOSITORY NAME>"
  description = "Name of the GitHub repository for Atlantis"
}
