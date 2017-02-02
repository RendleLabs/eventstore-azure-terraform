variable "resource_name_prefix" {}

variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

variable "location" {}

variable "vmusername" {}

variable "vmuserpassword" {}

variable "nodes" {
  default = "3"
}

variable "vm_size" {
  default = "Standard_D1_v2"
}

variable "storage_account_type" {
  default = "Standard_LRS"
}

variable "lb_backend_pool_name" {
  default = "backendPool1"
}

variable "lb_probe_name" {
  default = "tcpProbe"
}

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

resource "azurerm_resource_group" "es" {
  name     = "${var.resource_name_prefix}-es"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "es" {
  name                = "${var.resource_name_prefix}-vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.es.name}"
}

resource "azurerm_subnet" "es" {
  name                 = "${var.resource_name_prefix}-sn"
  resource_group_name  = "${azurerm_resource_group.es.name}"
  virtual_network_name = "${azurerm_virtual_network.es.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "es" {
  count                        = "${var.nodes}"
  name                         = "${var.resource_name_prefix}-es-ip-${count.index}"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.es.name}"
  domain_name_label            = "${var.resource_name_prefix}-es-${count.index}"
  public_ip_address_allocation = "static"
}

resource "azurerm_public_ip" "es-lb" {
  name                         = "${var.resource_name_prefix}-lb-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.es.name}"
  domain_name_label            = "${var.resource_name_prefix}-lb"
  public_ip_address_allocation = "static"
}

resource "azurerm_lb" "es" {
  name                = "${var.resource_name_prefix}-lb"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.es.name}"

  frontend_ip_configuration {
    name                 = "${var.resource_name_prefix}-lb-fe-ipconfig"
    public_ip_address_id = "${azurerm_public_ip.es-lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "es" {
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.es.name}"
  loadbalancer_id     = "${azurerm_lb.es.id}"
  name                = "${var.lb_backend_pool_name}"
}

resource "azurerm_network_interface" "es" {
  depends_on                = ["azurerm_lb_backend_address_pool.es"]
  count                     = "${var.nodes}"
  name                      = "${var.resource_name_prefix}-es-ni-${count.index}"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.es.name}"
  network_security_group_id = "${azurerm_network_security_group.es.id}"

  ip_configuration {
    name                                    = "es-configuration-${count.index}"
    subnet_id                               = "${azurerm_subnet.es.id}"
    private_ip_address_allocation           = "dynamic"
    public_ip_address_id                    = "${element(azurerm_public_ip.es.*.id, count.index)}"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb.es.id}/backendAddressPools/${var.lb_backend_pool_name}"]
  }
}

resource "azurerm_network_security_group" "es" {
  name                = "${var.resource_name_prefix}-es-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.es.name}"
}

resource "azurerm_network_security_rule" "inbound-http" {
  name                        = "eventstore-http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "2114"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.es.name}"
  network_security_group_name = "${azurerm_network_security_group.es.name}"
}

resource "azurerm_network_security_rule" "inbound-tcp" {
  name                        = "eventstore-tcp"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1112"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.es.name}"
  network_security_group_name = "${azurerm_network_security_group.es.name}"
}

resource "azurerm_network_security_rule" "inbound-ssh" {
  name                        = "ssh"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.es.name}"
  network_security_group_name = "${azurerm_network_security_group.es.name}"
}

resource "azurerm_storage_account" "es" {
  count               = "${var.nodes}"
  name                = "${var.resource_name_prefix}sys${count.index}"
  resource_group_name = "${azurerm_resource_group.es.name}"
  location            = "${var.location}"
  account_type        = "${var.storage_account_type}"

  tags {
    environment = "production"
  }
}

resource "azurerm_storage_container" "es" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.es.name}"
  storage_account_name  = "${element(azurerm_storage_account.es.*.name, count.index)}"
  container_access_type = "private"
}

