##########################################################
# ECR Repositories
##########################################################
resource "aws_ecr_repository" "classv-backend" {
    name = "classv-backend"
}

resource "aws_ecr_repository" "classv-fronend" {
    name = "classv-frontend"
}
