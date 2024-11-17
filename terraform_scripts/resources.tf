# Define a VPC using the Terraform AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "my-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

  # Define public subnets
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Define a custom security group for EKS
resource "aws_security_group" "eks_security_group" {
  name        = "eks-security-group"
  description = "Security group for EKS cluster"
  vpc_id      = module.vpc.vpc_id

  # Define ingress rules
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all inbound traffic not recommended for production
  }

  # Define egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-security-group"
  }
}

# Create an EKS cluster using the Terraform AWS EKS module
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.31"

  # Networking configuration
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  cluster_endpoint_public_access = true

  # Security group
  cluster_security_group_id = aws_security_group.eks_security_group.id

  # Enable EKS addons
  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  # Define EKS managed node groups
  eks_managed_node_groups = {
    eks_nodes = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_type  = "t3.medium"
      key_name       = "EKS-Cluster"

      desired_capacity          = 2
      max_capacity              = 3
      min_capacity              = 1
      additional_security_groups = [aws_security_group.eks_security_group.id]
    }
  }

  # Grant admin permissions to the creator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Project     = "EKS"
  }
}

# Create multiple EC2 instances for various tools
module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  for_each = toset(["Jenkins", "SonarQube", "Nexus"])

  name = each.key

  instance_type          = "t3.medium"
  key_name               = "Jenkins"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.eks_security_group.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
