terraform {

  cloud {
    organization = "KELLY-training"
    workspaces {
      name = "deploy-nginx-kubernetes"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.48.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "remote"

  config = {
    organization = "KELLY-training"
    workspaces = {
      name = "eks-cluster"
    }
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = "us-east-2"
  #access_key = "ASIAWQDBY64J6HXKI5TV"
  #secret_key = "UYzUahXMm1E0KbD66+BBBXBCR5q8j79Qr0I68Unf"
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name = "bb-demo"
    labels = {
      App = "RandomQuotesExamp"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "web"
      }
    }
    template {
      metadata {
        labels = {
          App = "web"
        }
      }
      spec {
        container {
          image = "octopussamples/randomquotes-k8s"
          name  = "bb-site"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }         
        }
      }
    }
  }
}

resource "kubernetes_service" "test" {
  metadata {
    name = "bb-entrypoint"
    namespace = "default"
  }
  spec {
    type = "NodePort"
    selector = {
      App = kubernetes_deployment.app.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
      node_port = 8081
    }
  }
}

output "lb_ip" {
  value = kubernetes_service.test.status.0.load_balancer.0.ingress.0.hostname
}
