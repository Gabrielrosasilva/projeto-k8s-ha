resource "oci_core_vcn" "k8s_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "vcn-k8s-ha"
}

resource "oci_core_internet_gateway" "k8s_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "igw-k8s-ha"
}

resource "oci_core_default_route_table" "k8s_route_table" {
  manage_default_resource_id = oci_core_vcn.k8s_vcn.default_route_table_id
  route_rules {
    network_entity_id = oci_core_internet_gateway.k8s_igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "k8s_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "sec-list-k8s"

  # Permite acessar via SSH da sua maquina
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options { 
      min = 22
      max = 22 
    }
  }

  # Permite trafego HTTP (80) e HTTPS (443) para o Load Balancer e Nginx
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { 
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Permite comunicacao interna total entre os nós do K3s
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }
  
  # Permite tudo para fora (saida de internet)
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "k8s_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.k8s_vcn.id
  display_name      = "subnet-k8s-nodes"
  security_list_ids = [oci_core_security_list.k8s_security_list.id]
}