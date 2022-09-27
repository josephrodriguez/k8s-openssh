terraform {
  required_providers {

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.13.1"
    }

    tls = {
      source = "hashicorp/tls"
      version = "4.0.3"
    }
  }  
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

resource "kubernetes_config_map" "openssh_config_map" {
  metadata {
    name      = "openssh"
    namespace = kubernetes_namespace.openssh.id
  }

  data = {
    PGID         = "1000"
    PUID         = "1000"
    SUDO_ACCESS  = "true"
    TZ           = "Europe/London"
  }
}

resource "kubernetes_secret" "openssh_public_key" {
  metadata {
    name = "public-key"
    namespace = kubernetes_namespace.openssh.id
  }

  data = {
    PUBLIC_KEY  = tls_private_key.ssh_key.public_key_openssh
  }
}