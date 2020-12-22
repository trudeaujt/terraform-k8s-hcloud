resource "null_resource" "kube-cni" {
  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm repo add cilium https://helm.cilium.io/"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm repo add mlohr https://helm-charts.mlohr.com/"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm repo update"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm install -n kube-system hcloud-csi-driver mlohr/hcloud-csi-driver --set csiDriver.secret.create=true --set csiDriver.secret.hcloudApiToken=${var.hcloud_token}"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm install -n kube-system hcloud-cloud-controller-manager mlohr/hcloud-cloud-controller-manager --set manager.secret.create=true --set manager.secret.hcloudApiToken=${var.hcloud_token} --set manager.privateNetwork.enabled=true --set manager.loadBalancers.enabled=true --set manager.privateNetwork.id=${hcloud_network.kubenet.id} --set manager.privateNetwork.clusterSubnet=10.88.0.0/16"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf helm install cilium cilium/cilium --version 1.9.1 --namespace kube-system --set prometheus.enabled=true --set devices='{eth0}' --set hostFirewall=true"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf kubectl apply -f ./cilium-firewall.yaml"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf kubectl apply -f ./monitoring-ns.yaml"
  }

  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf kubectl -n monitoring create secret generic etcd-client --from-file=\"secrets/pki/etcd/ca.crt\" --from-file=\"secrets/pki/etcd/healthcheck-client.crt\" --from-file=\"secrets/pki/etcd/healthcheck-client.key\""
  }

  depends_on = [hcloud_server.master, hcloud_network.kubenet, null_resource.init_masters, null_resource.init_workers]
}

resource "null_resource" "post_restart_masters" {
  depends_on = [null_resource.kube-cni]
  count       = var.master_count
  connection {
    host        = hcloud_server.master[count.index].ipv4_address
    type        = "ssh"
    port        = var.ssh_port
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = ["systemctl restart kubelet"]
  }
}

resource "null_resource" "post_restart_nodes" {
  depends_on = [null_resource.kube-cni]
  count       = var.node_count
  connection {
    host        = hcloud_server.node[count.index].ipv4_address
    type        = "ssh"
    port        = var.ssh_port
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = ["systemctl restart kubelet"]
  }
}

