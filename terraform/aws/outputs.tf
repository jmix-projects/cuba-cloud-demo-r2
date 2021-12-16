output "instance_public_dns" {
  value = module.instance.public_dns
}

output "instance_public_ip" {
  value = module.instance.public_ip
}

output "main-db_name" {
  value = module.main-db.db_instance_name
}

output "main-db_username" {
  value     = module.main-db.db_instance_username
  sensitive = true
}

output "main-db_password" {
  value     = module.main-db.db_instance_password
  sensitive = true
}

