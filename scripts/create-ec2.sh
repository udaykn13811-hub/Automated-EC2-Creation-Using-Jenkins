
#!/bin/bash

set -euo pipefail

echo "======================================"
echo "     AWS EC2 INSTANCE CREATION"
echo "======================================"

# AWS Configuration
AWS_REGION="${AWS_REGION:-ap-south-2}"

# Validate required environment variables
: "${AMI_ID:?AMI_ID is required}"
: "${INSTANCE_TYPE:?INSTANCE_TYPE is required}"
: "${INSTANCE_NAME:?INSTANCE_NAME is required}"
: "${SUBNET_ID:?SUBNET_ID is required}"
: "${SECURITY_GROUP_ID:?SECURITY_GROUP_ID is required}"
: "${KEY_NAME:?KEY_NAME is required}"
: "${VOLUME_SIZE:?VOLUME_SIZE is required}"

echo "AWS Region: $AWS_REGION"
echo "AMI ID: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Instance Name: $INSTANCE_NAME"

# Verify AWS authentication
echo "Checking AWS authentication..."

aws sts get-caller-identity \
    --region "$AWS_REGION"

# Validate AMI
echo "Checking AMI..."

aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --region "$AWS_REGION" \
    --query 'Images[0].ImageId' \
    --output text

# Create EC2 instance
echo "Launching EC2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --block-device-mappings \
    "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
    --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=ManagedBy,Value=Jenkins}]" \
    --count 1 \
    --region "$AWS_REGION" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "======================================"
echo "EC2 INSTANCE CREATED SUCCESSFULLY"
echo "Instance ID: $INSTANCE_ID"
echo "======================================"

# Wait for instance
echo "Waiting for EC2 instance..."

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION"

# Retrieve EC2 details
echo "Fetching EC2 details..."

aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].{
        InstanceID:InstanceId,
        State:State.Name,
        PublicIP:PublicIpAddress,
        PrivateIP:PrivateIpAddress
    }' \
    --output table

echo "EC2 provisioning completed!"
