# envoy-gateway-opa-demo

A repo that holds the different Kubernetes manifests used in demoing Envoy Gateway and OPA on September 25, 2025.

## Setup

Make sure you have an EKS cluster deployed with public API access, and kubectl configured to access the Kubernetes API. If you'd like to create a custom kubeconfig, you can run the following commands. 

```sh
kubectl apply -f cluster-setup/admin-sa.yaml
sh cluster-setup/create-sa-token.sh
```

You'll also need to install the [aws-load-balancer-controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller). You can do so by running the following:

```sh
sh cluster-setup/lbc-setup.sh
```

**NOTE:** There are quite a few variables that you're expected to fill out in that file before you run it.

Next, install Envoy Gateway. I used Helm, but you can find other ways to install it on the [project website](https://gateway.envoyproxy.io/):

```sh
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.5.1 \
  -n envoy-gateway-system \
  --create-namespace
```

## FYI

Most of the YAML files have placeholders that you need to replace with your values. I tried to keep them reflective of the types of things you'll put there, but if you want to see previous examples, look at the commit history. My original push of this repo had most of the original resource IDs from AWS, the domain name I used in the demo, etc. The only things I haven't pushed up are anything related to secrets.

## The Demo

First thing is to add a TLS cert ARN to the GatewayClass in `ingress-basics/envoy-gateway-config.yaml` on line 32:

```yaml
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: <TLS_CERT_ARN>
```

The TLS cert should match the domain that you're going to point to the load balancers that are deployed with your Gateway.

Next, you can deploy your GatewayClass, Gateway, and the first HTTPRoute:

```sh
kubeclt apply -f ingress-basics/
```

If you added the aws-load-balancer-controller with the correct permissions, then you should have an external IP (in the form of an auto-generated domain) associated with your Gateway's LoadBalancer Service. You can check by running:

```sh
kubectl get services -n envoy-gateway-system
```

Now you'll want to point your domain name to the new network load balancer in Route53.

Once that's there, and DNS resolves across the internet, you should be able to access `https://<your-domain>/httpbin/`. Give it a try!

That's the simple routing part.

### Authentication

I used AWS Cognito for my OIDC client to call into Google authentication. You can use whatever OIDC client you like. Just be sure to replace the details in `user-authentication/apps-scp.yaml`. Explaining how to set up an OIDC client is, unfortunately, beyond the scope of this demo.

Once you have your OIDC client configured, you can deploy the SecurityPolicy and root path HTTPRoute by running:

```sh
kubectl apply -f user-authentication/
```

Now, provided you've set up your OIDC connection correctly (double-check those redirect URLs!), you should be forced to sign in to your IdP whenever you go to `https://<your-domain>/httpbin/`. If you're using something like Google, in which you're permanently signed in, you can check for the presence of an `AccessToken` cookie at `https://<your-domain>/httpbin/cookies`.

### Authorization

First thing you'll need to do is bundle and push your Rego policies to a remote store, such as S3. You can read all about how to do that on the [OPA project website](https://www.openpolicyagent.org/). You'll also need to provide a secret called `policy-creds` that has the appropriate IAM credentials to access the contents of that S3 bucket, using the following keys:

- `AWS_ACCESS_KEY_ID`
- `AWS_REGION`
- `AWS_SECRET_ACCESS_KEY`

The current state of the OPA deployment expects that to be there, and will load those IAM credentials as environment variables, and will subsequently pull the policy bundle from the S3 bucket (provided you gave that IAM principle access to do so).

How you want to structure your authorization rules is up to you. You're welcome to stick with using Cognito groups like I have in my policy at `user-authorization/codesalot/authz/policy.rego:63-79`, or modify that however you like. Just be sure to add the users to the right groups to authorize them to see those protected routes.

Enjoy!

## Questions?

Hit me on [LinkedIn](https://www.linkedin.com/in/colinjlacy/).
