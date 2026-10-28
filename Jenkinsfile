pipeline {
    agent any

    options {
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        AWS_REGION   = 'eu-west-1'
        PROJECT      = 'secure-cicd'
        APP_NAME     = 'weather-app'
        ECS_CLUSTER  = "${PROJECT}-cluster"
        ECS_SERVICE  = "${APP_NAME}"
        TASK_FAMILY  = "${APP_NAME}"
        LOG_GROUP    = "/ecs/${APP_NAME}"
        ALB_NAME     = "${PROJECT}-alb"
        SONAR_HOST   = 'http://localhost:9000'

        GITLEAKS_IMAGE = 'zricethezav/gitleaks:v8.30.0'
        SONAR_IMAGE    = 'sonarsource/sonar-scanner-cli:12.2.0.4256_8.1.0'
        SNYK_IMAGE     = 'snyk/snyk:python-3.12'
        SYFT_IMAGE     = 'anchore/syft:v1.54.1'
        TRIVY_IMAGE    = 'aquasec/trivy:0.75.0'
        ZAP_IMAGE      = 'ghcr.io/zaproxy/zaproxy:2.16.1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT     = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG     = "${env.BUILD_NUMBER}-${env.GIT_SHORT}"
                    env.ACCOUNT_ID    = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                    env.ECR_REGISTRY  = "${env.ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE_URI     = "${env.ECR_REGISTRY}/${env.APP_NAME}:${env.IMAGE_TAG}"
                    env.EXEC_ROLE_ARN = "arn:aws:iam::${env.ACCOUNT_ID}:role/${env.PROJECT}-ecs-task-execution"
                    env.TASK_ROLE_ARN = "arn:aws:iam::${env.ACCOUNT_ID}:role/${env.PROJECT}-ecs-task"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.GIT_SHORT}"
                }
                sh 'rm -rf reports && mkdir -p reports'
            }
        }

        stage('Secret Scan (Gitleaks)') {
            steps {
                sh '''
                    docker run --rm --user "$(id -u):$(id -g)" \
                        -v "$WORKSPACE:/repo" -w /repo \
                        "$GITLEAKS_IMAGE" git /repo \
                        --config security/.gitleaks.toml \
                        --redact --verbose \
                        --report-format json --report-path reports/gitleaks.json \
                        --exit-code 1
                '''
            }
        }

        stage('Install & Unit Tests') {
            steps {
                sh '''
                    set -eu
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet --upgrade pip
                    pip install --quiet -r app/requirements.txt -r app/requirements-dev.txt
                    pytest --junitxml=reports/test-results.xml \
                           --cov=app --cov-report=xml:reports/coverage.xml
                '''
            }
            post {
                always {
                    junit 'reports/test-results.xml'
                }
            }
        }

        stage('SAST (SonarQube)') {
            steps {
                withCredentials([string(credentialsId: 'sonar_token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        docker run --rm --network host --user "$(id -u):$(id -g)" \
                            -e SONAR_HOST_URL="$SONAR_HOST" \
                            -e SONAR_TOKEN \
                            -e SONAR_USER_HOME="$WORKSPACE/.sonar" \
                            -e SCANNER_WORKDIR_PATH="$WORKSPACE/.scannerwork" \
                            -v "$WORKSPACE:$WORKSPACE" -w "$WORKSPACE" \
                            "$SONAR_IMAGE" \
                            -Dsonar.projectBaseDir="$WORKSPACE" \
                            -Dsonar.working.directory="$WORKSPACE/.scannerwork" \
                            -Dsonar.projectVersion="$IMAGE_TAG" \
                            -Dsonar.qualitygate.wait=true \
                            -Dsonar.qualitygate.timeout=300
                    '''
                }
            }
            post {
                always {
                    withCredentials([string(credentialsId: 'sonar_token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            set +e
                            sonar_api() {
                                curl -sf -H "Authorization: Bearer $SONAR_TOKEN" "$SONAR_HOST/api/$1"
                            }
                            sonar_api "qualitygates/project_status?projectKey=weather-app" \
                                > reports/sonar-quality-gate.json
                            sonar_api "issues/search?componentKeys=weather-app&resolved=false&ps=500" \
                                > reports/sonar-issues.json
                            exit 0
                        '''
                    }
                }
            }
        }

        stage('SCA (Snyk)') {
            steps {
                withCredentials([string(credentialsId: 'snyk_token', variable: 'SNYK_TOKEN')]) {
                    sh '''
                        set +e
                        docker run --rm -e SNYK_TOKEN \
                            -v "$WORKSPACE:/project:ro" -w /project \
                            --entrypoint sh "$SNYK_IMAGE" -c '
                                pip install --quiet -r app/requirements.txt >/dev/null 2>&1 &&
                                snyk test --file=app/requirements.txt --package-manager=pip \
                                    --severity-threshold=high --json
                            ' > reports/snyk.json
                        rc=$?

                        jq -r '.vulnerabilities[]? | "\\(.severity)\\t\\(.packageName)@\\(.version)\\t\\(.id)\\t\\(.title)"' \
                            reports/snyk.json | sort -u > reports/snyk-summary.txt
                        cat reports/snyk-summary.txt

                        exit $rc
                    '''
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build --pull --build-arg APP_VERSION="$IMAGE_TAG" -t "$IMAGE_URI" app/'
            }
        }

        stage('SBOM (Syft)') {
            steps {
                sh '''
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        "$SYFT_IMAGE" "docker:$IMAGE_URI" -o cyclonedx-json \
                        > reports/sbom.cdx.json
                    jq -r '"SBOM: \\(.components | length) components, format \\(.bomFormat) \\(.specVersion)"' \
                        reports/sbom.cdx.json
                '''
            }
        }

        stage('Image Scan (Trivy)') {
            steps {
                sh '''
                    set -eu
                    trivy() {
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v trivy-cache:/root/.cache \
                            -v "$WORKSPACE/security:/security:ro" \
                            "$TRIVY_IMAGE" image --scanners vuln \
                            --ignorefile /security/.trivyignore "$@" "$IMAGE_URI"
                    }
                    trivy --severity HIGH,CRITICAL --format table --exit-code 0 > reports/trivy.txt
                    cat reports/trivy.txt
                    trivy --severity HIGH,CRITICAL --ignore-unfixed --format json --exit-code 1 > reports/trivy.json
                '''
            }
        }

        stage('DAST (OWASP ZAP)') {
            steps {
                sh '''
                    set -eu
                    NET="zap-$BUILD_NUMBER"; APP="app-$BUILD_NUMBER"
                    docker network create "$NET" > /dev/null
                    docker run -d --name "$APP" --network "$NET" -e APP_VERSION="$IMAGE_TAG" "$IMAGE_URI" > /dev/null

                    for i in $(seq 1 30); do
                        docker exec "$APP" python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" 2>/dev/null && break
                        sleep 2
                    done

                    mkdir -p reports/zap && chmod 777 reports/zap
                    cp security/zap-rules.tsv reports/zap/

                    set +e
                    docker run --rm --network "$NET" -v "$WORKSPACE/reports/zap:/zap/wrk:rw" \
                        "$ZAP_IMAGE" zap-baseline.py -t "http://$APP:8000" \
                        -c zap-rules.tsv -r zap.html -J zap.json -I
                    rc=$?
                    set -e

                    if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
                        echo "ZAP exited $rc"; exit 1
                    fi
                    high=$(jq '[.site[].alerts[] | select(.riskcode == "3")] | length' reports/zap/zap.json)
                    echo "ZAP High-risk alerts: $high"
                    [ "$high" -eq 0 ]
                '''
            }
            post {
                always {
                    sh '''
                        docker rm -f "app-$BUILD_NUMBER" > /dev/null 2>&1 || true
                        docker network rm "zap-$BUILD_NUMBER" > /dev/null 2>&1 || true
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    set -eu
                    aws ecr get-login-password --region "$AWS_REGION" \
                        | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$IMAGE_URI"
                '''
            }
        }

        stage('Render & Register Task Definition') {
            steps {
                sh '''
                    set -eu
                    export APP_VERSION="$IMAGE_TAG"
                    scripts/render-taskdef.sh "reports/taskdef-$IMAGE_TAG.json"
                '''
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh 'scripts/deploy-ecs.sh "reports/taskdef-$IMAGE_TAG.json" reports/ecs'
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    set -eu
                    ALB_DNS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
                        --names "$ALB_NAME" --query 'LoadBalancers[0].DNSName' --output text)
                    echo "http://$ALB_DNS" > reports/ecs/app-url.txt

                    ok=0
                    for i in $(seq 1 20); do
                        v=$(curl -fsS "http://$ALB_DNS/health" | jq -r .version || true)
                        echo "attempt $i: version=$v"
                        if [ "$v" = "$IMAGE_TAG" ]; then ok=$((ok+1)); else ok=0; fi
                        [ "$ok" -ge 4 ] && break
                        sleep 3
                    done
                    [ "$ok" -ge 4 ] || { echo "ALB is not serving $IMAGE_TAG"; exit 1; }
                    curl -fsS "http://$ALB_DNS/health" | tee reports/ecs/health.json
                '''
            }
        }

        stage('Cleanup Old Revisions') {
            steps {
                sh 'scripts/cleanup-taskdefs.sh "$TASK_FAMILY" 3 | tee reports/ecs/cleanup.txt'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true, fingerprint: true
            sh '''
                set +e
                docker logout "$ECR_REGISTRY" > /dev/null 2>&1
                docker rmi "$IMAGE_URI" > /dev/null 2>&1
                docker image prune -f > /dev/null
                rm -rf .venv .sonar .scannerwork
                exit 0
            '''
        }
    }
}
