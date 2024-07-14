# Amazon CloudTrail

## Search CloudTrail for an EC2 Instance using Local Credentials

### The Scenario

There's an EC2 instance in an AWS account that is using account credentials instead of having an IAM Role attached to it.

The AWS CLI reports details about how EC2 instances are configured but cannot see inside the instances.

For management events, the top-level CloudTrail look-up options are limited to these fields:

- AWS access key
- Event ID
- Event name
- Event source
- Read only
- Resource name
- Resource type
- User name

IP address is **NOT** in this list.

However, digging deeper into each CloudTrail event the IP address **IS** stored in `CloudTrailEvent`.

It requires some effort to get to it because `CloudTrailEvent` is _serialized JSON_ data.

Here's a redacted example from `cloudtrail lookup-event`:

```json
{
  "EventId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "EventName": "LookupEvents",
  "ReadOnly": "true",
  "AccessKeyId": "AKIAxxxxxxxxxxxxxxx",
  "EventTime": "2024-07-13T14:09:43-07:00",
  "EventSource": "cloudtrail.amazonaws.com",
  "Username": "user_anonymized",
  "Resources": [],
  "CloudTrailEvent": "{\"eventVersion\":\"1.10\",\"userIdentity\":{\"type\":\"IAMUser\",\"principalId\":\"AIDAxxxxxxxxxxxxxxx\",\"arn\":\"arn:aws:iam::123456789012:user/user_anonymized\",\"accountId\":\"123456789012\",\"accessKeyId\":\"AKIAxxxxxxxxxxxxxxx\",\"userName\":\"user_anonymized\"},\"eventTime\":\"2024-07-13T21:09:43Z\",\"eventSource\":\"cloudtrail.amazonaws.com\",\"eventName\":\"LookupEvents\",\"awsRegion\":\"us-west-2\",\"sourceIPAddress\":\"0.0.0.0\",\"userAgent\":\"aws-cli/2.11.9 Python/3.11.2 Darwin/23.5.0 source/x86_64 prompt/off command/cloudtrail.lookup-events\",\"requestParameters\":{\"maxResults\":100},\"responseElements\":null,\"requestID\":\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\",\"eventID\":\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\",\"readOnly\":true,\"eventType\":\"AwsApiCall\",\"managementEvent\":true,\"recipientAccountId\":\"123456789012\",\"eventCategory\":\"Management\",\"tlsDetails\":{\"tlsVersion\":\"TLSv1.3\",\"cipherSuite\":\"TLS_AES_128_GCM_SHA256\",\"clientProvidedHostHeader\":\"cloudtrail.us-west-2.amazonaws.com\"}}"
}
```

### Serialzed JSON

_Serialized JSON_ is commonly used for nested JSON.

When a JSON object is serialized, it is converted/flattened into a single string.

This makes it easier to embed it into other JSON for transport.

