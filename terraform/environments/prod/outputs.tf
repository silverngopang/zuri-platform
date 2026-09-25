output "instance_public_ip" {
  value = module.compute.instance_public_ip
}

output "vpc_id" {
  value = module.networking.vpc_id
}
