# A simple walkthough using the AWS Key Management Service

This tutorial assumes:

* A KMS Customer Managed Key (CMK) already exists
* The user or IAM Role has access to KMS
* The user or IAM Role has access to the CMK

Some steps reference jQuery, a JavaScript library that does, amongst other things, parse JSON.  

**Note:** An IAM policy to use KMS is insufficient to use a CMK.  The CMK has a policy of its own to define who can use it as well as who can administer it.

## Generate an encryption key using a Customer Master Key

```bash
aws kms generate-data-key --key-id KEY-ID --key-spec AES_256 --region REGION
```
If the CMK has an alias, use this command:

```bash
aws kms generate-data-key --key-id alias/NAME --key-spec AES_256 --region REGION
```

## The output will look something this:

```json
{
    "Plaintext": "ebAXcyjPTJhQBv5GUCBasdfasdfasdfakPhPG1g0hf6Y4s=",
    "KeyId": "arn:aws:kms:us-west-2:000000000000:key/7h5ij15k-l357-425m-8978-n02opq68530",
    "CiphertextBlob": "AYIDAHgwdwm/Hnr0Uyr7fD0T4lM58uPQs7VsGeoyHvi7ozlGLAE0ot6dZ9LFXBSVt4RfrnQEAAAAfjB8BgkqhkiG9w0BBwagbzBtAgEAMGgGCSqGSIb3DQEHATAeB123456BZQMEAS4wEQQMKArNWUaVG8QN5viUAgEQgDvOx3AXakKYH9k8d3CoTcwxDBchKWF8euIbQwQhxpadKFhk7dSpZbJhHPexhNn4yMD9Qh0aAHUVckFq2w=="
}
```

Yes, I did edit the above to make the key, my account number, the plaintext, and the ciphertext wrong.

The `Plaintext` and `CiphertextBlob` are Base64 encoded.

## Optional: Create an Alias for the CMK

If you have permission to administer the key, here's the command to create an alias:

```bash
aws kms create-alias --target-key-id TARGET-KEY-ID --alias-name "alias/NAME" --region REGION
```

The REGION is always in lower-case.

## Save the keys as text files

Copy and paste the text from the JSON output to make two new files.  For this example, the I added the prefix `dek_` (Data Encryption Key) and the suffix `.base64`

```bash
echo "CIPHERTEXT" > dek_ciphertext.base64
```

```bash
echo "PLAINTEXT" > dek_plaintext.base64
```

If you save the output to a file, you can use jQuery to do this.

Using the filename: `data-key.json` these commands will parse the data for you.

```bash
cat data-key.json | jq -r '.CiphertextBlob' > dek_ciphertext.base64
```

```bash
cat data-key.json | jq -r '.Plaintext' > dek_plaintext.base64
```

**Note:** The `-r` option returns the raw data.  (It removes the quotation marks.)

## Decode the Base 64 version of the plaintext key

```bash
openssl base64 -d -in dek_plaintext.base64 -out dek_plaintext
```

## Use the plaintext AES256 key to encrypt a file.

For this example, my filename is `my_private_data.txt`

```bash
openssl enc -e -aes256 -kfile dek_plaintext -in my_private_data.txt -out my_private_data.encrypted
```

Once complete, the plaintext keys (both the original Base64 version and decoded one) as well as the plaintext file should be deleted.  

## Use the encrypted ciphertext to get another copy of the plaintext key

First, decode the Ciphertext from Base64

```bash
openssl base64 -d -in dek_ciphertext.base64 -out dek_ciphertext
```

```bash
aws kms decrypt --ciphertext-blob fileb://dek_ciphertext --region REGION
```

Alternatively, you could redirect this to a file.

```bash
aws kms decrypt --ciphertext-blob fileb://dek_ciphertext --region REGION > new_dek_key.json
```

Then, use jQuery to extract the data.

```bash
cat new_dek_key.json | jq -r '.Plaintext' > new_dek_plaintext.base64
```

The two steps can be combined.

```bash
aws kms decrypt --ciphertext-blob fileb://dek_ciphertext --region REGION | jq -r '.Plaintext' > new_dek_plaintext.base64
```
## Decode the newly returned plaintext

```bash
openssl base64 -d -in new_dek_plaintext.base64 -out new_dek_plaintext
```

## Use the newly decoded plaintext to decrypt the file

```bash
openssl enc -d -aes256 -kfile new_dek_plaintext -in my_private_data.encrypted -out my_private_data.decrypted
```


