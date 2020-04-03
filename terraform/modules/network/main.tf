resource "aws_vpc" "classv" {
  cidr_block       = "172.16.0.0/16"

  tags = {
    Name = "classv"
  }
}

resource "aws_subnet" "subnet-a" {
  vpc_id            = "${aws_vpc.classv.id}"
  cidr_block        = "172.16.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name                                        = "Public Subnet a"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/ytp"                 = "shared"
    "kubernetes.io/cluster/eks-classv"          = "shared"
    "kubernetes.io/role/alb-ingress"            = "" 
    "kubernetes.io/role/alb-ingress-controller" = "" 
    "kubernetes.io/role/ingress"                = "" 
  }
}

resource "aws_subnet" "subnet-b" {
  vpc_id            = "${aws_vpc.classv.id}"
  cidr_block        = "172.16.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/ytp"                 = "shared"
    "kubernetes.io/cluster/eks-classv"          = "shared"
    "kubernetes.io/role/alb-ingress"            = "" 
    "kubernetes.io/role/alb-ingress-controller" = "" 
    "kubernetes.io/role/ingress"                = "" 
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.classv.id}"

  tags = {
    Name = "classv-gw"
  }
}

resource "aws_route_table" "public-route" {
  vpc_id = "${aws_vpc.classv.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "classv-public"
  }
}

resource "aws_route_table_association" "subnet-a-association" {
  subnet_id      = "${aws_subnet.subnet-a.id}"
  route_table_id = "${aws_route_table.public-route.id}"
}

resource "aws_route_table_association" "subnet-b-association" {
  subnet_id      = "${aws_subnet.subnet-b.id}"
  route_table_id = "${aws_route_table.public-route.id}"
}

resource "aws_eip" "classv-nat-eip" {
  vpc = true
}

resource "aws_nat_gateway" "classv-nat" {
  allocation_id = "${aws_eip.classv-nat-eip.id}"
  subnet_id     = "${aws_subnet.subnet-a.id}"

  tags = {
    Name = "natgw clusters"
  }
}

resource "aws_route_table" "private-route" {
  vpc_id = "${data.aws_vpc.ytp.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.classv-nat.id}"
  }

  tags = {
    Name = "classv-private"
  }
}
