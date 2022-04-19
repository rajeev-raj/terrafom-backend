terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
 }
backend "s3" {
 bucket         = "rajeev-terrform-example"
 key            = "state/terraform.tfstate"
 region         = "us-east-2"
 encrypt        = true
 kms_key_id     = "alias/terraform-bucket-key"
 dynamodb_table = "terraform-state"
 shared_credentials_file = "~/.aws/credentials"
 }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "app_server" {
    //ami = "ami-04505e74c0741db8d"
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = var.inst_type
    vpc_security_group_ids = ["sg-0da6f53e231cbfad4"]

/*    
    user_data = <<-EOF 
    #!/bin/bash
    apt update
    apt -y install apache2
    cat <<EOF > /var/www/html/index.html
    <html><body><p>Linux startup script from a local file.</p></body></html>
    EOF

 user_data = << EOF
#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "The page was created by the user data" | sudo tee /var/www/html/index.html
EOF
*/

user_data = "${file("user-data-apache.sh")}"
    tags = {
        Name = "ExampleAppServerInstance"
    }
  
}


resource "aws_kms_key" "terraform-bucket-key" {
 description             = "This key is used to encrypt bucket objects"
 deletion_window_in_days = 10
 enable_key_rotation     = true
}

resource "aws_kms_alias" "key-alias" {
 name          = "alias/terraform-bucket-key"
 target_key_id = aws_kms_key.terraform-bucket-key.key_id
}

resource "aws_s3_bucket" "terraform-state" {
 bucket = "rajeev-terrform-example"
 acl    = "private"

 versioning {
   enabled = true
 }

 server_side_encryption_configuration {
   rule {
     apply_server_side_encryption_by_default {
       kms_master_key_id = aws_kms_key.terraform-bucket-key.arn
       sse_algorithm     = "aws:kms"
     }
   }
 }
}

resource "aws_s3_bucket_public_access_block" "block" {
 bucket = aws_s3_bucket.terraform-state.id

 block_public_acls       = true
 block_public_policy     = true
 ignore_public_acls      = true
 restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform-state" {
 name           = "terraform-state"
 read_capacity  = 20
 write_capacity = 20
 hash_key       = "LockID"

 attribute {
   name = "LockID"
   type = "S"
 }
}

