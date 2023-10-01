#s3 bucket for terraform backend
resource "aws_s3_bucket" "s3backend" {
  bucket = "bootcamp32-${lower(var.env)}-${random_integer.s3backend.result}"

  logging {
    target_bucket = "target-bucket"
  }

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "replication" {
  name               = "test"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.s3backend.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = [aws_s3_bucket.s3backend.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = [aws_s3_bucket.s3backend.arn]
  }
}

resource "aws_iam_policy" "replication" {
  name   = "test"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}


resource "aws_s3_bucket_acl" "source_bucket_acl" {

  bucket = aws_s3_bucket.s3backend.id
  acl    = "private"
}



resource "aws_s3_bucket_replication_configuration" "replication" {

  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.versioning_example]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.s3backend.id

  rule {
    id = "foobar"

    filter {
      prefix = "foo"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.s3backend.arn
      storage_class = "STANDARD"
    }
  }
}

#s3 bucket event notification

#resource "aws_sns_topic" "user_updates" {
#name = "user-updates-topic"
#{
#"Version": "2012-10-17",
#"Id": "example-ID",
#"Statement": [
#{
#"Sid": "example-statement-ID",
#"Effect": "Allow",
#"Principal": {
#"Service": "s3.amazonaws.com"
#},
#"Action": [
#"SQS:SendMessage"
#],
#"Resource": "SQS-queue-ARN",
#"Condition": {
#"ArnLike": {
#"aws:SourceArn": "arn:aws:s3:*:*:awsexamplebucket1"
#},
#"StringEquals": {
#"aws:SourceAccount": "bucket-owner-account-id"
#}
#}
#}
#]
#}
#}






resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.s3backend.id

  rule {
    id = "rule-1"

    # ... other transition/expiration actions ...

    status = "Enabled"
  }
}





resource "aws_s3_bucket_public_access_block" "good_example" {
  bucket                  = aws_s3_bucket.s3backend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



#kms key for bucket encryption
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.mykey.id
  policy = jsonencode({
    Id = "example"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }

        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
    ]
    Version = "2012-10-17"
  })
}


resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.s3backend.id #reference the bucket here

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}



#random integer for bucket naming convetion
resource "random_integer" "s3backend" {
  min = 1
  max = 100
  keepers = {
    # Generate a new integer each time we switch to a new listener ARN
    Environment = var.env #if there is change in dev env. the value will change
  }
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.s3backend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_instance" "my-test" {
  ami                  = data.aws_ami.amzlinux2.id
  instance_type        = "t2.micro"
  monitoring           = true
  ebs_optimized        = true
  iam_instance_profile = "test"

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }


}
# Get latest AMI ID for Amazon Linux2 OS
data "aws_ami" "amzlinux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


