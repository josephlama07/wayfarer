pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Feature identifier, e.g. poc-1')
    string(name: 'DB_HOST', defaultValue: 'host.minikube.internal', description: 'PostgreSQL host reachable from Jenkins')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'SOURCE_DB', defaultValue: 'wayfarer_source', description: 'Source PostgreSQL database')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Dump identifier; defaults to build number')
    string(name: 'IMAGE_TAG', defaultValue: 'local', description: 'Existing image tag available to Minikube')
    booleanParam(name: 'KEEP_ENVIRONMENT', defaultValue: true, description: 'Keep the feature namespace after the build')
  }

  environment {
    BACKUP_DIR = '/var/jenkins_home/database-backups/postgres'
    STATE_DIR = '/var/jenkins_home/database-restore-state/postgres'
    LOG_DIR = '/var/jenkins_home/database-restore-logs/postgres'
    IMAGE_REPOSITORY = 'wayfarer'
  }

  stages {
    stage('Validate') {
      steps {
        checkout scm
        script {
          if (!params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required') }
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          env.FEATURE_NAME_SAFE = params.FEATURE_NAME.trim().toLowerCase().replaceAll('[^a-z0-9-]', '-').replaceAll('-+', '-').replaceAll('^-|-$', '')
          if (!env.FEATURE_NAME_SAFE || env.FEATURE_NAME_SAFE.length() > 40) { error('FEATURE_NAME must produce a valid short identifier') }
          env.RELEASE_ID = params.RELEASE_ID?.trim() ?: "feature-${env.FEATURE_NAME_SAFE}-build-${env.BUILD_NUMBER}"
          env.TARGET_DB = "wayfarer_feature_${env.FEATURE_NAME_SAFE.replaceAll('-', '_')}"
          env.FEATURE_NAMESPACE = "wayfarer-${env.FEATURE_NAME_SAFE}"
          env.HELM_RELEASE = "wayfarer-${env.FEATURE_NAME_SAFE}"
          env.IMAGE = "${env.IMAGE_REPOSITORY}:${params.IMAGE_TAG.trim()}"
        }
        sh 'bash -n scripts/db-dump.sh scripts/db-restore.sh scripts/db-restore-status.sh scripts/db-verify.sh && test -x scripts/db-verify.sh'
        sh 'pg_isready --version; pg_dump --version; pg_restore --version; psql --version; kubectl version --client=true; helm version --short'
      }
    }

    stage('Dump source database') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
          sh '''
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" SOURCE_DB="$SOURCE_DB" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            BACKUP_DIR="$BACKUP_DIR" scripts/db-dump.sh "$RELEASE_ID"
          '''
        }
      }
    }

    stage('Restore feature database') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')
        ]) {
          sh '''
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" FEATURE_NAME="$FEATURE_NAME_SAFE" TARGET_DB="$TARGET_DB" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            APP_USER="$DB_ADMIN_USER" APP_PASSWORD="$DB_ADMIN_PASSWORD" \
            BACKUP_DIR="$BACKUP_DIR" STATE_DIR="$STATE_DIR" LOG_DIR="$LOG_DIR" \
            scripts/db-restore.sh "$RELEASE_ID"
          '''
          timeout(time: 5, unit: 'MINUTES') {
            waitUntil {
              script {
                def status = sh(script: "STATE_DIR='${env.STATE_DIR}' LOG_DIR='${env.LOG_DIR}' scripts/db-restore-status.sh '${env.RELEASE_ID}'", returnStatus: true)
                return status == 0
              }
            }
          }
        }
      }
    }

    stage('Verify feature database') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
          sh '''
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" FEATURE_NAME="$FEATURE_NAME_SAFE" TARGET_DB="$TARGET_DB" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            EXPECTED_TABLES=waypoints,trips scripts/db-verify.sh
          '''
        }
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
      echo "Feature=${env.FEATURE_NAME_SAFE} Namespace=${env.FEATURE_NAMESPACE} Database=${env.TARGET_DB} Release=${env.RELEASE_ID}"
      script {
        if (!params.KEEP_ENVIRONMENT && env.FEATURE_NAMESPACE) {
          sh "helm uninstall '${env.HELM_RELEASE}' --namespace '${env.FEATURE_NAMESPACE}' || true; kubectl delete namespace '${env.FEATURE_NAMESPACE}' --ignore-not-found"
        }
      }
    }
    success { echo 'Feature release POC completed successfully.' }
    failure { echo 'Feature release POC failed; inspect the build log and restore log.' }
  }
}
