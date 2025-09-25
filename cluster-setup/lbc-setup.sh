aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://./lbc-iam-policy.json

export AWS_ACCOUNT_ID=<YOUR_AWS_ACCOUNT_ID>
export VPC_ID=<YOUR_VPC_ID>
export CLUSTER_NAME=<YOUR_CLUSTER_NAME>
export REGION=<YOUR_REGION>

eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --region=${REGION} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set vpcId=${VPC_ID} \
  --set region=${REGION} \
  --set serviceAccount.name=aws-load-balancer-controller