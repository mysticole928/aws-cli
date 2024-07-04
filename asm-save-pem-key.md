# Manage PEM file with Amazon Secrets Manager

Saving PEM files for SSH via the web console can be tricky.  
Uploading via the browser can add line breaks or change PEM
files in ways that break it.

## Store the PEM in ASM

Use the AWS-CLI to upload the PEM file directly.

```shell
aws secretsmanager create-secret \
  --name <-ASM_Secret_Name-> \
  --region <-aws_region-> \
  --secret-string file://pem_filename_to_store.pem
```

## Retrieve the PEM from ASM

This CLI example requires the program `jq` to parse the JSON output.

```shell
aws secretsmanager get-secret-value \
  --secret-id <-ASM_Secret_Name-> \ 
  --region <-aws_region-> | jq '.SecretString' \
  --raw-output > desired_output_filename.pem
```

