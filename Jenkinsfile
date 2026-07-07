pipeline {
    agent any

    environment {
        IMAGE_NAME = 'sumanthrakasi/ci-cd-demo-app'
        EC2_HOST = '100.48.113.130'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Test') {
            steps {
                dir('app') {
                    script {
                        docker.image('node:20-alpine').inside {
                            sh 'npm ci'
                            sh 'npm test'
                        }
                    }
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    dockerImage = docker.build("${IMAGE_NAME}:${env.IMAGE_TAG}", './app')
                }
            }
        }

        stage('Push Image') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        dockerImage.push(env.IMAGE_TAG)
                        dockerImage.push('latest')
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} 'bash -s' -- \
                          "${IMAGE_NAME}:${env.IMAGE_TAG}" < deploy/rolling-deploy.sh
                    """
                }
            }
        }
    }

    post {
        always {
            // Clean up old, unused images so the Jenkins host's disk doesn't fill up.
            sh 'docker image prune -f --filter "until=24h" || true'
        }
    }
}
