source ./variables.sh

kubectl delete -f ../.

eksctl delete iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=default \
  --name=external-dns

eksctl delete iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller

eksctl delete cluster -f ~/eks/cluster.yml

aws iam delete-policy --policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AllowExternalDNSUpdates
aws iam delete-policy --policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy

# route53_id=$(aws route53 list-hosted-zones --query "HostedZones[].{Id:Id, Name:$DOMAIN}[0].Id" --output text | cut -d / -f3)

# aws route53 delete-hosted-zone --id $route53_id

aws cloudformation delete-stack --stack-name network-stack

rm -rf ~/eks