Since normal JSON object keys and strings are enclosed in double (`"`) quotes, the quotes in serialized JSON must be escaped with a backslash (`\`) character.

Serialized JSON simplifies some aspects of data storage and transmission but it requires additional processing to parse and manipulate.

\<sarcasm\>No kidding.\</sarcasm\>

## Find an IAM User in a CloudTrail Trail

The options for `cloudtrail lookup-events` include `--start-time` and `--end-time`.

They both require UTC time formatted as an ISO 8601 string.
`YYYY-MM-DDTHH:MM:SSZ`

Using a date range is helpful when narrowing searchs.

The `date` command in unix/linux generates UTC ISO 8601 formatted dates. However, when getting past dates, the BSD Unix (MacOS) version uses different options than the GNU version. (Of **_course\*_** they are different.)

### The `date` Command

#### Get the current date and time and assign it to a shell variable

BSD/MacOS and GNU/Linux

```shell
export CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

##### Command output

```shell
echo $CURRENT_DATE

2024-07-13T22:01:48Z
```

#### Get the date and time 7 days prior to today

BSD/MacOS `date` 7 days ago

```shell
export PREVIOUS_WEEK=$(date -u -v -"7"d +"%Y-%m-%dT%H:%M:%SZ")
```

GNU/Linux `date` 7 days ago

```shell
export PREVIOUS_WEEK=$(date -u -d "-7 days" +"%Y-%m-%dT%H:%M:%SZ")
```

##### Command output

```shell
echo $PREVIOUS_WEEK

2024-07-06T22:05:25Z
```

### A First Attempt at Parsing CloudTrail Searching for an IP Address

This works. (More or less.)

It uses these shell variables:

- $AWS_REGION
- $PREVIOUS_WEEK
- $IP_ADDRESS

I've since improved on this example. However, I'm proud that I figured it out and got it to work.

(Sometimes, I just can't let go of a problem until I get it to work and this was one of those times. It cost me some sleep and I probably should have let it go. Still, it works a and a win is a win.)

```shell
aws cloudtrail lookup-events \
    --region $AWS_REGION \
    --start-time $PREVIOUS_WEEK \
    --query 'Events[*].CloudTrailEvent' \
    --output json | jq --arg ipaddr $IP_ADDRESS '
            [ .[] |= fromjson
            | .[]
            | select(.sourceIPAddress == $ipaddr and
                    .userIdentity.type == "IAMUser" )
            |   {
                Username: .userIdentity.userName,
                User_Type: .userIdentity.type,
                SourceIPAddress: .sourceIPAddress,
                UserAgent: .userAgent,
                AccessKeyId: .userIdentity.accessKeyId,
                PrincipalID: .userIdentity.principalId
                }
                | first '
```

Here is a sample of the output:

```json
{
  "Username": "anonymized_user",
  "User_Type": "IAMUser",
  "SourceIPAddress": "9.28.19.68",
  "UserAgent": "[aws-cli/2.x.x md/awscrt#x.xx.xx ua/x.x os/linux#x.x.x-xxxx-aws md/arch#x86_64 lang/python#x.x.x md/pyimpl#CPython cfg/retry-mode#standard md/installer#exe md/distrib#linux.distro md/prompt#off md/command#s3.command]",
  "AccessKeyId": "AKIAxxxxxxxxxxxxxxx",
  "PrincipalID": "AIDAxxxxxxxxxxxxxxx"
}
```

This answers the question about an IAM User working on an EC2 instance. Though, it took a lot more effort than I anticipated. As I studed the problem more, I figured out how to make the command more readable and, maybe, more efficient.

Some lessons learned:

### Test for `.userIdentity.type`

There are other AWS services that interact with EC2. Adding a test for `.userIdenty.type == "IAMUser"` filters them out.

### The `--query` statement is unnecessary

I thought that, because the IP address was inside `.CloudTrailEvent`, I had to query it. Wrong.

If anything, this probabably made the command work harder than it needed to. I got a couple of errors related to throttling while testing. This setting probaby is related to it.

### The `jq` command is too complicated

`jq` can process serialized JSON, but I sent it to Cleveland first. (Nothing wrong with Cleveland. It rocks!)

### Abusing JSON to get a single response

To use the `jq` filter `first`, I put the output in an array. A better way is to put the filter `first` in front of the `jq` processing.

## A better way

This example is cleaner and slightly more efficient. It omits the `--query` statement, processes the serialized JSON in place, and moves the `first` filter to the front of `jq`.

In `jq` the `|=` operator updates a value in place. `(.CloudTrailEvent |= fromjson)` transforms the serialzed JSON to normal/parsed JSON and updates `.CloudTrailEvents`.

```shell
 aws cloudtrail lookup-events \
    --region $AWS_REGION \
    --start-time $PREVIOUS_WEEK \
    --output json | \
        jq -r --arg ip_addr $IP_ADDRESS 'first( .Events[] |
            (.CloudTrailEvent |= fromjson) | select(
                .CloudTrailEvent.sourceIPAddress == $ip_addr and
                .CloudTrailEvent.userIdentity.type == "IAMUser") |
                {
                    Username: .Username,
                    User_Type: .CloudTrailEvent.userIdentity.type,
                    SourceIPAddress: .CloudTrailEvent.sourceIPAddress,
                    AccessKeyId: .CloudTrailEvent.userIdentity.accessKeyId,
                    UserAgent: .CloudTrailEvent.userAgent
                }
            )'
```

> [!tip]
> Use `ifconfig.co` to assign your computer's public IP to a shell variable.
>
> ```shell
> export PUBLIC_IP=$(curl --silent ifconfig.co)
> ```
