#!/usr/bin/env bash
set -euo pipefail

# Local POC only: host PostgreSQL 16 + Minikube workloads.
# Secrets are generated locally and written only to Kubernetes Secrets.

DB_HOST="${DB_HOST:-host.minikube.internal}"
DB_PORT="${DB_PORT:-5432}"
SOURCE_DB="${SOURCE_DB:-wayfarer_source}"
FEATURE_DB="${FEATURE_DB:-wayfarer_feature_local}"
ADMIN_ROLE="${ADMIN_ROLE:-wayfarer_admin}"
APP_ROLE="${APP_ROLE:-wayfarer_app}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-wayfarer-local}"
JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"

admin_password="$(openssl rand -hex 24)"
app_password="$(openssl rand -hex 24)"
psql_admin() {
  sudo -u postgres psql --set ON_ERROR_STOP=1 "$@"
}

psql_admin --dbname=postgres <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${ADMIN_ROLE}') THEN
    CREATE ROLE ${ADMIN_ROLE} LOGIN PASSWORD '${admin_password}';
  ELSE
    ALTER ROLE ${ADMIN_ROLE} WITH LOGIN PASSWORD '${admin_password}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_ROLE}') THEN
    CREATE ROLE ${APP_ROLE} LOGIN PASSWORD '${app_password}';
  ELSE
    ALTER ROLE ${APP_ROLE} WITH LOGIN PASSWORD '${app_password}';
  END IF;
END
\$\$;
SQL

if ! psql_admin --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname='${SOURCE_DB}'" | grep -q '^1$'; then
  psql_admin --dbname=postgres --command="CREATE DATABASE ${SOURCE_DB} OWNER ${ADMIN_ROLE};"
fi

if ! psql_admin --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname='${FEATURE_DB}'" | grep -q '^1$'; then
  psql_admin --dbname=postgres --command="CREATE DATABASE ${FEATURE_DB} OWNER ${APP_ROLE};"
fi

psql_admin --dbname=postgres --command="GRANT CONNECT ON DATABASE ${SOURCE_DB} TO ${ADMIN_ROLE};"
psql_admin --dbname=postgres --command="GRANT CONNECT ON DATABASE ${FEATURE_DB} TO ${APP_ROLE};"
psql_admin --dbname="${SOURCE_DB}" --command="GRANT USAGE,CREATE ON SCHEMA public TO ${ADMIN_ROLE};"
psql_admin --dbname="${FEATURE_DB}" --command="GRANT USAGE,CREATE ON SCHEMA public TO ${APP_ROLE};"
psql_admin --dbname="${FEATURE_DB}" --command="GRANT USAGE,CREATE ON SCHEMA public TO ${ADMIN_ROLE};"

kubectl -n "$JENKINS_NAMESPACE" create secret generic wayfarer-db-admin \
  --from-literal=DB_HOST="$DB_HOST" \
  --from-literal=DB_PORT="$DB_PORT" \
  --from-literal=DB_ADMIN_USER="$ADMIN_ROLE" \
  --from-literal=DB_ADMIN_PASSWORD="$admin_password" \
  --from-literal=SOURCE_DB="$SOURCE_DB" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$KUBE_NAMESPACE" create secret generic wayfarer-db-app \
  --from-literal=DB_HOST="$DB_HOST" \
  --from-literal=DB_PORT="$DB_PORT" \
  --from-literal=DB_USER="$APP_ROLE" \
  --from-literal=DB_PASSWORD="$app_password" \
  --from-literal=DATABASE_URL="postgresql://${APP_ROLE}:${app_password}@${DB_HOST}:${DB_PORT}/${FEATURE_DB}" \
  --from-literal=DB_NAME="$FEATURE_DB" \
  --dry-run=client -o yaml | kubectl apply -f -

printf 'Database POC setup completed.\n'
printf 'Source database: %s\n' "$SOURCE_DB"
printf 'Feature database: %s\n' "$FEATURE_DB"
printf 'Kubernetes Secrets: %s/wayfarer-db-admin and %s/wayfarer-db-app\n' "$JENKINS_NAMESPACE" "$KUBE_NAMESPACE"
