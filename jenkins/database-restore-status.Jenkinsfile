pipeline {
  agent { label 'database-utility' }

  parameters {
    choice(name: 'DB_ENGINE', choices: ['postgres', 'mysql'], description: 'Database engine')
    string(name: 'RELEASE_ID', defaultValue: '', description: 'Restore release identifier')
  }

  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Validate') {
      steps {
        script {
          if (!params.RELEASE_ID?.trim()) { error('RELEASE_ID is required') }
          env.RELEASE_ID = params.RELEASE_ID.trim()
        }
        sh '''
          set -eu
          if [ "$DB_ENGINE" = postgres ]; then
            test -x scripts/db-restore-status.sh
            bash -n scripts/db-restore-status.sh
          else
            test -x scripts/mysql/mysql-status.sh
            bash -n scripts/mysql/mysql-status.sh
          fi
        '''
      }
    }
    stage('Check restore status') {
      steps {
        sh '''
          set -eu
          if [ "$DB_ENGINE" = postgres ]; then
            STATE_DIR=/var/jenkins_home/database-restore-state/postgres LOG_DIR=/var/jenkins_home/database-restore-logs/postgres \
              scripts/db-restore-status.sh "$RELEASE_ID"
          else
            STATE_DIR=/var/lib/mysql/restore-state LOG_DIR=/var/log/mysql-restore \
              scripts/mysql/mysql-status.sh "$RELEASE_ID"
          fi
        '''
      }
    }
  }
}
