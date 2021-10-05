resource "yandex_compute_instance" "vm" {
  for_each	= toset(var.vm_name)
  name		= each.value
  resources {
    cores         = var.yc_cores
    memory        = var.yc_memory
    core_fraction = 20

  }

  boot_disk {
    initialize_params {
      image_id = var.yc_imageid
      size     = var.yc_disk_size
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
      host        = "${self.network_interface.0.nat_ip_address}"
      type        = "ssh"
      user        = "seruff"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
 }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ./kubernetes-setup/node-playbook.yml"
  }
}

resource "time_sleep" "wait_20_seconds" {
  depends_on = [yandex_compute_instance.vm]
  provisioner "local-exec" {
    command = "rm -f ./kubernetes-setup/kubernetes-setup"
  }
  create_duration = "20s"
}

resource "null_resource" "next1" {
  depends_on	= [time_sleep.wait_20_seconds]
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm[element(var.vm_name, 0)].network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ./kubernetes-setup/master-playbook.yml"
  }
}
resource "null_resource" "next2" {
  depends_on	= [time_sleep.wait_20_seconds]
  for_each	= toset(slice(var.vm_name, 1, length(var.vm_name)))
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u seruff -i '${yandex_compute_instance.vm[each.key].network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa -e 'pub_key=~/.ssh/id_rsa.pub' ./kubernetes-setup/slave-playbook.yml"
  }
}
resource "null_resource" "next3" {
  depends_on    = [null_resource.next2]
  provisioner "local-exec" {
    command = "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
  }
}
output "external_ip_addresses" {
  value = {
    for k, v in yandex_compute_instance.vm : k=> v.network_interface.0.nat_ip_address
  }
}

output "count_external_ip_addresses" {
  value = length(yandex_compute_instance.vm)

}
