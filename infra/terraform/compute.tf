# Busca a imagem mais recente do Oracle Linux 9 ARM
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E5.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Cria 3 instâncias: 1 para o Master (index 0) e 2 para Workers (index 1 e 2)
resource "oci_core_instance" "k8s_nodes" {
  count               = 3
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  
  # Nomeia as máquinas dinamicamente: k8s-master, k8s-worker-1, k8s-worker-2
  display_name        = count.index == 0 ? "k8s-master" : "k8s-worker-${count.index}"
  shape               = "VM.Standard.E5.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.k8s_subnet.id
    display_name     = "vnic-${count.index}"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    # Aqui usamos a variável da sua chave pública SSH
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }
}

# Necessário para pegar o Availability Domain
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [master]
    k8s-master ansible_host=${oci_core_instance.k8s_nodes[0].public_ip} ansible_user=opc ansible_ssh_private_key_file=ssh_private_key.pem

    [workers]
    k8s-worker-1 ansible_host=${oci_core_instance.k8s_nodes[1].public_ip} ansible_user=opc ansible_ssh_private_key_file=ssh_private_key.pem
    k8s-worker-2 ansible_host=${oci_core_instance.k8s_nodes[2].public_ip} ansible_user=opc ansible_ssh_private_key_file=ssh_private_key.pem

    [k8s_cluster:children]
    master
    workers
  EOT
  
  # Como a pipeline roda na raiz, vamos salvar o inventário na raiz temporariamente
  filename = "${path.module}/../../inventory.ini"
}

  resource "null_resource" "update_cloudns" {
  # Isso garante que ele só vai rodar DEPOIS que a máquina Master for criada
  depends_on = [oci_core_instance.k8s_nodes]

  # Dispara a requisição para o CloudNS com o novo IP
  provisioner "local-exec" {
    command = "curl -s 'https://ipv4.cloudns.net/api/dynamicURL/?q=COLOQUE_SEU_CODIGO_AQUI&ip=${oci_core_instance.k8s_nodes[0].public_ip}'"
  }
}