##########################################################
# Cluster Networking
##########################################################

# Defining private subnet 1
resource "aws_subnet" "private-subnet-1" {
  vpc_id            = "${var.aws_vpc}"
  cidr_block        = "${var.private-subnet-1-cidr}"
  availability_zone = "us-west-2a"

  tags = {
    Name = "Private ${var.cluster-name} cluster a"
    "kubernetes.io/cluster/${var.cluster-name}"         = "shared"
    "kubernetes.io/role/internal-elb"           = ""
    "kubernetes.io/role/alb-ingress"            = "" 
    "kubernetes.io/role/alb-ingress-controller" = "" 
    "kubernetes.io/role/ingress"                = "" 
  }
}

# Defining private subnet 2
resource "aws_subnet" "private-subnet-2" {
  vpc_id            = "${var.aws_vpc}"
  cidr_block        = "${var.private-subnet-2-cidr}"
  availability_zone = "us-west-2b"

  tags = {
    Name = "Private ${var.cluster-name} cluster b"
    "kubernetes.io/cluster/${var.cluster-name}"         = "shared"
    "kubernetes.io/role/internal-elb"           = ""
    "kubernetes.io/role/alb-ingress"            = "" 
    "kubernetes.io/role/alb-ingress-controller" = "" 
    "kubernetes.io/role/ingress"                = "" 
  }
}
resource "aws_route_table_association" "private-subnet-1" {
  subnet_id      = "${aws_subnet.private-subnet-1.id}"
  route_table_id = "${var.private-route-table-id}"
}
resource "aws_route_table_association" "private-subnet-2" {
  subnet_id      = "${aws_subnet.private-subnet-2.id}"
  route_table_id = "${var.private-route-table-id}"
}

##########################################################
# Master Node
##########################################################

#  IAM Role

resource "aws_iam_role" "cluster-role" {
  name = "${var.cluster-name}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "cluster-assume" {
  name        = "${var.cluster-name}-assume-rol"
  description = "Policy to assume roles in ${var.cluster-name} cluster"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = "${aws_iam_role.cluster-role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role = "${aws_iam_role.cluster-role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-AssumeRol" {
  policy_arn = "${aws_iam_policy.cluster-assume.arn}"
  role = "${aws_iam_role.cluster-role.name}"
}


# Security group
resource "aws_security_group" "cluster-sg" {
  name = "${var.cluster-name}-cluster"
  description = "Cluster communication with ${var.cluster-name} worker nodes"

  /*  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["${var.private_subnet_a_cidr}", "${var.private_subnet_b_cidr}"]
  }
  */

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${var.aws_vpc}"

  tags = {
    Name = "${var.cluster-name}-cluster"
  }
}

resource "aws_security_group_rule" "cluster-ingress-workstation-https" {
  cidr_blocks = ["${var.office-ip}"]
  description = "Allow workstation to communicate with the cluster API Server"
  from_port = 443
  protocol = "tcp"
  security_group_id = "${aws_security_group.cluster-sg.id}"
  to_port = 443
  type = "ingress"
}


# EKS Master 
resource "aws_eks_cluster" "cluster-eks" {
  name = "${var.cluster-name}"
  role_arn = "${aws_iam_role.cluster-role.arn}"

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids = ["${aws_security_group.cluster-sg.id}"]
    subnet_ids = ["${aws_subnet.private-subnet-1.id}", "${aws_subnet.private-subnet-2.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-AmazonEKSServicePolicy",
  ]
}


##########################################################
# Worker Nodes
##########################################################

#IAM role
resource "aws_iam_role" "cluster-node" {
  name = "${var.cluster-name}-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = "${aws_iam_role.cluster-node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = "${aws_iam_role.cluster-node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = "${aws_iam_role.cluster-node.name}"
}

resource "aws_iam_instance_profile" "node-profile" {
  name = "${var.cluster-name}"
  role = "${aws_iam_role.cluster-node.name}"
}

# Security group

# alb restrictions are created only if the variable enable_alb_sg is not empty
resource "aws_security_group" "eks-alb" {
  count = "${var.enable_alb_sg ? 1 : 0}"
  name = "${var.cluster-name}-alb"
  description = "Sg to grouping alb-ingress ALBs in the ${var.cluster-name} cluster"
  vpc_id = "${var.aws_vpc}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https connectio to the ALB"
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = "${split(",", var.alb_sg_cidr)}"
  }
  ingress {
    description = "http connectio to https redirects"
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = "${split(",", var.alb_sg_cidr)}"
  }

  tags = "${
    map(
    "Name", "${var.cluster-name}-alb",
    "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}
resource "aws_security_group" "node-sg" {
  name = "${var.cluster-name}-node"
  description = "Security group for all nodes in the ${var.cluster-name} cluster"
  vpc_id = "${var.aws_vpc}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = "${
    map(
     "Name", "${var.cluster-name}",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "node-ingress-self" {
  description = "Allow node to communicate with each other"
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.node-sg.id}"
  source_security_group_id = "${aws_security_group.node-sg.id}"
  to_port = 65535
  type = "ingress"
}
resource "aws_security_group_rule" "node-ingress-alb" {
  count = "${var.enable_alb_sg ? 1 : 0}"
  description = "Allow node to communicate with with the ALBs"
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.node-sg.id}"
  source_security_group_id = "${aws_security_group.eks-alb[count.index].id}"
  to_port = 65535
  type = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
  description = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port = 1025
  protocol = "tcp"
  security_group_id = "${aws_security_group.node-sg.id}"
  source_security_group_id = "${aws_security_group.cluster-sg.id}"
  to_port = 65535
  type = "ingress"
}

#allow cominucation with master node
resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description = "Allow pods to communicate with the cluster API Server"
  from_port = 443
  protocol = "tcp"
  security_group_id = "${aws_security_group.cluster-sg.id}"
  source_security_group_id = "${aws_security_group.node-sg.id}"
  to_port = 443
  type = "ingress"
}

#AutoScaling group
data "aws_ami" "worker" {
  filter {
    name = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.cluster-eks.version}-v*"]
  }

  most_recent = true
  owners = ["602401143452"] # Amazon EKS AMI Account ID
}


#This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_region" "current" {}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We implement a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cluster-eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cluster-eks.certificate_authority.0.data}' '${aws_eks_cluster.cluster-eks.name}'
USERDATA
}

resource "aws_launch_configuration" "launch-config" {
  associate_public_ip_address = false
  enable_monitoring           = false
  iam_instance_profile        = "${aws_iam_instance_profile.node-profile.name}"
  image_id                    = "${data.aws_ami.worker.id}"
  instance_type               = "${var.instance-type}"
  name_prefix                 = "${var.cluster-name}"
  security_groups             = ["${aws_security_group.node-sg.id}"]
  user_data_base64            = "${base64encode(local.node-userdata)}"
  key_name                    = "${var.cluster-name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaling-group" {
  desired_capacity     = "${var.desired_capacity}"
  launch_configuration = "${aws_launch_configuration.launch-config.id}"
  max_size             = "${var.max_size}"
  min_size             = 1
  name                 = "${var.cluster-name}"
  vpc_zone_identifier  = ["${aws_subnet.private-subnet-1.id}", "${aws_subnet.private-subnet-2.id}"]

  tag {
    key                 = "Name"
    value               = "${var.cluster-name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.cluster-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}


