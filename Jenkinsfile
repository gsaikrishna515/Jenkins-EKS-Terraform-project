pipeline {
    agent any

    tools {
        terraform 'terraform-latest' 
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Select the Terraform action to perform.'
        )
        // --- NEW PARAMETER FOR YOUR APP REPO ---
        string(
            name: 'APP_GIT_REPO_URL',
            defaultValue: 'https://github.com/gsaikrishna515/python-node-microservices-project-with-K8S.git',
            description: 'The Git repository URL of the Kubernetes application to deploy.'
        )
    }

    environment {
        AWS_REGION = 'ap-south-1'
        TF_IN_AUTOMATION = 'true'
    }

    stages {
        // ... Checkout Code, Terraform Execution stages remain the same ...

        stage('Terraform Execution') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        if (params.ACTION == 'apply') {
                            // ... terraform init, plan, apply, and kubectl config steps are the same ...
                            sh 'terraform apply -auto-approve tfplan'
                            
                            echo 'Configuring kubectl...'
                            sh '''
                                CLUSTER_NAME=$(terraform output -raw cluster_name)
                                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                            '''
                            sh 'kubectl get nodes'
                        }
                        // ... destroy logic is the same ...
                    }
                }
            }
        }
        
        // --- NEW/MODIFIED DEPLOYMENT STAGE ---
        stage('Deploy Kubernetes Application') {
            // This stage only runs if the action was 'apply'
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    // Use a separate directory for the application code
                    dir('app-repo') {
                        echo "Cloning application repository from ${params.APP_GIT_REPO_URL}"
                        // Clone the application repository
                        git url: params.APP_GIT_REPO_URL

                        // Apply all manifest files from the 'manifests' directory (or adjust the path)
                        echo "Applying Kubernetes manifests from the repository..."
                        sh "kubectl apply -f kubernetes/"
                    }
                    
                    echo "Deployment initiated. Waiting for resources to become ready..."
                    sh 'sleep 30'
                    echo "--- Services ---"
                    sh 'kubectl get svc'
                    echo "--- PersistentVolumeClaims ---"
                    sh 'kubectl get pvc'
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
