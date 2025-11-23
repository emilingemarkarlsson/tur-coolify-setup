#!/usr/bin/env bash
set -euo pipefail

REQUIRED=(
  APPSMITH_ENCRYPTION_PASSWORD
  APPSMITH_ENCRYPTION_SALT
  GF_SECURITY_ADMIN_USER
  GF_SECURITY_ADMIN_PASSWORD
  MONGO_INITDB_ROOT_USERNAME
  MONGO_INITDB_ROOT_PASSWORD
  REDIS_PASSWORD
  MINIO_ROOT_USER
  MINIO_ROOT_PASSWORD
  CLICKHOUSE_USER
  CLICKHOUSE_PASSWORD
)

if [[ ! -f .env ]]; then
  echo "[FAIL] .env file not found. Create it from .env.example" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

FAIL=0
printf "Checking required environment variables...\n\n"
for var in "${REQUIRED[@]}"; do
  value="${!var-}"
  if [[ -z "${value}" ]]; then
    printf "[MISSING] %s is not set\n" "$var"
    FAIL=1
  elif [[ "${value}" == CHANGEME* ]] || [[ "${value}" == *CHANGEME* ]]; then
    printf "[PLACEHOLDER] %s still has a CHANGEME value\n" "$var"
    FAIL=1
  else
    printf "[OK] %s set\n" "$var"
  fi
done

if [[ $FAIL -eq 1 ]]; then
  printf "\nValidation failed. Update missing/placeholder secrets before deploying.\n"
  exit 2
fi

printf "\nAll required env vars look good.\n"
