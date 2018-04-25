//-------------------------------------------------------------------
// Vault settings
//-------------------------------------------------------------------

variable "vault_download_url" {
    default = "https://releases.hashicorp.com/vault/0.10.1/vault_0.10.1_linux_amd64.zip"
    description = "URL to download Vault"

}

variable "consul_download_url" {
    default = "https://releases.hashicorp.com/consul/1.0.7/consul_1.0.7_linux_amd64.zip"
    description = "URL to download Consul"

}

variable "vault_config" {
  description = "Configuration (text) for Vault"
  default = <<EOF
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
  backend "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
ui=true
EOF
}

variable "consul_config" {
    description = "Configuration (text) for Consul"
    default = <<EOF
{
  "log_level": "INFO",
  "server": true,
  "ui": true,
  "data_dir": "/opt/consul/data",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "advertise_addr": "IP_ADDRESS",
  "bootstrap_expect": 3,
  "retry_join": ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join region=us-east-1"],
  "service": {
    "name": "consul"
  }
}
EOF
}

variable "vault_extra_install" {
    default = ""
    description = "Extra commands to run in the vault install script"
}

variable "consul_extra_install" {
    default = ""
    description = "Extra commands to run in the consul install script"
}

//-------------------------------------------------------------------
// AWS settings
//-------------------------------------------------------------------

variable "ami" {
    default = "ami-7eb2a716"
    description = "AMI for Vault instances"
}

variable "instance_name" {
    default = "vault"
    description = "name of Vault EC2 instance"
}

variable "public_ip" {
    default = false
    description = "should ec2 instance have public ip?"
}

variable "name_prefix" {
    default = "vault"
    description = "prefix used in resource names"
}

variable "availability_zones" {
    default = "us-east-1a,us-east-1b"
    description = "Availability zones for launching the Vault instances"
}

variable "elb_health_check" {
    default = "HTTP:8200/v1/sys/health?standbyok=true"
    description = "Health check for Vault servers"
}

variable "elb_internal" {
    default = true
    description = "make ELB internal or external"
}

variable "instance_type" {
    default = "t2.medium"
    description = "Instance type for Vault instances"
}

variable "key_name" {
    default = "default"
    description = "SSH key name for Vault instances"
}

variable "nodes" {
    default = "3"
    description = "number of Vault instances"
}

variable "subnets" {
    description = "list of subnets to launch Vault within"
}

variable "vpc_id" {
    description = "VPC ID"
}
