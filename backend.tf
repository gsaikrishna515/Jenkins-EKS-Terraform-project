terraform {
  backend "s3" {
    # Use the name of the S3 bucket you just created
    bucket         = "your-unique-eks-terraform-state-bucket" # <-- USE THE SAME NAME AS ABOVE
    key            = "eks-cluster/terraform.tfstate"         # The path/name of the state file within the bucket
    region         = "ap-south-1"

    # Use the name of the DynamoDB table you just created
    dynamodb_table = "eks-terraform-locks"
    encrypt        = true
  }
}
