pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Dump/release identifier to clean up')
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Feature name used to derive the target database')
    booleanParam(name: 'DROP_TARGET_DB', defaultValue: false, description: 'Also drop the derived target database')
    string(name: 'DB_HOST', defaultValue: '', description: 'Required only when dropping the target database')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
  }

  environment {
    BACKUP_DIR = '/var/jenkins_home/database-backups/postgres'
    STATE_DIR = '/var/jenkins_home/database-restore-state/postgres'
    LOG_DIR = '/var/jenkins_home/database-restore-logs/postgres'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate') {
      steps {
        script {
          if (!params.RELEASE_ID?.trim()) { error('RELEASE_ID is required') }
          if (params.DROP_TARGET_DB && !params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required when DROP_TARGET_DB is true') }
          if (params.DROP_TARGET_DB && !params.DB_HOST?.trim()) { error('DB_HOST is required when DROP_TARGET_DB is true') }
          env.RELEASE_ID = params.RELEASE_ID.trim()
          env.TARGET_DB = params.FEATURE_NAME?.trim() ? "wayfarer_feature_${params.FEATURE_NAME.trim()}" : ''
        }
        sh 'test -x scripts/db-release-destroy.sh && bash -n scripts/db-release-destroy.sh'
      }
    }

    stage('Remove release artifacts') {
      steps {
        script {
          if (params.DROP_TARGET_DB) {
            withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
              sh '''
                set -eu
                DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
                TARGET_DB="$TARGET_DB" BACKUP_DIR="$BACKUP_DIR" STATE_DIR="$STATE_DIR" LOG_DIR="$LOG_DIR" \
                scripts/db-release-destroy.sh "$RELEASE_ID" --drop-target --confirm-release "$RELEASE_ID"
              '''
            }
          } else {
            sh '''
              set -eu
              BACKUP_DIR="$BACKUP_DIR" STATE_DIR="$STATE_DIR" LOG_DIR="$LOG_DIR" \
              scripts/db-release-destroy.sh "$RELEASE_ID"
            '''
          }
        }
      }
    }
  }

  post {
    success { echo "Database release cleanup completed: ${env.RELEASE_ID}" }
    failure { echo "Database release cleanup failed: ${env.RELEASE_ID ?: 'unknown'}" }
  }
}
