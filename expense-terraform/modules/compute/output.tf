output "instance_ip_map" { 
    value = { for k, v in module.compute.this : k => v.private_ip } # You need to export this in compute outputs
    }
