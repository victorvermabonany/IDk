#!/usr/bin/env bash
set -euo pipefail

[[ "${CONFIGURATION:-}" == "Release" ]] || exit 0

required=(COVE_API_BASE_URL COVE_PRIVACY_URL COVE_TERMS_URL COVE_SUPPORT_URL)
for name in "${required[@]}"; do
  value="${!name:-}"
  if [[ -z "$value" || "$value" != https://* ]]; then
    echo "error: $name must be a non-empty HTTPS URL for Release builds." >&2
    exit 1
  fi
done

if [[ "${COVE_RUNTIME_MODE:-}" != "PRODUCTION_LIVE" ]]; then
  echo "error: COVE_RUNTIME_MODE must be PRODUCTION_LIVE for Release builds." >&2
  exit 1
fi

if grep -R --include='*.swift' -n 'return DemoPlanRepository()' "$SRCROOT/Weektable" | grep -v AppConfiguration.swift >/dev/null; then
  echo "error: DemoPlanRepository is referenced outside the explicit Debug configuration gate." >&2
  exit 1
fi
