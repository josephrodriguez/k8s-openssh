resource "kubernetes_namespace" "openssh" {
  metadata {
    name = "openssh"
  }
}