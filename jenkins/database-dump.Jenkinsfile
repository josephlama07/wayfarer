pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'DB_HOST', defaultValue: '', description: 'PostgreSQL hostname or RDS endpoint')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'SOURCE_DB', defaultValue: 'wayfarer_source', description: 'Source database')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Dump identifier; defaults to build number')
  }

  environment {
    BACKUP_DIR = '/var/jenkins_home/database-backups/postgres'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate') {
      steps {
        script {
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          env.RELEASE_ID = params.RELEASE_ID?.trim() ?: "build-${env.BUILD_NUMBER}"
        }
        sh 'test -x scripts/db-dump.sh && bash -n scripts/db-dump.sh'
      }
    }

    stage('Dump source database') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
          sh '''
            set -eu
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" SOURCE_DB="$SOURCE_DB" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            BACKUP_DIR="$BACKUP_DIR" scripts/db-dump.sh "$RELEASE_ID"
          '''
        }
      }
    }
  }

  post {
    success { echo "Database dump completed: ${env.RELEASE_ID}" }
    failure { echo "Database dump failed: ${env.RELEASE_ID ?: 'unknown'}" }
  }
}
