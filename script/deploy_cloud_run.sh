#!/usr/bin/env bash
set -euo pipefail

# -------- Config (edit these) --------
PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
REGION="${REGION:-europe-west1}"
SERVICE="${SERVICE:-circle2search-backend}"
SECRET="${SECRET:-replace-with-long-random-secret}"
# ------------------------------------

if [[ "$PROJECT_ID" == "your-gcp-project-id" ]]; then
  echo "Set PROJECT_ID first. Example:"
  echo '  PROJECT_ID="my-project" SECRET="$(openssl rand -hex 32)" ./script/deploy_cloud_run.sh'
  exit 1
fi

echo "Using PROJECT_ID=$PROJECT_ID REGION=$REGION SERVICE=$SERVICE"

gcloud config set project "$PROJECT_ID"

echo "Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  translate.googleapis.com \
  artifactregistry.googleapis.com

SA_EMAIL="${SERVICE}-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account (if missing)..."
gcloud iam service-accounts create "${SERVICE}-sa" \
  --display-name="Circle2Search Backend SA" || true

echo "Granting Cloud Translate role..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudtranslate.user"

ENV_VARS_FILE="$(mktemp)"
trap 'rm -f "$ENV_VARS_FILE"' EXIT
cat >"$ENV_VARS_FILE" <<EOF
GOOGLE_CLOUD_PROJECT: "$PROJECT_ID"
GOOGLE_TRANSLATE_ENDPOINT: "translate-eu.googleapis.com"
GOOGLE_TRANSLATE_LOCATION: "$REGION"
GOOGLE_TRANSLATE_MODEL: "general/nmt"
GOOGLE_TRANSLATE_LABELS_JSON: '{"app":"circle2search","surface":"screen_translate"}'
TRANSLATE_SHARED_SECRET: "$SECRET"
EOF

echo "Deploying Cloud Run service..."
gcloud run deploy "$SERVICE" \
  --source backend \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --service-account "$SA_EMAIL" \
  --env-vars-file "$ENV_VARS_FILE"

SERVICE_URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"

echo
echo "Deploy complete."
echo "SERVICE_URL=$SERVICE_URL"
echo
echo "Health check:"
echo "  curl -i \"$SERVICE_URL/healthz\""
echo
echo "Translate test:"
echo "  TRANSLATE_SHARED_SECRET=\"$SECRET\" ./script/test_translate_backend.sh \"$SERVICE_URL\" sv"