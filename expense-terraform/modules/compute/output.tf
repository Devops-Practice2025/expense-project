output "instance_ip_map" { 
    value = { for k, v in module.compute.this : k => v.private_ip } # You need to export this in compute outputs
    }
    # modules/compute/output.tf
output "this" {
  value = aws_instance.your_instance_resource_name 
}

