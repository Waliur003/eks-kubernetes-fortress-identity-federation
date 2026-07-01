//Create EKS cluster named "kubernetes-fortress" in the AWS region specified by the variable "aws_region"
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name       = "kubernetes-fortress"
  kubernetes_version = "1.28"

  vpc_id     = aws_vpc.project8_vpc.id 
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  endpoint_private_access = true
  endpoint_public_access  = true

  endpoint_public_access_cidrs = [
    "0.0.0.0/0"
  ]

  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  addons = {
    coredns = {}

    kube-proxy = {}

    vpc-cni = {
      before_compute = true
    }

    eks-pod-identity-agent = {
      before_compute = true
    }

    aws-ebs-csi-driver = {}
  }

  eks_managed_node_groups = {
    general = {
      name = "general"

      ami_type       = "ubuntu"
      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      capacity_type = "ON_DEMAND"

      labels = {
        role = "general"
      }

      tags = {
        NodeGroup = "general"
      }
    }
  }

  tags = {
    Environment = "Production"
    Project     = "Kubernetes-Fortress"
  }
}