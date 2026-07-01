//Create role with EKS - Cluster as the common use case. Name it eks-cluster-role and ensure AmazonEKSClusterPolicy is attached
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<EOF
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
EOF
}   

//Create a second role with EC2 as the trusted entity use case for the worker nodes. Name it eks-worker-node-role and manually attach three managed policies:
resource "aws_iam_role" "eks_worker_node_role" {
  name = "eks-worker-node-role"

  assume_role_policy = <<EOF
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
EOF
}

//Attach the  managed policy named "AmazonEKSWorkerNodePolicy" to the eks-worker-node-role:
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

//Attach the  managed policy named "AmazonEC2ContainerRegistryReadOnly" to the eks-worker-node-role:
resource "aws_iam_role_policy_attachment" "eks_worker_node_ecr_readonly_policy_attachment" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

//Attach the  managed policy named "AmazonEKS_CNI_Policy" to the eks-worker-node-role:
resource "aws_iam_role_policy_attachment" "eks_worker_node_cni_policy_attachment" {
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

//Create AWS policy Document for AppS3ReadPolicy.json
data "aws_iam_policy_document" "app_s3_read_policy" {
  statement {
    sid    = "FortressS3BucketReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::fortress-secure-assets-bucket",
      "arn:aws:s3:::fortress-secure-assets-bucket/*"
    ]
  }
}


//Attach the policy document to the policy named "AppS3ReadPolicy" 
resource "aws_iam_policy" "app_s3_read_policy" {
  name        = "AppS3ReadPolicy"
  description = "Policy to allow read access to the fortress-secure-assets-bucket"
  policy      = data.aws_iam_policy_document.app_s3_read_policy.json
}


// Create the Federated Trust Relationship Document for the OIDC Provider
data "aws_iam_policy_document" "eks_secure_app_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:production-apps:secure-pod-sa"]
    }
  }
}

// Create the Web Identity Role
resource "aws_iam_role" "eks_secure_app_s3_role" {
  name               = "eks-secure-app-s3-role"
  assume_role_policy = data.aws_iam_policy_document.eks_secure_app_trust.json
}

// Attach your S3 Read Policy to the new Federated Role
resource "aws_iam_role_policy_attachment" "secure_app_s3_attachment" {
  role       = aws_iam_role.eks_secure_app_s3_role.name
  policy_arn = aws_iam_policy.app_s3_read_policy.arn
}



