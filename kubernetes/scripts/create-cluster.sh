#! /usr/bin/bash

source ./variables.sh

# Create AWS Network Environment
aws cloudformation create-stack --stack-name network-stack \
  --template-body file://../cloudformation/network.yml  \
  --parameters file://../cloudformation/network-params.json \
  --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
  --region=$REGION
echo "Waiting for cloudformation stack to complete!"
aws cloudformation wait stack-create-complete --stack-name "network-stack"

# Create Route 53 Hosted Zone >> TO BE RUN FOR THE FIRST TIME ONLY
aws route53 create-hosted-zone --name $DOMAIN --caller-reference ${DOMAIN}${CURRENT_DATETIME} > /dev/null

# Dynamically create the cluster YAML file
subnets=`aws cloudformation list-exports --query "Exports[?Name=='Voting-App-PRIV-NETS'].Value" --output text`
subnetsArr=(${subnets//,/ })
availabilityZones=`aws cloudformation list-exports --query "Exports[?Name=='Voting-App-PRIV-NETS-AZ'].Value" --output text`
azsArr=(${availabilityZones//,/ })
mkdir -p ~/eks
`cat > ~/eks/cluster.yml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $CLUSTER_NAME
  region: $REGION
# privateCluster:
#   enabled: true
vpc:
  subnets:
    private:
      ${azsArr[0]}: { id: ${subnetsArr[0]} }
      ${azsArr[1]}: { id: ${subnetsArr[1]} }
nodeGroups:
  - name: ng-1
    instanceType: t2.medium
    desiredCapacity: 2
    volumeSize: 100
    privateNetworking: true
    ssh:
      publicKeyPath: ${PUBLIC_KEY_PATH}
EOF
`
# Run the cluster YAML file
eksctl create cluster -f ~/eks/cluster.yml

aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME


# Create an IAM OIDC identity provider for the cluster
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

aws iam create-policy \
  --policy-name AllowExternalDNSUpdates \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["route53:ChangeResourceRecordSets"],"Resource":["arn:aws:route53:::hostedzone/*"]},{"Effect":"Allow","Action":["route53:ListHostedZones","route53:ListResourceRecordSets"],"Resource":["*"]}]}' > /dev/null

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --name=external-dns \
  --namespace=default \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AllowExternalDNSUpdates --approve

# Create IAM Policy for the AWS Load Balancer Controller
curl -Lo ~/eks/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://~/eks/iam_policy.json > /dev/null


# Create IAM Role for Kubernetes Service Account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install Cert Manager to the Cluster
kubectl apply \
    --validate=false \
    -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml


# Download The Controller
curl -Lo ~/eks/v2_4_7_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.7/v2_4_7_full.yaml
# # Remove the Service Account from the Controller file to avoid overwriting what we did in previous steps
sed -i '561,569d' ~/eks/v2_4_7_full.yaml
sed -i "s/your-cluster-name/$CLUSTER_NAME/g" ~/eks/v2_4_7_full.yaml
# Install the Controller
kubectl apply -f ~/eks/v2_4_7_full.yaml


# Install the IngressClass
curl -Lo ~/eks/v2_4_7_ingclass.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.7/v2_4_7_ingclass.yaml
kubectl apply -f ~/eks/v2_4_7_ingclass.yaml


# # Deploy K8s Resources
kubectl apply -f ../.

route53_id=$(aws route53 list-hosted-zones --query "HostedZones[].{Id:Id, Name:$DOMAIN}[0].Id" --output text | cut -d / -f3)
aws route53 list-resource-record-sets --hosted-zone-id $route53_id --query 'ResourceRecordSets[?Type == `NS`].ResourceRecords[].Value'