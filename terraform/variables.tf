variable "project_id" {
  description = "GCP project id. Not a secret, but keep the real value in terraform.tfvars, which is gitignored."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters: start with a letter, then lowercase letters, digits, or hyphens."
  }
}

variable "region" {
  description = "Region for Cloud Run, the function, and the scheduler."
  type        = string
  default     = "europe-west1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must look like europe-west1."
  }
}

variable "env" {
  description = "Environment label stamped on every resource."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test"], var.env)
    error_message = "env must be dev or test."
  }
}

variable "owner" {
  description = "Owner label stamped on every resource."
  type        = string
  default     = "cloud-practice"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.owner))
    error_message = "owner must be 1-63 characters: lowercase letters, digits, underscores, or hyphens."
  }
}

variable "location_slug" {
  description = "Location path segment in the GCS layout, for example minsk."
  type        = string
  default     = "minsk"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.location_slug))
    error_message = "location_slug must be lowercase letters, digits, and single hyphens."
  }
}

variable "location_query" {
  description = "tomorrow.io location query as latitude,longitude."
  type        = string
  default     = "53.9,27.57"

  validation {
    condition     = can(regex("^-?[0-9]+(?:\\.[0-9]+)?,-?[0-9]+(?:\\.[0-9]+)?$", var.location_query))
    error_message = "location_query must be latitude,longitude, for example 53.9,27.57."
  }
}

variable "force_destroy" {
  description = "Delete a non-empty data bucket on destroy. Leave false until teardown."
  type        = bool
  default     = false
}

locals {
  labels = {
    environment = var.env
    owner       = var.owner
    managed_by  = "terraform"
  }
}
