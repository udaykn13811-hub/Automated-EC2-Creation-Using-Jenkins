
pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['Development', 'Testing', 'Production'],
            description: 'Select deployment environment'
        )

        string(
            name: 'INSTANCE_NAME',
            defaultValue: 'aa-automated-ec2',
            description: 'EC2 instance name'
        )

        choice(
            name: 'INSTANCE_TYPE',
            choices: ['t3.micro', 't3.small', 't3.medium'],
            description: 'Select EC2 instance type'
        )

        string(
            name: 'SUBNET_ID',
            defaultValue: 'subnet-REPLACE_WITH_ACTUAL_ID',
            description: 'Actual subnet ID in ap-south-2'
        )

        string(
            name: 'SECURITY_GROUP_ID',
            defaultValue: 'sg-REPLACE_WITH_ACTUAL_ID',
            description: 'Actual security group ID'
        )

        string(
            name: 'KEY_NAME',
            defaultValue: 'aa-ec2-key',
            description: 'Existing EC2 key pair name'
        )

        string(
            name: 'VOLUME_SIZE',
            defaultValue: '8',
            description: 'Root EBS volume size in GB'
        )
    }

    environment {
        AWS_REGION = 'ap-south-2'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Starting Automated EC2 Provisioning Project'
                checkout scm
            }
        }

        stage('Validate Parameters') {
            steps {
                script {
                    if (!params.INSTANCE_NAME.matches(
                        '[a-zA-Z0-9._-]{1,50}'
                    )) {
                        error('Invalid EC2 instance name')
                    }

                    if (!params.SUBNET_ID.matches('subnet-[a-fA-F0-9]+')) {
                        error('Enter a valid subnet ID')
                    }

                    if (!params.SECURITY_GROUP_ID.matches('sg-[a-fA-F0-9]+')) {
                        error('Enter a valid security group ID')
                    }

                    if (!params.KEY_NAME?.trim()) {
                        error('EC2 key pair name is required')
                    }

                    if (!(params.VOLUME_SIZE ==~ /[0-9]+/)) {
                        error('Volume size must be numeric')
                    }

                    int volumeSize = params.VOLUME_SIZE.toInteger()

                    if (volumeSize < 8 || volumeSize > 100) {
                        error('Volume size must be between 8 and 100 GB')
                    }

                    if (params.ENVIRONMENT == 'Production') {
                        error('Production provisioning is disabled until an approval workflow is configured')
                    }
                }
            }
        }

        stage('AWS Authentication') {
            steps {
                sh '''
                    set -e

                    echo "Checking AWS CLI..."
                    aws --version

                    echo "Checking AWS IAM identity..."

                    aws sts get-caller-identity \
                      --region "$AWS_REGION"
                '''
            }
        }

        stage('Get Latest Amazon Linux AMI') {
            steps {
                script {
                    env.AMI_ID = sh(
                        script: '''
                            set -e

                            aws ssm get-parameter \
                              --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
                              --region "$AWS_REGION" \
                              --query 'Parameter.Value' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!env.AMI_ID.matches('ami-[a-fA-F0-9]+')) {
                        error("Invalid AMI returned by SSM: ${env.AMI_ID}")
                    }

                    echo "Retrieved Amazon Linux 2023 AMI: ${env.AMI_ID}"
                }
            }
        }

        stage('Validate AWS Resources') {
            steps {
                sh '''
                    set -e

                    echo "===================================="
                    echo "Validating AMI..."
                    echo "===================================="

                    aws ec2 describe-images \
                      --image-ids "$AMI_ID" \
                      --region "$AWS_REGION" \
                      --query 'Images[0].State' \
                      --output text

                    echo "===================================="
                    echo "Validating subnet..."
                    echo "===================================="

                    SUBNET_VPC=$(aws ec2 describe-subnets \
                      --subnet-ids "$SUBNET_ID" \
                      --region "$AWS_REGION" \
                      --query 'Subnets[0].VpcId' \
                      --output text)

                    if [ "$SUBNET_VPC" = "None" ] || [ -z "$SUBNET_VPC" ]; then
                        echo "Subnet validation failed"
                        exit 1
                    fi

                    echo "Subnet VPC: $SUBNET_VPC"

                    echo "===================================="
                    echo "Validating security group..."
                    echo "===================================="

                    SG_VPC=$(aws ec2 describe-security-groups \
                      --group-ids "$SECURITY_GROUP_ID" \
                      --region "$AWS_REGION" \
                      --query 'SecurityGroups[0].VpcId' \
                      --output text)

                    if [ "$SG_VPC" = "None" ] || [ -z "$SG_VPC" ]; then
                        echo "Security group validation failed"
                        exit 1
                    fi

                    echo "Security Group VPC: $SG_VPC"

                    if [ "$SUBNET_VPC" != "$SG_VPC" ]; then
                        echo "ERROR: Subnet and security group belong to different VPCs"
                        exit 1
                    fi

                    echo "Subnet and security group VPC validation successful"

                    echo "===================================="
                    echo "Validating EC2 key pair..."
                    echo "===================================="

                    aws ec2 describe-key-pairs \
                      --key-names "$KEY_NAME" \
                      --region "$AWS_REGION"

                    echo "All AWS resources validated successfully"
                '''
            }
        }

        stage('Create EC2 Instance') {
            steps {
                script {
                    env.INSTANCE_ID = sh(
                        script: '''
                            set -e

                            echo "===================================="
                            echo "Creating EC2 Instance..."
                            echo "===================================="

                            aws ec2 run-instances \
                              --image-id "$AMI_ID" \
                              --instance-type "$INSTANCE_TYPE" \
                              --key-name "$KEY_NAME" \
                              --subnet-id "$SUBNET_ID" \
                              --security-group-ids "$SECURITY_GROUP_ID" \
                              --block-device-mappings \
                              "[{\\"DeviceName\\":\\"/dev/xvda\\",\\"Ebs\\":{\\"VolumeSize\\":$VOLUME_SIZE,\\"VolumeType\\":\\"gp3\\",\\"DeleteOnTermination\\":true}}]" \
                              --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
                              --tag-specifications \
                              "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=ManagedBy,Value=Jenkins}]" \
                              --count 1 \
                              --region "$AWS_REGION" \
                              --query 'Instances[0].InstanceId' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!env.INSTANCE_ID.matches('i-[a-fA-F0-9]+')) {
                        error("EC2 creation returned an invalid instance ID: ${env.INSTANCE_ID}")
                    }

                    echo "EC2 Instance Created: ${env.INSTANCE_ID}"
                }
            }
        }

        stage('Wait For EC2') {
            steps {
                sh '''
                    set -e

                    echo "Waiting for EC2 instance to become running..."

                    aws ec2 wait instance-running \
                      --instance-ids "$INSTANCE_ID" \
                      --region "$AWS_REGION"

                    echo "EC2 instance is running successfully"
                '''
            }
        }

        stage('Get EC2 Details') {
            steps {
                sh '''
                    set -e

                    echo "===================================="
                    echo "Fetching EC2 Instance Details"
                    echo "===================================="

                    aws ec2 describe-instances \
                      --instance-ids "$INSTANCE_ID" \
                      --region "$AWS_REGION" \
                      --query 'Reservations[0].Instances[0].{
                        InstanceID:InstanceId,
                        InstanceType:InstanceType,
                        State:State.Name,
                        PrivateIP:PrivateIpAddress,
                        PublicIP:PublicIpAddress,
                        AvailabilityZone:Placement.AvailabilityZone,
                        AMI:ImageId
                      }' \
                      --output table
                '''
            }
        }
    }

    post {
        success {
            echo """
            ========================================
                EC2 CREATION SUCCESSFUL
            ========================================
            Instance ID: ${env.INSTANCE_ID}
            Environment: ${params.ENVIRONMENT}
            Instance Type: ${params.INSTANCE_TYPE}
            Region: ${env.AWS_REGION}
            ========================================
            """
        }

        failure {
            echo 'EC2 provisioning failed. Check Jenkins console output.'
        }

        always {
            echo 'EC2 provisioning pipeline execution finished.'
        }
    }
}
