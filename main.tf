data "template_file" "install" {
    template = "${file("${path.module}/scripts/install.sh.tpl")}"

    vars {
        vault_download_url  = "${var.vault_download_url}"
        consul_download_url  = "${var.consul_download_url}"
        vault_config        = "${var.vault_config}"
        consul_config        = "${var.consul_config}"
        vault_extra_install = "${var.vault_extra_install}"
        consul_extra_install = "${var.consul_extra_install}"
    }
}

// We launch Vault into an ASG so that it can properly bring them up for us.
resource "aws_autoscaling_group" "vault" {
    name = "vault-${aws_launch_configuration.vault.name}"
    launch_configuration = "${aws_launch_configuration.vault.name}"
    availability_zones = ["${split(",", var.availability_zones)}"]
    min_size = "${var.nodes}"
    max_size = "${var.nodes}"
    desired_capacity = "${var.nodes}"
    health_check_grace_period = 15
    health_check_type = "EC2"
    vpc_zone_identifier = ["${split(",", var.subnets)}"]
    load_balancers = ["${aws_elb.vault.id}"]

    tags = [
      {
        key = "Name"
        value = "${var.instance_name}"
        propagate_at_launch = true
      },
      {
        key = "ConsulAutoJoin"
        value = "auto-join"
        propagate_at_launch = true
      }
    ]

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_launch_configuration" "vault" {
    name_prefix = "${var.name_prefix}"
    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    security_groups = ["${aws_security_group.vault.id}"]
    user_data = "${data.template_file.install.rendered}"
    associate_public_ip_address = "${var.public_ip}"
    iam_instance_profile = "${aws_iam_instance_profile.instance_profile.name}"

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.name_prefix}"
  role        = "${aws_iam_role.instance_role.name}"
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${var.name_prefix}"
  assume_role_policy = "${data.aws_iam_policy_document.instance_role.json}"
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "auto-discover-cluster"
  role   = "${aws_iam_role.instance_role.id}"
  policy = "${data.aws_iam_policy_document.auto_discover_cluster.json}"
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances"
    ]

    resources = ["*"]
  }
}

// Security group for Vault allows SSH and HTTP access (via "tcp" in
// case TLS is used)
resource "aws_security_group" "vault" {
    name = "${var.name_prefix}-vault-sg"
    description = "Vault servers"
    vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "vault-ssh" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Vault HTTP API access to individual nodes, since each will
// need to be addressed individually for unsealing.
resource "aws_security_group_rule" "vault-http-api" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8200
    to_port = 8200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-cluster" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8201
    to_port = 8201
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul HTTP API access to individual nodes.
resource "aws_security_group_rule" "consul-http-api" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul RPC.
resource "aws_security_group_rule" "consul-rpc" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8300
    to_port = 8300
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul Serf TCP.
resource "aws_security_group_rule" "consul-serf-tcp" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8301
    to_port = 8302
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul Serf UDP.
resource "aws_security_group_rule" "consul-serf-udp" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8301
    to_port = 8302
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul-dns-tcp" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8600
    to_port = 8600
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul-dns-udp" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "ingress"
    from_port = 8600
    to_port = 8600
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-egress" {
    security_group_id = "${aws_security_group.vault.id}"
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

// Launch the ELB that is serving Vault. This has proper health checks
// to only serve healthy, unsealed Vaults.
resource "aws_elb" "vault" {
    name = "${var.name_prefix}-elb"
    connection_draining = true
    connection_draining_timeout = 400
    internal = "${var.elb_internal}"
    subnets = ["${split(",", var.subnets)}"]
    security_groups = ["${aws_security_group.elb.id}"]

    listener {
        instance_port = 8200
        instance_protocol = "tcp"
        lb_port = 8200
        lb_protocol = "tcp"
    }

    listener {
        instance_port = 8500
        instance_protocol = "tcp"
        lb_port = 8500
        lb_protocol = "tcp"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 3
        timeout = 5
        target = "${var.elb_health_check}"
        interval = 15
    }
}

resource "aws_security_group" "elb" {
    name = "${var.name_prefix}-elb"
    description = "Vault ELB"
    vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "vault-elb-http" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "ingress"
    from_port = 8200
    to_port = 8200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul-elb-http" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "ingress"
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault-elb-egress" {
    security_group_id = "${aws_security_group.elb.id}"
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
