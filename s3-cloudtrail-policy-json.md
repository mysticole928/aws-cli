# S3 Bucket Policy for AWS CloudTrail Logging

The `Sid:` is a "statement id."   It is optional and is used to 
distinguish between different statements within a single policy. 

When AWS creates policy documents, they include random numbers in
each statement id to add entropy.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::<---s3-bucket-name--->"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::<---s3-bucket-name--->/AWSLogs/<---AWS-ACCOUNT-NUMBER--->/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
```
