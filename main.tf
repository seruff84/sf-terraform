terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.61.0"
    }
  }
}

provider "yandex" {
  token     = "AQAAAAARJlzzAATuwR3zAUB7cUU3pjwCWHjuw8s"
  cloud_id  = "b1giech89svtpr2sgq4c"
  folder_id = "b1gkk6na84ph4jq1hi38"
  zone      = "ru-central1-a"
}
resource "yandex_compute_instance" "vm-1" {
  name = "sf-kube-1"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20

  }

  boot_disk {
    initialize_params {
      image_id = "fd83klic6c8gfgi40urb"
      size     = 4
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = "${file("~/projects/learn-terraform/meta.txt")}"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]
    on_failure = continue
    connection {
      host        = "${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address}"
      type        = "ssh"
      user        = "seruff"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }


  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ~/projects/learn-terraform/kubernetes-setup/node-playbook.yml"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ~/projects/learn-terraform/kubernetes-setup/master-playbook.yml"
  }

}
resource "yandex_compute_instance" "vm-2" {
  name = "sf-kube-2"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20

  }

  boot_disk {
    initialize_params {
      image_id = "fd83klic6c8gfgi40urb"
      size     = 4
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = "${file("~/projects/learn-terraform/meta.txt")}"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]
    on_failure = continue
    connection {
      host        = "${yandex_compute_instance.vm-2.network_interface.0.nat_ip_address}"
      type        = "ssh"
      user        = "seruff"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm-2.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ~/projects/learn-terraform/kubernetes-setup/node-playbook.yml"
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm-2.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ~/projects/learn-terraform/kubernetes-setup/slave-playbook.yml"
  }
  provisioner "local-exec" {
    command = "kubectl apply -f  https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml"
  }

}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}
output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}
output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}

