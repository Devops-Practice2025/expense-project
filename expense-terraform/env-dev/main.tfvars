env = "dev"
vpc_cidr = "10.0.0.0/16"

subnets = {
    public-1a  = {
        cidr = "10.0.1.0/24"
        availability_zone = "us-east-1a"
        is_public = true
    }
    public-1b = {
        cidr = "10.0.2.0/24"
        availability_zone = "us-east-1b"
        is_public = true
}

private-app-1a  = {
        cidr = "10.0.3.0/24"
        availability_zone = "us-east-1a"
        is_public = false
    }
    private-app-1b = {
        cidr = "10.0.4.0/24"
        availability_zone = "us-east-1b"
        is_public = false
}


    private-db-1b = {
        cidr = "10.0.5.0/24"
        availability_zone = "us-east-1b"
        is_public = false
}

private-db-1b = {
        cidr = "10.0.6.0/24"
        availability_zone = "us-east-1b"
        is_public = false
}
}