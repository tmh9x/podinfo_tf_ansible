resource "local_sensitive_file" "private_key" {
  content = tls_private_key.key.private_key_pem
  filename          = format("%s/%s/%s", abspath(path.root), ".ssh", "ansible-ssh-key.pem")
  file_permission   = "0600"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {
    ip_addrs = [for ip in module.ec2: ip.public_ip]
    ssh_keyfile = local_sensitive_file.private_key.filename
  })
  filename = format("%s/%s", abspath(path.root), "inventory.ini")
}