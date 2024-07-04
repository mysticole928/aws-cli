# AWS-CLIv2 Example to Get Account Number

This assumes permissions are in place that allow access to this information.

```shell
aws sts get-caller-identity --query Account --output text
```
