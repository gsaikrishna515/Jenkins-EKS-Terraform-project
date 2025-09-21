pipeline {
    agent any

    // NEW SECTION: Define the tools required for this pipeline
    tools {
        // The name 'terraform-latest' MUST match the name you configured in Manage Jenkins -> Tools
        terraform 'terraform-latest' 
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Select the Terraform action to perform.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        TF_IN_AUTOMATION = 'true'
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out the EKS Terraform project...'
                checkout scm
            }
        }

        stage('Terraform Execution') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        if (params.ACTION == 'plan') {
                            echo "Running Terraform Plan..."
                            // Jenkins now knows where to find 'terraform'
                            sh 'terraform init -input=false'
                            sh 'terraform plan -out=tfplan'
                        }
                        
                        else if (params.ACTION == 'apply') {
                            echo "Running Terraform Apply..."
                            sh 'terraform init -input=false'
                            sh 'terraform plan -out=tfplan'
                            
                            // input 'Proceed with Terraform Apply?'
                            
                            sh 'terraform apply -auto-approve tfplan'
                            
                            echo 'Configuring kubectl...'
                            sh '''
                                CLUSTER_NAME=$(terraform output -raw cluster_name)
                                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                            '''
                            sh 'kubectl get nodes'
                            
                            echo 'Deploying Nginx application...'
                            sh 'kubectl apply -f nginx-app/nginx.yaml'
                            sh 'sleep 30'
                            sh 'kubectl get svc nginx-service'
                        }
                        
                        else if (params.ACTION == 'destroy') {
                            echo "Running Terraform Destroy..."
                            sh 'terraform init -input=false'
                            sh 'terraform plan -destroy -out=tfdestroy'
                            
                            input 'DANGER: Proceed with Terraform Destroy? This cannot be undone.'
                            
                            sh 'terraform destroy -auto-approve'
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline finished.'
            cleanWs()
        }
    }
}
