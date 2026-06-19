terraform {
  backend "s3" {

bucket         = var.bucket_name
    key            = var.key_name
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = var.dynamodb_table # This line enables state locking    
    # This line enables state locking
    
  }
}
