variable "docker_image" {
  type        = string
  description = "Docker image tag."
  default     = ""
}

variable "envs" {
  type        = map(string)
  description = "Environment variables."
  default     = {}
}

variable "ports" {
  type        = list(number)
  description = "Ports."
  default     = [80]
}

variable "password" {
  type        = string
  description = "main-db password."
}

variable "username" {
  type        = string
  description = "main-db username."
}

