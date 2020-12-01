resource "null_resource" "kube-cni" {
  provisioner "local-exec" {
    command = "KUBECONFIG=secrets/admin.conf kubectl create -n kube-system secret generic cilium-ipsec-keys --from-literal=keys=\"3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null| xxd -p -c 64)) 128\""
  }

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
    command = "KUBECONFIG=secrets/admin.conf helm install cilium cilium/cilium --version 1.8.4 --namespace kube-system --set global.prometheus.enabled=true --set global.encryption.enabled=true --set global.encryption.nodeEncryption=false --set global.devices='{eth0}'"
  }

  depends_on = [hcloud_server.master, hcloud_network.kubenet]
}

resource "null_resource" "post_restart_masters" {
  depends_on = [null_resource.kube-cni]
  count       = var.master_count
  connection {
    host        = hcloud_server.master[count.index].ipv4_address
    type        = "ssh"
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
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = ["systemctl restart kubelet"]
  }
}
