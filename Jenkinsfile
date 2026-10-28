pipeline {
  agent {
    kubernetes {
      defaultContainer 'node'
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node
    image: node:20.18.1-alpine3.20
    command: [sleep]
    args: [99d]
  - name: docker
    image: docker:27-cli
    command: [sleep]
    args: [99d]
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: helm-kubectl
    image: dtzar/helm-kubectl:3.16.4
    command: [sleep]
    args: [99d]
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
    }
  }

  environment {
    IMAGE_REPOSITORY = 'wayfarer'
    IMAGE_TAG = "${env.GIT_COMMIT ?: env.BUILD_TAG}"
    IMAGE = "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
    KUBECONFIG = "${env.WORKSPACE}/.kube/config"
  }

  stages {
    stage('Install') {
      steps { sh 'npm ci' }
    }

    stage('Quality') {
      steps {
        sh 'npm run lint'
        sh 'npm run typecheck'
        sh 'npm run build'
      }
    }

    stage('Configure cluster access') {
      steps {
        container('helm-kubectl') {
          sh '''
            mkdir -p "$(dirname "$KUBECONFIG")"
            kubectl config set-cluster minikube \
              --server=https://kubernetes.default \
              --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
              --embed-certs=true
            kubectl config set-credentials jenkins \
              --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
            kubectl config set-context minikube --cluster=minikube --user=jenkins
            kubectl config use-context minikube
            kubectl auth can-i get pods
          '''
        }
      }
    }

    stage('Helm lint') {
      steps {
        container('helm-kubectl') {
          sh 'helm lint helm/wayfarer'
          sh 'helm template wayfarer helm/wayfarer --namespace wayfarer-local --set image.repository="$IMAGE_REPOSITORY" --set image.tag="$IMAGE_TAG" >/tmp/wayfarer-rendered.yaml'
          sh 'kubectl apply --dry-run=client -f /tmp/wayfarer-rendered.yaml >/dev/null'
        }
      }
    }

    stage('Build local image') {
      steps {
        container('docker') {
          sh 'docker build --tag "$IMAGE" .'
          sh 'docker image inspect "$IMAGE" >/dev/null'
        }
      }
    }

    stage('Deploy feature environment') {
      steps {
        script {
          def rawBranch = env.CHANGE_ID ? "pr-${env.CHANGE_ID}" : (env.BRANCH_NAME ?: 'local')
          env.FEATURE_NAMESPACE = rawBranch.toLowerCase().replaceAll('[^a-z0-9-]', '-').replaceAll('-+', '-').replaceAll('^-|-$', '').take(63)
          if (!env.FEATURE_NAMESPACE) { env.FEATURE_NAMESPACE = 'wayfarer-local' }
        }
        container('helm-kubectl') {
          sh '''
            kubectl create namespace "$FEATURE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
            helm upgrade --install wayfarer helm/wayfarer \
              --namespace "$FEATURE_NAMESPACE" \
              --set image.repository="$IMAGE_REPOSITORY" \
              --set image.tag="$IMAGE_TAG" \
              --set image.pullPolicy=IfNotPresent \
              --atomic \
              --wait \
              --timeout 5m
            kubectl rollout status deployment/wayfarer-wayfarer --namespace "$FEATURE_NAMESPACE" --timeout=180s
          '''
        }
      }
    }

    stage('Smoke test') {
      steps {
        container('helm-kubectl') {
          sh '''
            kubectl run wayfarer-smoke --namespace "$FEATURE_NAMESPACE" \
              --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet -- \
              curl --fail --silent --show-error --max-time 20 \
              http://wayfarer-wayfarer:3000/
          '''
        }
      }
    }
  }
}
