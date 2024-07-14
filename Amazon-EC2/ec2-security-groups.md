# EC2 CLI Snippets

## Convenient Shell Variables

Assign public IP to PUBLIC_IP:

```shell
export IP_ADDRESS=$(curl --silent ifconfig.co)
```

## Get In-Bound Rules for a Security Group

```shell
aws ec2 describe-security-groups \
  --region <--AWS-REGION--> \
  --group-ids <--SECURITY-GROUP-ID--> \
  --query "SecurityGroups[*].{
      GroupId: GroupId,
      IngressRules: IpPermissions
    }" \
  --output yaml
```

## Authorize Specific IP for Port 22/SSH Access

```shell
aws ec2 authorize-security-group-ingress \
  --region <--AWS-REGION--> \
  --group-id <--SECURITY-GROUP-ID--> \
  --protocol tcp \
  --port 22 \
  --cidr ${PUBLIC_IP}/32
```

## Authorize Specific IP for Port 3389/Windows-RDP Access

```shell
aws ec2 authorize-security-group-ingress \
  --region <--AWS-REGION--> \
  --group-id <--SECURITY-GROUP-ID--> \
  --protocol tcp \
  --port 3389 \
  --cidr ${PUBLIC_IP}/32
```

## Disable Public Internet Access for Port 22/SSH

```shell
aws ec2 revoke-security-group-ingress \
  --region <--AWS-REGION--> \
  --group-id <--SECURITY-GROUP-ID--> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

## Disable Public Internet Access for Port 3389/Windows-RDP

```shell
aws ec2 revoke-security-group-ingress \
  --region <--AWS-REGION--> \
  --group-id <--SECURITY-GROUP-ID--> \
  --protocol tcp \
  --port 3389 \
  --cidr 0.0.0.0/0
```
