provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "eks-vpc" }
}

resource "aws_subnet" "eks_subnet_a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "eks_subnet_b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.eks_vpc.id
  name   = "eks-cluster-sg"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-security-group" }
}

resource "aws_security_group" "node_sg" {
  vpc_id = aws_vpc.eks_vpc.id
  name   = "eks-node-sg"

  ingress {
    from_port        = 1025
    to_port          = 65535
    protocol         = "tcp"
    security_groups  = [aws_security_group.eks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-node-security-group" }
}

resource "aws_eks_cluster" "devops_demo" {
  name     = "devops-demo"
  role_arn = "arn:aws:iam::443370691052:role/awsfullaccessrole"

  vpc_config {
    subnet_ids         = [aws_subnet.eks_subnet_a.id, aws_subnet.eks_subnet_b.id]
    security_group_ids = [aws_security_group.eks_sg.id]
  }
}

resource "aws_eks_node_group" "devops_demo_nodes" {
  cluster_name    = aws_eks_cluster.devops_demo.name
  node_group_name = "devops-demo-nodes"
  node_role_arn   = "arn:aws:iam::443370691052:role/awsfullaccessrole"
  subnet_ids      = [aws_subnet.eks_subnet_a.id, aws_subnet.eks_subnet_b.id]
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.devops_demo]
}
