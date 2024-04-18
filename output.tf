output "server-data" {
  value       = [for ip in module.ec2 : {
    ip = ip
  }]
  description = "The public IP and DNS of the servers"
}