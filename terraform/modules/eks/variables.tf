
variable "cluster-name" {
  type = string
}

variable "private-subnet-1-cidr" {
  type = string
}
variable "private-subnet-2-cidr" {
  type = string
}

variable "private-route-table-id"{
  type = string
}
variable "aws_vpc" {
  type = string
}

variable "office-ip" {
  type = string
}

variable "desired_capacity" {
  type = string
}

variable "max_size" {
  type = string
}

variable "enable_alb_sg" {
  type = bool
}

variable "alb_sg_cidr" {
  type = string
}
variable "instance-type" {
  type = string
}
