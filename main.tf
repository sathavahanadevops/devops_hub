provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "eks-vpc" }
}

# Subnets
resource "aws_subnet" "eks_subnet_a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "eks_subnet_b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Private Subnets
resource "aws_subnet" "eks_private_subnet_a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "eks_private_subnet_b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
}

# Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags   = { Name = "eks-internet-gateway" }
}

# Route Table
resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = { Name = "eks-route-table" }
}

resource "aws_route_table_association" "eks_subnet_a_association" {
  subnet_id      = aws_subnet.eks_subnet_a.id
  route_table_id = aws_route_table.eks_route_table.id
}

resource "aws_route_table_association" "eks_subnet_b_association" {
  subnet_id      = aws_subnet.eks_subnet_b.id
  route_table_id = aws_route_table.eks_route_table.id
}

# Security Groups
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

# EKS Cluster
resource "aws_eks_cluster" "devops_demo" {
  name     = "devops-demo"
  role_arn = "arn:aws:iam::443370691052:role/awsfullaccessrole"

  vpc_config {
    subnet_ids             = [aws_subnet.eks_subnet_a.id, aws_subnet.eks_subnet_b.id]
    security_group_ids     = [aws_security_group.eks_sg.id]
    endpoint_public_access = true
  }
}

# EKS Node Group
resource "aws_eks_node_group" "devops_demo_nodes" {
  cluster_name    = aws_eks_cluster.devops_demo.name
  node_group_name = "devops-demo-nodes"
  node_role_arn   = "arn:aws:iam::443370691052:role/awsfullaccessrole"
  subnet_ids      = [aws_subnet.eks_subnet_a.id, aws_subnet.eks_subnet_b.id]
  instance_types  = ["t2.micro"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.devops_demo]
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.devops_demo.name
  addon_name   = "coredns"
  preserve     = false
}

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.devops_demo.name
  addon_name   = "vpc-cni"
  preserve     = false
}

# Kube Proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.devops_demo.name
  addon_name   = "kube-proxy"
  preserve     = false
}

# ECR Repository for storing container images
resource "aws_ecr_repository" "html_repo" {
  name = "html-service-repo"
}

resource "aws_ecr_repository" "nodejs_repo" {
  name = "nodejs-service-repo"
}

# Cluster Autoscaler Add-on
resource "aws_eks_addon" "cluster_autoscaler" {
  cluster_name = aws_eks_cluster.devops_demo.name
  addon_name   = "cluster-autoscaler"
  preserve     = false
}



# AWS Load Balancer Controller (Required for Ingress)
resource "aws_eks_addon" "aws_lb_controller" {
  cluster_name = aws_eks_cluster.devops_demo.name
  addon_name   = "aws-load-balancer-controller"
  preserve     = false
}

# Install Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "kube-system"
}

# Ingress Resource for app.revelaservices.in
resource "kubernetes_ingress_v1" "revela_ingress" {
  metadata {
    name      = "revela-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                 = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    rule {
      host = "app.revelaservices.in"
      http {
        path {
          path      = "/html"
          path_type = "Prefix"
          backend {
            service {
              name = "html-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/nodejs"
          path_type = "Prefix"
          backend {
            service {
              name = "nodejs-service"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}
