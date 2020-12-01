provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "k8s_admin" {
  name       = "k8s_admin"
  public_key = file(var.ssh_public_key)
}

resource "hcloud_network" "kubenet" {
  name = "kubenet"
  ip_range = "10.88.0.0/16"
}

resource "hcloud_network_subnet" "kubenet" {
  network_id = hcloud_network.kubenet.id
  type = "server"
  network_zone = "eu-central"
  ip_range   = "10.88.0.0/16"
}

resource "hcloud_load_balancer" "kube_load_balancer" {
  name       = "kube-lb"
  load_balancer_type = "lb11"
  location   = var.location
}

resource "hcloud_load_balancer_service" "kube_load_balancer_service" {
  load_balancer_id = hcloud_load_balancer.kube_load_balancer.id
  protocol = "tcp"
  listen_port = 6443
  destination_port = 6443
}

resource "hcloud_server" "master" {
  depends_on = [hcloud_load_balancer.kube_load_balancer]
  count       = var.master_count
  name        = "${var.cluster_name}-master-${count.index + 1}"
  location   = var.location
  server_type = var.master_type
  image       = var.master_image
  ssh_keys    = [hcloud_ssh_key.k8s_admin.id]

  connection {
    host        = self.ipv4_address
    type        = "ssh"
    private_key = file(var.ssh_private_key)
  }

  provisioner "local-exec" {
    command = "LB_ID=${hcloud_load_balancer.kube_load_balancer.id} KUBE_TOKEN=${var.hcloud_token} SERVER_ID=${self.id} bash scripts/add_lb.sh"
  }

  provisioner "file" {
    source      = "files/10-kubeadm.conf"
    destination = "/root/10-kubeadm.conf"
  }

  provisioner "file" {
    source      = "scripts/bootstrap.sh"
    destination = "/root/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = ["DOCKER_VERSION=${var.docker_version} KUBERNETES_VERSION=${var.kubernetes_version} bash /root/bootstrap.sh"]
  }

  provisioner "file" {
    source      = "scripts/master.sh"
    destination = "/root/master.sh"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/secrets && touch ${path.module}/secrets/kubeadm_control_plane_join"
  }

  provisioner "file" {
    source      = "${path.module}/secrets/kubeadm_control_plane_join"
    destination = "/tmp/kubeadm_control_plane_join"

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key)
    }
  }

  provisioner "remote-exec" {
    inline = ["FEATURE_GATES=${var.feature_gates} LB_IP=${hcloud_load_balancer.kube_load_balancer.ipv4} MASTER_INDEX=${count.index} bash /root/master.sh"]
  }

  provisioner "local-exec" {
    command = "bash scripts/copy-kubeadm-token.sh"

    environment = {
      SSH_PRIVATE_KEY = var.ssh_private_key
      SSH_USERNAME    = "root"
      SSH_HOST        = hcloud_server.master[0].ipv4_address
      TARGET          = "${path.module}/secrets/"
    }
  }
}

resource "hcloud_server" "node" {
  count       = var.node_count
  name        = "${var.cluster_name}-node-${count.index + 1}"
  server_type = var.node_type
  image       = var.node_image
  location    = var.location
  depends_on  = [hcloud_server.master]
  ssh_keys    = [hcloud_ssh_key.k8s_admin.id]

  connection {
    host        = self.ipv4_address
    type        = "ssh"
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source      = "files/10-kubeadm.conf"
    destination = "/root/10-kubeadm.conf"
  }

  provisioner "file" {
    source      = "scripts/bootstrap.sh"
    destination = "/root/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = ["DOCKER_VERSION=${var.docker_version} KUBERNETES_VERSION=${var.kubernetes_version} bash /root/bootstrap.sh"]
  }


  provisioner "remote-exec" {
    inline = ["kubeadm token create --print-join-command > /tmp/kubeadm_join_${count.index + 1}"]

    connection {
      host        = hcloud_server.master[0].ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key)
    }
  }

  provisioner "local-exec" {
    command = "bash scripts/copy-join-token.sh"

    environment = {
      SSH_PRIVATE_KEY = var.ssh_private_key
      SSH_USERNAME    = "root"
      SSH_HOST        = hcloud_server.master[0].ipv4_address
      TARGET          = "${path.module}/secrets/"
      ID              = count.index + 1
    }
  }

  provisioner "file" {
    source      = "${path.module}/secrets/kubeadm_join_${count.index + 1}"
    destination = "/tmp/kubeadm_join"

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key)
    }
  }

  provisioner "file" {
    source      = "scripts/node.sh"
    destination = "/root/node.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/node.sh"]
  }
}

resource "hcloud_server_network" "master_network" {
  count       = var.master_count
  depends_on  = [hcloud_server.master]
  server_id = hcloud_server.master[count.index].id
  network_id = hcloud_network.kubenet.id
}

resource "hcloud_server_network" "node_network" {
  count       = var.node_count
  depends_on  = [hcloud_server.node]
  server_id = hcloud_server.node[count.index].id
  network_id = hcloud_network.kubenet.id
}
