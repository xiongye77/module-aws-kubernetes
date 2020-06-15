provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {}

# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "ms-cluster" {
  name = "ms-up-running-cluster"

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

resource "aws_iam_role_policy_attachment" "ms-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.ms-cluster.name
}

// resource "aws_iam_role_policy_attachment" "ms-cluster-AmazonEKSServicePolicy" {
//  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
//  role       = aws_iam_role.ms-cluster.name
//}

resource "aws_security_group" "ms-cluster" {
  name        = "ms-up-running-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ms-up-running"
  }
}

resource "aws_eks_cluster" "ms-up-running" {
  name     = var.cluster_name
  role_arn = aws_iam_role.ms-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.ms-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.ms-cluster-AmazonEKSClusterPolicy
  ]
}


#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

resource "aws_iam_role" "ms-node" {
  name = "ms-up-running-node"

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

resource "aws_iam_role_policy_attachment" "ms-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ms-node.name
}

resource "aws_iam_role_policy_attachment" "ms-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ms-node.name
}

resource "aws_iam_role_policy_attachment" "ms-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ms-node.name
}

resource "aws_eks_node_group" "ms-node-group" {
  cluster_name    = aws_eks_cluster.ms-up-running.name
  node_group_name = "microservices"
  node_role_arn   = aws_iam_role.ms-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.ms-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ms-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.ms-node-AmazonEC2ContainerRegistryReadOnly,
  ]

  # Setup kubeconfig using AWS.
  # This requires that kubectl and aws cli are both installed. It also requires that AWS 
  # credentials have been setup (either in the environment or in an AWS config file.)
  provisioner "local-exec" {
    command = "/usr/local/bin/aws eks --region $REGION update-kubeconfig --name $CLUSTER"

    environment = {
      REGION  = var.aws_region
      CLUSTER = var.cluster_name
    }
  }

  # Install Istio (default profile)
  # This requires that istioctl is installed and in the path
  # TODO - can I use the istio helm charts for this instead?
  provisioner "local-exec" {
    command = "./istio-1.6.0/bin/istioctl install -y"
  }
}

# Label the default namespeace so that pods will be injected with the Istio sidecar
resource "kubernetes_namespace" "istio-default-injector" {
  metadata {
    labels = {
      istio-injection = "enabled"
    }

    name = "default"
  }
}

#kubectl create namespace argocd
#resource "kubernetes_namespace" "argocd" {
#    name = "argocd" 
#}

#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#resource "kubernetes_" 
