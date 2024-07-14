# Amazon EC2 Snippets

## Enforce IMDSv2

```shell
aws ec2 modify-instance-metadata-options \
    --instance-id <--INSTANCE-ID--> \
    --http-tokens required \
    --http-endpoint enabled
```
