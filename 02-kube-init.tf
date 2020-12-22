resource "null_resource" "init_main_master" {
  connection {
    host = hcloud_server.master[0].ipv4_address
    type = "ssh"
    port = var.ssh_port
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source = "files/10-kubeadm.conf"
    destination = "/root/10-kubeadm.conf"
  }

  provisioner "file" {
    source = "scripts/kube-bootstrap.sh"
    destination = "/root/kube-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "DOCKER_VERSION=${var.docker_version} KUBERNETES_VERSION=${var.kubernetes_version} MASTER_INDEX=1 bash /root/kube-bootstrap.sh"]
  }

  provisioner "file" {
    source = "scripts/kube-main-master.sh"
    destination = "/root/kube-main-master.sh"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/secrets && touch ${path.module}/secrets/kubeadm_control_plane_join"
  }

  provisioner "remote-exec" {
    inline = [
      "FEATURE_GATES=${var.feature_gates} LB_IP=${hcloud_load_balancer.kube_load_balancer.ipv4} bash /root/kube-main-master.sh"]
  }

  provisioner "local-exec" {
    command = "bash scripts/copy-kubeadm-token.sh"

    environment = {
      SSH_PRIVATE_KEY = var.ssh_private_key
      SSH_USERNAME = "root"
      SSH_PORT = var.ssh_port
      SSH_HOST = hcloud_server.master[0].ipv4_address
      TARGET = "${path.module}/secrets/"
    }
  }
}

resource "null_resource" "init_masters" {
  depends_on = [null_resource.init_main_master]
  count = var.master_count
  connection {
    host = hcloud_server.master[count.index].ipv4_address
    type = "ssh"
    port = var.ssh_port
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source = "files/10-kubeadm.conf"
    destination = "/root/10-kubeadm.conf"
  }

  provisioner "file" {
    source = "scripts/kube-bootstrap.sh"
    destination = "/root/kube-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "DOCKER_VERSION=${var.docker_version} KUBERNETES_VERSION=${var.kubernetes_version} MASTER_INDEX=${count.index} bash /root/kube-bootstrap.sh"]
  }

  provisioner "file" {
    source = "scripts/kube-master.sh"
    destination = "/root/kube-master.sh"
  }

  provisioner "file" {
    source = "${path.module}/secrets/kubeadm_control_plane_join"
    destination = "/tmp/kubeadm_control_plane_join"
  }

  provisioner "remote-exec" {
    inline = [
      "FEATURE_GATES=${var.feature_gates} MASTER_INDEX=${count.index} bash /root/kube-master.sh"]
  }
}

resource "null_resource" "init_workers" {
  depends_on = [null_resource.init_masters]
  count = var.node_count
  connection {
    host = hcloud_server.node[count.index].ipv4_address
    type = "ssh"
    port = var.ssh_port
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source = "files/10-kubeadm.conf"
    destination = "/root/10-kubeadm.conf"
  }

  provisioner "file" {
    source = "scripts/kube-bootstrap.sh"
    destination = "/root/kube-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "DOCKER_VERSION=${var.docker_version} KUBERNETES_VERSION=${var.kubernetes_version} bash /root/kube-bootstrap.sh"]
  }

  provisioner "remote-exec" {
    inline = [
      "kubeadm token create --print-join-command > /tmp/kubeadm_join_${count.index + 1}"]

    connection {
      host        = hcloud_server.master[0].ipv4_address
      type        = "ssh"
      port        = var.ssh_port
      user        = "root"
      private_key = file(var.ssh_private_key)
    }
  }

  provisioner "local-exec" {
    command = "bash scripts/copy-join-token.sh"

    environment = {
      SSH_PRIVATE_KEY = var.ssh_private_key
      SSH_USERNAME = "root"
      SSH_PORT = var.ssh_port
      SSH_HOST = hcloud_server.master[0].ipv4_address
      TARGET = "${path.module}/secrets/"
      ID = count.index + 1
    }
  }

  provisioner "file" {
    source = "${path.module}/secrets/kubeadm_join_${count.index + 1}"
    destination = "/tmp/kubeadm_join"
  }

  provisioner "file" {
    source = "scripts/kube-node.sh"
    destination = "/root/kube-node.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /root/kube-node.sh"]
  }
}