#############################################
# CUSTOMIZATIONS
#############################################
# https://github.com/fpco/terraform-aws-foundation/tree/master/modules/s3-remote-state

terraform { required_version = "~> 0.11" }
provider "aws" { version = "~> 1.54.0" region  = "${var.region}" }

resource "aws_s3_bucket_policy" "b" {
  bucket = "${aws_s3_bucket.remote-state.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.remote-state.bucket}/*",
      "Condition": {
         "IpAddress": {"aws:SourceIp": "8.8.8.8/32"}
      }
    }
  ]
}
POLICY
}

variable "region" {
  default = "us-east-2"
}

#############################################
# /CUSTOMIZATIONS
#############################################

/**
 * ## S3 Bucket to Store Remote State
 *
 * This module creates a private S3 bucket and IAM policy to access that bucket.
 * The bucket can be used as a remote storage bucket for `terraform`, `kops`, or
 * similar tools.
 *
 */

variable "bucket_name" {
  description = "the name to give the bucket"
}

variable "principals" {
  default     = []
  description = "list of user/role ARNs to get full access to the bucket"
}

variable "versioning" {
  default     = "true"
  description = "enables versioning for objects in the S3 bucket"
}

variable "force_destroy" {
  description = "Whether to allow a forceful destruction of this bucket"
  default     = false
}

resource "aws_s3_bucket" "remote-state" {
  bucket = "${var.bucket_name}"
  acl    = "private"
  region = "${var.region}"
  force_destroy = "${var.force_destroy}"

  versioning {
    enabled = "${var.versioning}"
  }
}

# Lookup the current AWS partition
data "aws_partition" "current" {}

data "aws_iam_policy_document" "s3-full-access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]

    principals {
      type        = "AWS"
      identifiers = ["${compact(var.principals)}"]
    }

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}"]
  }

  statement {
    effect = "Allow"

    # find an authoritative list of valid Actions for a AWS bucket policy,
    # I haven't been able to locate one, and the two commented out are invalid
    actions = [
      #     "s3:ListObjects",
      "s3:PutObject",

      "s3:GetObject",
      "s3:DeleteObject",

      #     "s3:CreateMultipartUpload",
      "s3:ListMultipartUploadParts",

      "s3:AbortMultipartUpload",
    ]

    principals {
      type        = "AWS"
      identifiers = ["${compact(var.principals)}"]
    }

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}/*"]
  }
}

data "aws_iam_policy_document" "bucket-full-access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}/*"]
  }
}

resource "aws_iam_policy" "bucket-full-access" {
  name   = "s3-${var.bucket_name}-full-access"
  policy = "${data.aws_iam_policy_document.bucket-full-access.json}"
}

data "aws_iam_policy_document" "bucket-full-access-with-mfa" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.remote-state.id}/*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "bucket-full-access-with-mfa" {
  name   = "s3-${var.bucket_name}-full-access-with-mfa"
  policy = "${data.aws_iam_policy_document.bucket-full-access-with-mfa.json}"
}

output "bucket_arn" {
  value       = "${aws_s3_bucket.remote-state.arn}"
  description = "`arn` exported from `aws_s3_bucket`"
}

output "bucket_id" {
  value       = "${aws_s3_bucket.remote-state.id}"
  description = "`id` exported from `aws_s3_bucket`"
}

output "region" {
  value       = "${aws_s3_bucket.remote-state.region}"
  description = "`region` exported from `aws_s3_bucket`"
}

output "url" {
  value       = "https://s3-${aws_s3_bucket.remote-state.region}.amazonaws.com/${aws_s3_bucket.remote-state.id}"
  description = "Derived URL to the S3 bucket"
}

output "principals" {
  value       = "${var.principals}"
  description = "Export `principals` variable (list of IAM user/role ARNs with access to the bucket)"
}

output "bucket-full-access-policy-arn" {
  value       = "${aws_iam_policy.bucket-full-access.arn}"
  description = "ARN of IAM policy that grants access to the bucket (without requiring MFA)"
}

output "bucket-full-access-with-mfa-policy-arn" {
  value       = "${aws_iam_policy.bucket-full-access-with-mfa.arn}"
  description = "ARN of IAM policy that grants access to the bucket (with MFA required)"
}
