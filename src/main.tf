variable "project_name" {}
variable "region_name" {}
variable "env" {}

data "archive_file" "lambda_function" {
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda.zip"
  type        = "zip"
}


provider "aws" {
	region = var.region_name    

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    access_key                  = "mock_access_key"
    secret_key                  = "mock_secret_key"
}

resource "aws_s3_bucket" "source_bucket" {
    bucket              = "s3-source-${var.project_name}-${var.region_name}"
    tags = {
        Name            = "S3 source bucket"
        Environment     = var.env
    }
    force_destroy = true
}

resource "aws_s3_bucket" "target_bucket" {
    bucket              = "s3-target-${var.project_name}-${var.region_name}"
    tags = {
        Name            = "S3_target_bucket"
        Environment     = var.env
    }
    force_destroy = true
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy-${var.project_name}-${var.region_name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:CopyObject",
        "s3:HeadObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::s3-source-${var.project_name}-${var.region_name}",
        "arn:aws:s3:::s3-source-${var.project_name}-${var.region_name}/*"
      ]
    },
    {
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:CopyObject",
        "s3:HeadObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::s3-target-${var.project_name}-${var.region_name}",
        "arn:aws:s3:::s3-target-${var.project_name}-${var.region_name}/*"
      ]
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3_copy_function" {
    name = "app-lambda-${var.project_name}-${var.region_name}"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_iam_policy_execution" {
  role = "${aws_iam_role.s3_copy_function.id}"
  policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}

resource "aws_lambda_permission" "allow_bucket" {
    statement_id = "AllowExecutionFromS3Bucket"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.s3_copy_function.arn}"
    principal = "s3.amazonaws.com"
    source_arn = "${aws_s3_bucket.source_bucket.arn}"
}

resource "aws_lambda_function" "s3_copy_function" {
    filename = "lambda.zip"
    source_code_hash = data.archive_file.lambda_function.output_base64sha256
    function_name = "app-lambda-s3-copy-${var.project_name}-${var.region_name}"
    role = "${aws_iam_role.s3_copy_function.arn}"
    handler = "main.handler"
    runtime = "python3.6"

    environment {
        variables = {
            TARGET_BUCKET = "s3-target-${var.project_name}-${var.region_name}",
            REGION = "${var.region_name}"
        }
    }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
    bucket = "${aws_s3_bucket.source_bucket.id}"
    lambda_function {
        lambda_function_arn = "${aws_lambda_function.s3_copy_function.arn}"
        events = ["s3:ObjectCreated:*"]
    }

    depends_on = [ aws_lambda_permission.allow_bucket ]
}