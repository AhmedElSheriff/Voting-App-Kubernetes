export AWS_PROFILE="dev"
CLUSTER_NAME='basic-cluster'
REGION='us-east-1'
ACCOUNT_ID="$(aws sts get-caller-identity --query Account)"
ACCOUNT_ID="${ACCOUNT_ID//[\",]}"
DOMAIN="abshafi.website"
CURRENT_DATETIME=$(date +%d-%m-%y-%T)
PUBLIC_KEY_PATH="key.pub"