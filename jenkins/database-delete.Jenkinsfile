pipeline {
  agent { label 'database-utility' }

  parameters {
    choice(name: 'DB_ENGINE', choices: ['postgres', 'mysql'], description: 'Database engine')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Dump/release identifier to clean up')
    string(name: 'DB_NAME', defaultValue: '', description: 'Explicit target database name')
    booleanParam(name: 'DROP_TARGET_DB', defaultValue: false, description: 'Also drop the explicitly supplied target database')
    string(name: 'DB_HOST', defaultValue: '', description: 'Required only when dropping the target database')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
  }

  environment {
    BACKUP_ROOT = '/var/jenkins_home/database-backups'
    STATE_ROOT = '/var/jenkins_home/database-restore-state'
    LOG_ROOT = '/var/jenkins_home/database-restore-logs'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate') {
      steps {
        script {
          if (!params.RELEASE_ID?.trim()) { error('RELEASE_ID is required') }
          if (params.DROP_TARGET_DB && !params.DB_NAME?.trim()) { error('DB_NAME is required when DROP_TARGET_DB is true') }
          if (params.DROP_TARGET_DB && !params.DB_HOST?.trim()) { error('DB_HOST is required when DROP_TARGET_DB is true') }
          env.RELEASE_ID = params.RELEASE_ID.trim()
          env.TARGET_DB = params.DB_NAME?.trim() ?: ''
        }
        sh '''
          set -eu
          if [ "$DB_ENGINE" = postgres ]; then
            test -x scripts/db-release-destroy.sh && bash -n scripts/db-release-destroy.sh
          else
            test -x scripts/mysql/mysql-delete.sh && bash -n scripts/mysql/mysql-delete.sh
          fi
        '''
      }
    }

    stage('Remove release artifacts') {
      steps {
        script {
          if (params.DROP_TARGET_DB && params.DB_ENGINE == 'postgres') {
            withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
              sh '''
                set -eu
                DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
                TARGET_DB="$TARGET_DB" BACKUP_DIR="$BACKUP_ROOT/postgres" STATE_DIR="$STATE_ROOT/postgres" LOG_DIR="$LOG_ROOT/postgres" \
                scripts/db-release-destroy.sh "$RELEASE_ID" --drop-target --confirm-release "$RELEASE_ID"
              '''
            }
          } else if (params.DB_ENGINE == 'postgres') {
            sh '''
              set -eu
              BACKUP_DIR="$BACKUP_ROOT/postgres" STATE_DIR="$STATE_ROOT/postgres" LOG_DIR="$LOG_ROOT/postgres" \
              scripts/db-release-destroy.sh "$RELEASE_ID"
            '''
          } else {
            withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
              sh '''
                set -eu
                BACKUP_DIR="$BACKUP_ROOT/mysql" STATE_DIR="$STATE_ROOT/mysql" LOG_DIR="$LOG_ROOT/mysql" \
                scripts/mysql/mysql-delete.sh "$RELEASE_ID"
              '''
            }
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
