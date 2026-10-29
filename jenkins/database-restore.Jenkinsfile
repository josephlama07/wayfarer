pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'DB_HOST', defaultValue: '', description: 'PostgreSQL hostname or RDS endpoint')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Required feature name; target DB becomes wayfarer_feature_<name>')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Existing dump identifier')
  }

  environment {
    BACKUP_DIR = '/opt/backup/postgres-backup'
    STATE_DIR = '/var/lib/wayfarer/restore-state'
    LOG_DIR = '/var/log/wayfarer'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate') {
      steps {
        script {
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          if (!params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required') }
          if (!params.RELEASE_ID?.trim()) { error('RELEASE_ID is required') }
          env.RELEASE_ID = params.RELEASE_ID.trim()
        }
        sh 'test -x scripts/db-restore.sh && bash -n scripts/db-restore.sh'
      }
    }

    stage('Restore dump') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD'),
          usernamePassword(credentialsId: 'wayfarer-db-app', usernameVariable: 'APP_USER', passwordVariable: 'APP_PASSWORD')
        ]) {
          sh '''
            set -eu
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" FEATURE_NAME="$FEATURE_NAME" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            APP_USER="$APP_USER" APP_PASSWORD="$APP_PASSWORD" \
            SOURCE_DB="${SOURCE_DB:-wayfarer_source}" BACKUP_DIR="$BACKUP_DIR" \
            STATE_DIR="$STATE_DIR" LOG_DIR="$LOG_DIR" \
            scripts/db-restore.sh "$RELEASE_ID"
          '''
        }
      }
    }
  }

  post {
    success { echo "Restore submitted for ${env.RELEASE_ID}; completion must be checked separately." }
    failure { echo "Database restore submission failed: ${env.RELEASE_ID ?: 'unknown'}" }
  }
}
