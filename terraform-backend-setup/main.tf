provider "aws" {
  region = "ap-south-1"
}

# A unique S3 bucket to store the Terraform state file
# Bucket names must be globally unique across all of AWS
resource "aws_s3_bucket" "terraform_state" {
  bucket = "cicd-tf-eks-sai" # <-- CHANGE THIS NAME

  # Prevent accidental deletion of the state file
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning to keep a history of your state files
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# A DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "eks-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
