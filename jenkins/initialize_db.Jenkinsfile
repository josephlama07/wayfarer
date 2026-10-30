pipeline {
  agent { label 'database-utility' }

  parameters {
    string(name: 'FEATURE_NAME', defaultValue: '', description: 'Feature name; database will be <feature_name>_db_name')
    string(name: 'DB_HOST', defaultValue: '', description: 'PostgreSQL hostname or RDS endpoint')
    string(name: 'DB_PORT', defaultValue: '5432', description: 'PostgreSQL port')
    string(name: 'DB_ADMIN_DB', defaultValue: 'postgres', description: 'Administrative PostgreSQL database')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Validate and derive database name') {
      steps {
        script {
          if (!params.FEATURE_NAME?.trim()) { error('FEATURE_NAME is required') }
          if (!params.DB_HOST?.trim()) { error('DB_HOST is required') }

          def featureName = params.FEATURE_NAME.trim().replaceAll('-', '_')
          def targetDb = "${featureName}_db_name"
          def identifierPattern = /^[A-Za-z_][A-Za-z0-9_]*$/

          if (!(featureName ==~ identifierPattern)) {
            error("Invalid FEATURE_NAME: ${params.FEATURE_NAME}. Use letters, numbers, underscores, or hyphens.")
          }
          if (!(targetDb ==~ identifierPattern)) {
            error("Invalid derived database name: ${targetDb}")
          }

          env.FEATURE_NAME_NORMALIZED = featureName
          env.TARGET_DB = targetDb
        }
        sh '''
          set -eu
          command -v psql >/dev/null
          printf 'Feature name: %s\nTarget database: %s\n' "$FEATURE_NAME_NORMALIZED" "$TARGET_DB"
        '''
      }
    }

    stage('Initialize database') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'postgres-setup-operator',
          usernameVariable: 'DB_ADMIN_USER',
          passwordVariable: 'DB_ADMIN_PASSWORD'
        )]) {
          sh '''
            set -eu
            export PGPASSWORD="$DB_ADMIN_PASSWORD"

            exists="$(psql \
              --host="$DB_HOST" \
              --port="$DB_PORT" \
              --username="$DB_ADMIN_USER" \
              --dbname="$DB_ADMIN_DB" \
              --tuples-only --no-align \
              --command="SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB'" \
              | tr -d '[:space:]')"

            if [ "$exists" = "1" ]; then
              printf 'Database already exists: %s\n' "$TARGET_DB"
            else
              psql \
                --host="$DB_HOST" \
                --port="$DB_PORT" \
                --username="$DB_ADMIN_USER" \
                --dbname="$DB_ADMIN_DB" \
                --set=ON_ERROR_STOP=1 \
                --command="CREATE DATABASE $TARGET_DB"
              printf 'Database created: %s\n' "$TARGET_DB"
            fi

            verified="$(psql \
              --host="$DB_HOST" \
              --port="$DB_PORT" \
              --username="$DB_ADMIN_USER" \
              --dbname="$DB_ADMIN_DB" \
              --tuples-only --no-align \
              --command="SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB'" \
              | tr -d '[:space:]')"

            [ "$verified" = "1" ]
            printf 'Database initialization verified: %s\n' "$TARGET_DB"
          '''
        }
      }
    }
  }

  post {
    success { echo "Database initialization completed: ${env.TARGET_DB ?: 'unknown'}" }
    failure { echo "Database initialization failed: ${env.TARGET_DB ?: 'unknown'}" }
  }
}
