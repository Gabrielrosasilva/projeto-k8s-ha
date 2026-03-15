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