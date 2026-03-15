output "master_public_ip" {
  value = oci_core_instance.k8s_nodes[0].public_ip
}

output "workers_public_ips" {
  value = [for i in oci_core_instance.k8s_nodes[*] : i.public_ip if i.display_name != "k8s-master"]
}