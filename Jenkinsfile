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
        stage('Checkout Infrastructure Code') {
            steps {
                echo 'Checking out the EKS Terraform project...'
                checkout scm
            }
        }

        stage('Terraform Plan') {
            // This stage runs for 'plan', 'apply', and 'destroy' actions.
            when {
                // Fixed syntax: Added '==' to the expression
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' || params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        echo "Initializing Terraform..."
                        sh 'terraform init -input=false'
                        // Generate a different plan file based on the action
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
            // This stage ONLY runs when the action is 'apply'.
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    // Safety Gate: Manual approval before applying
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
                            // NOTE: Make sure 'git-https-token' is the correct Credentials ID in Jenkins for your GitHub PAT.
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

        // --- UPDATED DESTROY STAGE ---
        stage('Terraform Destroy') {
            // This stage ONLY runs when the action is 'destroy'.
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    script {
                        echo "--- STEP 1: Cleaning up Kubernetes application resources ---"
                        
                        echo "Configuring kubectl for cleanup..."
                        sh '''
                            # Get the cluster name from the existing Terraform state
                            CLUSTER_NAME=$(terraform output -raw cluster_name)
                            
                            # Check if the cluster name exists. If not, maybe it was never created.
                            if [ -z "$CLUSTER_NAME" ]; then
                                echo "Could not determine cluster name from Terraform state. Assuming no Kubernetes resources to clean."
                            else
                                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                                
                                # Clone the application repo to get the manifests for deletion
                                dir('app-repo-cleanup') {
                                    echo "Cloning application repository to delete manifests..."
                                    git url: params.APP_GIT_REPO_URL, 
                                        branch: 'main', 
                                        credentialsId: 'git-https-token'
                                    
                                    echo "Deleting Kubernetes application (Services, Deployments, etc.)..."
                                    # The '--ignore-not-found=true' flag prevents errors if the app was never fully deployed.
                                    sh "kubectl delete -f kubernetes/ --ignore-not-found=true"
                                }
                                
                                echo "Waiting 60 seconds for AWS Load Balancer and ENIs to be deleted..."
                                # This pause is CRITICAL to give the AWS controller time to clean up network resources.
                                sleep 60
                            fi
                        '''
                        
                        echo "--- STEP 2: Destroying Terraform infrastructure ---"

                        // CRITICAL Safety Gate: Double confirmation for destruction
                        input 'DANGER: Proceed with Terraform Destroy? This cannot be undone.'
                        
                        echo "Destroying infrastructure..."
                        // We apply the 'destroy' plan that was generated in the 'Terraform Plan' stage
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline finished.'
            // This cleans the workspace of plan files and checked-out code for a clean run next time.
            cleanWs()
        }
    }
}
