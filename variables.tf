variable "aws_region" {
  description = "AWS region ID for deployment (e.g. eu-west-1)"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cluster_subnet_ids" {
  type = list(string)
}

variable "nodegroup_subnet_ids" {
  type = list(string)
}

variable "nodegroup_desired_size" {
  type = number
}

variable "nodegroup_min_size" {
  type = number
}

variable "nodegroup_max_size" {
  type = number
}

variable "nodegroup_disk_size" {
  type = string
}

variable "nodegroup_instance_types" {
  type = list(string)
}