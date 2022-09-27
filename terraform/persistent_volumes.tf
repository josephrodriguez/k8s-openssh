resource "kubernetes_persistent_volume" "openssh" {
  metadata {
    name = "example"
  }
  spec {
    capacity = {
      storage = "100Mi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/ssh/config"
        type = "Directory"
      }
    }
  }
}