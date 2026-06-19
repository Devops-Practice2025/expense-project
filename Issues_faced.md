 
 S3 bucket versioning enabled
 aws s3api put-bucket-versioning --bucket  techkarthi17062026 --versioning-configuration Status=enabled

An error occurred (MalformedXML) when calling the PutBucketVersioning operation: The XML you provided was not well-formed or did not validate against our published schema
aws validates against its xml schema for commands
Issue enabled should be Enabled 

 aws s3api create-bucket \
    --bucket techkarthi170626 \
    --region us-east-1
 aws dynamodb create-table \
    --table-name terraform-lock-table \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

terraform apply -auto-approve -var-file="env-dev/main.tfvars"
terraform init -backend-config="state.tfvars"

terraform init -backend-config=env-dev/state.tfvars
Initializing the backend...
Initializing modules...
╷
│ Error: Backend configuration changed
│
│ A change in the backend configuration has been detected, which may require migrating existing state.
│
│ If you wish to attempt automatic migration of the state, use "terraform init -migrate-state".
│ If you wish to store the current configuration with no changes to the state, use "terraform init -reconfigure".