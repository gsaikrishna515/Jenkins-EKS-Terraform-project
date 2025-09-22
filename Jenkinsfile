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
            // This stage ONLY runs when the action is 'apply'.
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
            // This stage ONLY runs when the action is 'apply'.
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir('app-repo') {
                        echo "Cloning application repository from ${params.APP_GIT_REPO_URL}"
                        //git url: params.APP_GIT_REPO_URL
                        git url: params.APP_GIT_REPO_URL, 
                        branch: 'main', 
                        credentialsId: 'git-https-token'

                        echo "Applying Kubernetes manifests from the repository..."
                        // Assuming manifests are in a 'manifests' folder. Adjust if needed.
                        sh "kubectl apply -f kubernetes/"
                    }
                    
                    echo "Deployment initiated. Waiting for resources to become ready..."
                    sh 'sleep 30'
                    echo "--- Services ---"
                    sh 'kubectl get svc --all-namespaces'
                    echo "--- PersistentVolumeClaims ---"
                    sh 'kubectl get pvc --all-namespaces'
                }
            }
        }
        
        stage('Terraform Destroy') {
            // This stage ONLY runs when the action is 'destroy'.
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials-for-eks')]) {
                    // CRITICAL Safety Gate: Double confirmation for destruction
                    input 'DANGER: Proceed with Terraform Destroy? This cannot be undone.'

                    echo "Destroying infrastructure..."
                    // We apply the 'destroy' plan that was generated in the 'plan' stage
                    sh 'terraform apply -auto-approve tfplan'
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
