pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Feature identifier, e.g. poc-1')
    string(name: 'DB_NAME', defaultValue: '', description: 'Explicit prepared target database name')
    string(name: 'DB_HOST', defaultValue: 'host.minikube.internal', description: 'PostgreSQL host reachable from Jenkins')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'IMAGE_TAG', defaultValue: 'local', description: 'Existing image tag available to Minikube')
    booleanParam(name: 'KEEP_ENVIRONMENT', defaultValue: true, description: 'Keep the feature namespace after the build')
  }

  environment {
    IMAGE_REPOSITORY = 'wayfarer'
  }

  stages {
    stage('Validate') {
      steps {
        checkout scm
        script {
          if (!params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required') }
          if (!params.DB_NAME?.trim()) { error('DB_NAME is required') }
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          env.FEATURE_NAME_SAFE = params.FEATURE_NAME.trim().toLowerCase().replaceAll('[^a-z0-9-]', '-').replaceAll('-+', '-').replaceAll('^-|-$', '')
          if (!env.FEATURE_NAME_SAFE || env.FEATURE_NAME_SAFE.length() > 40) { error('FEATURE_NAME must produce a valid short identifier') }
          env.TARGET_DB = params.DB_NAME.trim()
          env.FEATURE_NAMESPACE = "wayfarer-${env.FEATURE_NAME_SAFE}"
          env.HELM_RELEASE = "wayfarer-${env.FEATURE_NAME_SAFE}"
          env.IMAGE = "${env.IMAGE_REPOSITORY}:${params.IMAGE_TAG.trim()}"
        }
        sh 'kubectl version --client=true; helm version --short'
      }
    }

    stage('Migration') {
      steps {
        sh "printf 'SKIPPED: no migration runner configured for this POC\\n' | tee migration-result.txt"
        archiveArtifacts artifacts: 'migration-result.txt', fingerprint: false
      }
    }

    stage('Helm deploy') {
      steps {
        sh '''
          kubectl create namespace "$FEATURE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
          helm lint helm/wayfarer
          helm upgrade --install "$HELM_RELEASE" helm/wayfarer \
            --namespace "$FEATURE_NAMESPACE" \
            --set image.repository="$IMAGE_REPOSITORY" \
            --set image.tag="$IMAGE_TAG" \
            --set image.pullPolicy=IfNotPresent \
            --set env.DB_HOST="$DB_HOST" \
            --set env.DB_PORT="$DB_PORT" \
            --set env.DB_NAME="$TARGET_DB" \
            --atomic --wait --timeout 5m
          kubectl rollout status deployment/"$HELM_RELEASE"-wayfarer --namespace "$FEATURE_NAMESPACE" --timeout=180s
        '''
      }
    }

    stage('Smoke test') {
      steps {
        sh '''
          kubectl run wayfarer-smoke --namespace "$FEATURE_NAMESPACE" --image=curlimages/curl:8.10.1 \
            --restart=Never --rm -i --quiet -- \
            curl --fail --silent --show-error --max-time 20 http://"$HELM_RELEASE"-wayfarer:3000/
        '''
      }
    }
  }

  post {
    always {
      echo "Feature=${env.FEATURE_NAME_SAFE} Namespace=${env.FEATURE_NAMESPACE} Database=${env.TARGET_DB}"
      script {
        if (!params.KEEP_ENVIRONMENT && env.FEATURE_NAMESPACE) {
          sh "helm uninstall '${env.HELM_RELEASE}' --namespace '${env.FEATURE_NAMESPACE}' || true; kubectl delete namespace '${env.FEATURE_NAMESPACE}' --ignore-not-found"
        }
      }
    }
    success { echo 'Feature release POC completed successfully.' }
    failure { echo 'Feature release POC failed; verify the database was prepared by the database pipelines.' }
  }
}
