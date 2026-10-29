pipeline {
  agent { label 'database-utility' }

  parameters {
    choice(name: 'DB_ENGINE', choices: ['postgres'], description: 'Database engine')
    string(name: 'DB_HOST', defaultValue: '', description: 'PostgreSQL hostname or endpoint')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'DB_NAME', defaultValue: '', description: 'Explicit target database name')
    string(name: 'EXPECTED_TABLES', defaultValue: 'waypoints,trips', description: 'Comma-separated expected tables')
  }

  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Verify target database') {
      steps {
        script {
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }
          if (!params.DB_NAME?.trim()) { error('DB_NAME is required') }
        }
        withCredentials([usernamePassword(credentialsId: 'postgres-setup-operator', usernameVariable: 'DB_ADMIN_USER', passwordVariable: 'DB_ADMIN_PASSWORD')]) {
          sh '''
            set -eu
            DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" TARGET_DB="$DB_NAME" \
            DB_ADMIN_USER="$DB_ADMIN_USER" DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
            EXPECTED_TABLES="$EXPECTED_TABLES" scripts/db-verify.sh
          '''
        }
      }
    }
  }
}
