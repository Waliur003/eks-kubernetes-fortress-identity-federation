//Create An ECR Repository named "devsecops-secure-app" 
resource "aws_ecr_repository" "devsecops_secure_app" {
  name                 = "devsecops-secure-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  
}

//Create The Lifecycle Policy for the ECR Repository created above and create a rule matching untagged images, and set the action to expire after 14 days
resource "aws_ecr_lifecycle_policy" "devsecops_secure_app_lifecycle_policy" {
  repository = aws_ecr_repository.devsecops_secure_app.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 14 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 14
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}