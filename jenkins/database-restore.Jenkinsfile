pipeline {
  agent { label 'database-utility' }

  parameters {
    choice(name: 'DB_ENGINE', choices: ['postgres', 'mysql'], description: 'Database engine')
    string(name: 'DB_HOST', defaultValue: '', description: 'PostgreSQL hostname or RDS endpoint')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'SOURCE_DB', defaultValue: 'wayfarer_source', description: 'Source database name')
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Required feature name; target DB becomes wayfarer_feature_<name>')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Existing dump identifier')
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
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          if (!params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required') }
          if (!params.RELEASE_ID?.trim()) { error('RELEASE_ID is required') }
          env.RELEASE_ID = params.RELEASE_ID.trim()
        }
        sh '''
          set -eu
          if [ "$DB_ENGINE" = postgres ]; then
            test -x scripts/db-restore.sh && bash -n scripts/db-restore.sh
          else
            test -x scripts/mysql/mysql-restore.sh && bash -n scripts/mysql/mysql-restore.sh
          fi
        '''
      }
    }

    stage('Restore dump') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD'),
          usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'APP_USER', passwordVariable: 'APP_PASSWORD')
        ]) {
          sh '''
            set -eu
            if [ "$DB_ENGINE" = postgres ]; then
              : "${APP_USER:?APP_USER is required for PostgreSQL restore}"
              : "${APP_PASSWORD:?APP_PASSWORD is required for PostgreSQL restore}"
              DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" FEATURE_NAME="$FEATURE_NAME" \
              DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
              SOURCE_DB="$SOURCE_DB" BACKUP_DIR="$BACKUP_ROOT/postgres" \
              STATE_DIR="$STATE_ROOT/postgres" LOG_DIR="$LOG_ROOT/postgres" \
              scripts/db-restore.sh "$RELEASE_ID"
            else
              DB_HOST="$DB_HOST" DB_PORT="${DB_PORT:-3306}" FEATURE_NAME="$FEATURE_NAME" \
              DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
              SOURCE_DB="$SOURCE_DB" BACKUP_DIR="$BACKUP_ROOT/mysql" \
              STATE_DIR="$STATE_ROOT/mysql" LOG_DIR="$LOG_ROOT/mysql" \
              scripts/mysql/mysql-restore.sh "$RELEASE_ID"
            fi
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