resource "azurerm_availability_set" "es" {
  name                = "${var.resource_name_prefix}-availability-set"
  resource_group_name = "${azurerm_resource_group.es.name}"
  location            = "${var.location}"
}

resource "azurerm_virtual_machine" "es" {
  count                         = "${var.nodes}"
  name                          = "${var.resource_name_prefix}-es-${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.es.name}"
  network_interface_ids         = ["${element(azurerm_network_interface.es.*.id, count.index)}"]
  vm_size                       = "${var.vm_size}"
  availability_set_id           = "${azurerm_availability_set.es.id}"
  delete_os_disk_on_termination = "true"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "eventstorenode${count.index}osdisk1"
    vhd_uri       = "${element(azurerm_storage_account.es.*.primary_blob_endpoint, count.index)}${element(azurerm_storage_container.es.*.name, count.index)}/eventstorenode${count.index}osdisk1.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.resource_name_prefix}-es-${count.index}"
    admin_username = "${var.vmusername}"
    admin_password = "${var.vmuserpassword}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.vmusername}/ssh/authorized_keys"
      key_data = "${file("ssh/id_rsa.pub")}"
    }
  }

  tags {
    environment = "production"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "${var.vmusername}"
      private_key = "${file("ssh/id_rsa")}"
      host        = "${element(azurerm_public_ip.es.*.fqdn, count.index)}"
    }

    script = "./scripts/install.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "${var.vmusername}"
      private_key = "${file("ssh/id_rsa")}"
      host        = "${element(azurerm_public_ip.es.*.fqdn, count.index)}"
    }

    source      = "./scripts/configure.sh"
    destination = "/tmp/configure.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "${var.vmusername}"
      private_key = "${file("ssh/id_rsa")}"
      host        = "${element(azurerm_public_ip.es.*.fqdn, count.index)}"
    }

    inline = [
      "sudo chmod +x /tmp/configure.sh",
      "sudo /tmp/configure.sh ${element(azurerm_network_interface.es.*.private_ip_address, count.index)} ${join(" ", azurerm_network_interface.es.*.private_ip_address)}",
    ]
  }
}

resource "azurerm_lb_probe" "es" {
  depends_on          = ["azurerm_virtual_machine.es"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.es.name}"
  loadbalancer_id     = "${azurerm_lb.es.id}"
  name                = "${var.lb_probe_name}"
  protocol            = "tcp"
  port                = 2114
}

resource "azurerm_lb_rule" "es-http" {
  depends_on                     = ["azurerm_lb_probe.es"]
  location                       = "${var.location}"
  resource_group_name            = "${azurerm_resource_group.es.name}"
  loadbalancer_id                = "${azurerm_lb.es.id}"
  name                           = "eventstore-http"
  protocol                       = "tcp"
  frontend_port                  = 2114
  backend_port                   = 2114
  frontend_ip_configuration_name = "${var.resource_name_prefix}-lb-fe-ipconfig"
  probe_id                       = "${azurerm_lb.es.id}/probes/${var.lb_probe_name}"
  backend_address_pool_id        = "${azurerm_lb.es.id}/backendAddressPools/${var.lb_backend_pool_name}"
}

resource "azurerm_lb_rule" "es-tcp" {
  depends_on                     = ["azurerm_lb_probe.es"]
  location                       = "${var.location}"
  resource_group_name            = "${azurerm_resource_group.es.name}"
  loadbalancer_id                = "${azurerm_lb.es.id}"
  name                           = "eventstore-tcp"
  protocol                       = "tcp"
  frontend_port                  = 1112
  backend_port                   = 1112
  frontend_ip_configuration_name = "${var.resource_name_prefix}-lb-fe-ipconfig"
  probe_id                       = "${azurerm_lb.es.id}/probes/${var.lb_probe_name}"
  backend_address_pool_id        = "${azurerm_lb.es.id}/backendAddressPools/${var.lb_backend_pool_name}"
}
