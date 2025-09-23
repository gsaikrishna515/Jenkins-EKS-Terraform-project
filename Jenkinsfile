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
        // ... (Checkout, Plan, Apply, Configure Kubectl, Deploy Application stages are all correct and remain unchanged) ...

        stage('Checkout Infrastructure Code') {
            steps {
                echo 'Checking out the EKS Terraform project...'
                checkout scm
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' || params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        echo "Initializing Terraform..."
                        sh 'terraform init -input=false'
                        if (params.ACTION == 'destroy') {
                            echo "Generating destroy plan..."
                            sh 'terraform plan -destroy -out=tfplan'
                        } else {
                            echo "Generating infrastructure plan..."
                            sh 'terraform plan -out=tfplan'
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    input 'Proceed with Terraform Apply?'
                    echo "Applying Terraform plan..."
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Configure Kubectl') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    echo 'Configuring kubectl to connect to the cluster...'
                    sh '''
                        CLUSTER_NAME=$(terraform output -raw cluster_name)
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                    '''
                    sh 'kubectl get nodes'
                }
            }
        }

        stage('Deploy Kubernetes Application') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        dir('app-repo') {
                            echo "Cloning application repository from ${params.APP_GIT_REPO_URL}"
                            git url: params.APP_GIT_REPO_URL,
                                branch: 'main',
                                credentialsId: 'git-https-token'
                            echo "Applying Kubernetes manifests from the repository..."
                            sh "kubectl apply -f kubernetes/"
                            sh 'sleep 20'
                            sh 'kubectl rollout restart deployment product-service'
                        }
                        echo "Deployment initiated. Waiting for resources to become ready..."
                        sh 'sleep 30'
                        echo "--- Services ---"
                        sh 'kubectl get svc --all-namespaces'
                        echo "--- PersistentVolumeClaims ---"
                        sh 'kubectl get pvc --all-namespaces'
                        echo "--- Pods ---"
                        sh 'kubectl get pods --all-namespaces'
                    }
                }
            }
        }
        
        // --- CORRECTED DESTROY STAGE ---
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        echo "--- STEP 1: Cleaning up Kubernetes application resources ---"
                        
                        // Get the cluster name from Terraform state into a Groovy variable
                        def clusterName = sh(script: 'terraform output -raw cluster_name', returnStdout: true).trim()
                        
                        // Use a Groovy 'if' condition to check if the cluster exists
                        if (!clusterName.isEmpty()) {
                            echo "Cluster '${clusterName}' found. Proceeding with Kubernetes resource cleanup."
                            
                            // Step 1.1: Configure kubectl using a shell step
                            sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${clusterName}"
                            
                            // Step 1.2: Use the 'dir' step to create a temporary directory
                            dir('app-repo-cleanup') {
                                echo "Cloning application repository to delete manifests..."
                                // Use the 'git' step inside 'dir'
                                git url: params.APP_GIT_REPO_URL, 
                                    branch: 'main', 
                                    credentialsId: 'git-https-token'
                                
                                echo "Deleting Kubernetes application (Services, Deployments, etc.)..."
                                // Use a shell step to run kubectl
                                sh "kubectl delete -f kubernetes/ --ignore-not-found=true"
                            }
                            
                            echo "Waiting 60 seconds for AWS Load Balancer and ENIs to be deleted..."
                            // Use the Groovy 'sleep' step
                            sleep 60
                        } else {
                            echo "Could not determine cluster name from Terraform state. Assuming no Kubernetes resources to clean."
                        }
                        
                        echo "--- STEP 2: Destroying Terraform infrastructure ---"

                        input 'DANGER: Proceed with Terraform Destroy? This cannot be undone.'
                        
                        echo "Destroying infrastructure..."
                        sh 'terraform apply -auto-approve tfplan'
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
