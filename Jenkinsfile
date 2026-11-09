
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
            name: 'AMI_ID',
            defaultValue: 'ami-xxxxxxxxxxxxxxxxx',
            description: 'Amazon Linux 2023 AMI ID'
        )

        string(
            name: 'SUBNET_ID',
            defaultValue: 'subnet-xxxxxxxx',
            description: 'Target subnet ID'
        )

        string(
            name: 'SECURITY_GROUP_ID',
            defaultValue: 'sg-xxxxxxxx',
            description: 'Security group ID'
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
                echo 'Starting EC2 provisioning project'
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

                    if (!(params.VOLUME_SIZE ==~ /[0-9]+/)) {
                        error('Volume size must be numeric')
                    }

                    if (params.VOLUME_SIZE.toInteger() < 8 ||
                        params.VOLUME_SIZE.toInteger() > 100) {
                        error('Volume size must be between 8 and 100 GB')
                    }

                    if (!params.AMI_ID.startsWith('ami-') ||
                        !params.SUBNET_ID.startsWith('subnet-') ||
                        !params.SECURITY_GROUP_ID.startsWith('sg-')) {
                        error('Invalid AWS resource ID')
                    }

                    if (params.ENVIRONMENT == 'Production') {
                        error('Production provisioning requires a separate approval workflow')
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

        stage('Validate AWS Resources') {
            steps {
                sh '''
                    set -e

                    echo "Validating AMI..."

                    aws ec2 describe-images \
                      --image-ids "$AMI_ID" \
                      --region "$AWS_REGION" \
                      --query 'Images[0].ImageId' \
                      --output text

                    echo "Validating subnet..."

                    aws ec2 describe-subnets \
                      --subnet-ids "$SUBNET_ID" \
                      --region "$AWS_REGION"

                    echo "Validating security group..."

                    aws ec2 describe-security-groups \
                      --group-ids "$SECURITY_GROUP_ID" \
                      --region "$AWS_REGION"
                '''
            }
        }

        stage('Create EC2 Instance') {
            steps {
                script {

                    env.INSTANCE_ID = sh(
                        script: '''
                            set -e

                            aws ec2 run-instances \
                              --image-id "$AMI_ID" \
                              --instance-type "$INSTANCE_TYPE" \
                              --key-name "$KEY_NAME" \
                              --subnet-id "$SUBNET_ID" \
                              --security-group-ids "$SECURITY_GROUP_ID" \
                              --block-device-mappings \
                              "[{\\"DeviceName\\":\\"/dev/xvda\\",\\"Ebs\\":{\\"VolumeSize\\":$VOLUME_SIZE,\\"VolumeType\\":\\"gp3\\",\\"DeleteOnTermination\\":true}}]" \
                              --tag-specifications \
                              "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=ManagedBy,Value=Jenkins}]" \
                              --count 1 \
                              --region "$AWS_REGION" \
                              --query 'Instances[0].InstanceId' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

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

                    echo "EC2 instance is running"
                '''
            }
        }

        stage('Get EC2 Details') {
            steps {
                sh '''
                    echo "Fetching EC2 instance details..."

                    aws ec2 describe-instances \
                      --instance-ids "$INSTANCE_ID" \
                      --region "$AWS_REGION" \
                      --query 'Reservations[0].Instances[0].{
                        InstanceID:InstanceId,
                        InstanceType:InstanceType,
                        State:State.Name,
                        PrivateIP:PrivateIpAddress,
                        PublicIP:PublicIpAddress
                      }' \
                      --output table
                '''
            }
        }
    }

    post {
        success {
            echo """
            ====================================
                 EC2 CREATION SUCCESSFUL
            ====================================
            Instance ID: ${env.INSTANCE_ID}
            Environment: ${params.ENVIRONMENT}
            Instance Type: ${params.INSTANCE_TYPE}
            ====================================
            """
        }

        failure {
            echo 'EC2 provisioning failed. Check Jenkins console output.'
        }

        always {
            echo 'EC2 provisioning pipeline execution completed.'
        }
    }
}
