pipeline {
    agent any

    // Define user-selectable parameters for the build
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
                // Wrap all actions in the credentials block to stay DRY
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    // Use a script block to allow for if/else logic
                    script {
                        // --- ACTION: PLAN ---
                        if (params.ACTION == 'plan') {
                            echo "Running Terraform Plan..."
                            sh 'terraform init -input=false'
                            sh 'terraform plan -out=tfplan'
                        }
                        
                        // --- ACTION: APPLY ---
                        else if (params.ACTION == 'apply') {
                            echo "Running Terraform Apply..."
                            sh 'terraform init -input=false'
                            sh 'terraform plan -out=tfplan'
                            
                            // Safety Gate: Manual approval before applying
                            input 'Proceed with Terraform Apply?'
                            
                            sh 'terraform apply -auto-approve tfplan'
                            
                            // Post-Apply Steps: Configure kubectl and deploy app
                            echo 'Configuring kubectl...'
                            sh '''
                                CLUSTER_NAME=$(terraform output -raw cluster_name)
                                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                            '''
                            sh 'kubectl get nodes'
                            
                            echo 'Deploying Nginx application...'
                            sh 'kubectl apply -f nginx-app/nginx.yaml'
                            sh 'sleep 30' // Give the Load Balancer time to provision
                            sh 'kubectl get svc nginx-service'
                        }
                        
                        // --- ACTION: DESTROY ---
                        else if (params.ACTION == 'destroy') {
                            echo "Running Terraform Destroy..."
                            sh 'terraform init -input=false'
                            
                            // It's good practice to show a destroy plan first
                            sh 'terraform plan -destroy -out=tfdestroy'
                            
                            // CRITICAL Safety Gate: Double confirmation for destruction
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
            // Clean up the workspace to remove plan files and state files
            // This ensures a fresh run every time
            cleanWs()
        }
    }
}

