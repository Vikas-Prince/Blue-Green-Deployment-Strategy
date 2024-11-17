pipeline{
    agent{
        label "slave"
    }

    tools{
        maven "maven3"
    }

    parameters{
        choice(name: 'DEPLOY_ENV', choices:["blue", "green"])
        choice(name: 'DOCKER_TAG', choices:["blue", "green"])
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue:false)
    }

    environment{
        DOCKER_IMAGE = "vikasprince/javabankapp"
        TAG = "${params.DOCKER_TAG}"
        SONAR_HOME = "sonar-scanner"
    }

    stages{
        
        stage("Cleanup Workspace"){
            steps{
                cleanWs();
            }
        }

        stage("Verifying Test Cases"){
            steps{
                sh "mvn test -DskipTests=true"
            }
        }

        stage("Trivy File System Scan"){
            steps{
                sh "trivy fs --format json -o fs-report.json ."
            }
        }

        stage("Sonar Code Quality Check"){
            steps{
                withSonarQubeEnv('sonar') {
                    sh "$SONAR_HOME/bin/sonar-scanner -Dsonar.projectKey=javaApp -Dsonar.projectName=javaApp -Dsonar.java.binaries=target"
                }
            }
        }

        stage("Sonar Quality Gate"){
            steps{
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-cred'

                }
            }
        }

        stage("Build Artifacts"){
            steps{
                sh "mvn clean package -DskipTests=true"
            }
        }

        stage("Build Docker Image"){
            steps{
                withDockerRegistry(credentialsId: 'docker-cred', url: "https://index.docker.io/v1/") {
                    sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                }
            }
        }

        stage("Docker Image Scan using Trivy"){
            steps{
                sh "trivy image --format json -o image-report.json ."
            }
        }

        stage("Push to Docker hub"){
            steps{
                withDockerRegistry(credentialsId: 'docker-cred', url:"https://index.docker.io/v1/") {
                    sh "docker push ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }

    }

    post{
        always{
            emailext(
                subject: "Build Result: ${currentBuild.currentResult}",
                body: """
                    Hi Team,

                    Please find attached the Trivy security scan results for this build.

                    Build Status: ${currentBuild.currentResult}
                    Build URL: ${env.BUILD_URL}

                    Thanks,
                    Jenkins
                """,
                to: "mppschool798@gmail.com",
                attachFiles: "image-report.json" // Attach the Trivy report
            )
        }
    }
}