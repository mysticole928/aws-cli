# AWS S3 Scripts and CLI Examples
_Created: 2026-01-02_

## S3 Bucket Info Scripts

- `s3-bucket-info.zsh`
- `s3-bucket-info.py`

These scripts display the configuration and metadata for an 
Amazon S3 bucket in `YAML` format.

For each S3 `get-bucket-*` API call, the script:

- Prints the configuration if it exists
- Prints "status: not configured" when the configuration is absent
- Prints an error block for unexpected failures

Note: The bucket creation date is retrieved from `s3api list-buckets`.
This is the authoritative source for S3 bucket creation time.

**Outputs Include:**

- Caller identity
- Bucket creation date
- Location, versioning, encryption
- Public access block, policy, logging
- Tags, lifecycle configuration
- ACL, ownership controls, CORS, and replication
