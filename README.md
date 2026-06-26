# Cloud Engineering Project 08: Kubernetes Fortress (Hardened Compute Isolation & Pod-Level Identity Federation)

## Overview

I have architected and deployed a highly secure, production-grade container orchestration environment on AWS EKS using Infrastructure as Code primitives and zero-trust engineering methodologies. This project establishes a hardened Kubernetes infrastructure footprint by entirely segregating compute worker instances within private subnets, managing traffic ingress and egress using dedicated NAT Gateways, and completely eliminating static cloud credentials. By utilizing IAM Roles for Service Accounts (IRSA) via an OpenID Connect (OIDC) federated identity provider, pods fetch short-lived, cryptographic AWS resource tokens on demand. The architecture guarantees a self-healing operational baseline for containerized deployment microservices, ensuring continuous uptime while strictly confining operational boundaries to independent logical workspaces.

## The Problem

Standard Kubernetes implementations and default cloud cluster configurations frequently expose enterprise systems to excessive attack surfaces, compliance tracking failures, and systemic runtime configuration drift. Traditional container deployment setups typically experience three fatal design flaws:

* **Over-Exposed Worker Topologies:** Running worker instances inside public-facing subnets or assigning nodes direct public IPv4 mappings leaves cluster host platforms exposed to continuous internet scanning, automated credential stuffing bots, and network-level exploitation vectors.

* **Ambient Credential Proliferation:** Embedding static AWS Access Keys or long-lived IAM user secret strings inside container environments or deployment configurations violates the core principle of least privilege. If a single application layer pod is compromised, the leaked static token allows attackers to move laterally across the corporate cloud account.

* **Stateless Lifecycle Process Exits:** Deploying lightweight container images lacking persistent background daemons causes the Kubernetes engine to execute the primary container task and immediately shut down with a successful exit code. This behavior triggers an aggressive, endless cluster loop where workloads rapidly flip between initialization states and backoff errors, degrading overall node efficiency.

## The Solution

* **Perimeter Network Segregation:** Confined all worker compute resources strictly inside isolated private subnets. All communication bounds destined for the public internet are securely routed through stateful, public-facing NAT Gateways, shielding the underlying instances from direct external discovery.

* **Cryptographic Token Federation (IRSA):** Provisioned an AWS OIDC identity provider mapped directly to the EKS cluster API control plane. This enables the secure injection of short-lived, machine-level AWS identity tokens straight into specific workloads via local ServiceAccounts, limiting operational access without hardcoded credentials.

* **Workload Persistence Engineering:** Integrated custom shell execution wrappers directly into the container engine startup parameters. This provides stateless application tiers with an explicit, continuous background task loop, ensuring workloads retain a permanent running state while broadcasting active diagnostic logs.

* **Logical Boundary Partitioning:** Enforced absolute workspace governance by isolating all application infrastructure assets inside a dedicated, protected Kubernetes namespace partition, preventing cross-workspace naming collisions or unauthorized component interaction.

## Tech Stack

* **Orchestration Engine:** Amazon Elastic Kubernetes Service (EKS v1.35 Architecture)

* **Compute Infrastructure:** Amazon EC2 Managed Node Groups (t3.medium / Amazon Linux 2023)

* **Private Image Storage:** Amazon Elastic Container Registry (ECR Repository: devsecops-secure-app)

* **Identity Governance:** AWS IAM & OpenID Connect (OIDC Federated Trust Maps)

* **Workspace Isolation:** Kubernetes Namespaces (production-apps Logical Boundary)

* **Cluster Management Engine:** Kubectl CLI Control System

* **Local Container Engine:** Docker Daemon Platform (CloudShell Asset Layering)

## Architecture Diagram

## Project Procedure

### 1. Private Network Fabric & Compute Provisioning

I engineered a hardened Virtual Private Cloud (VPC) topology explicitly split across two separate Availability Zones to establish structural high availability.

* **Subnet Architecture Selection:** Defined two public entry subnets alongside two entirely isolated private subnets. The public zone hosts a single NAT Gateway instance mapped to a static Elastic IP address to act as the automated egress gateway.

* **Route Path Enforcement:** Updated the private route tables to map the 0.0.0.0/0 route target interface directly to the active NAT Gateway ID, guaranteeing that nodes sitting inside the private zone can cleanly reach external package registries or AWS API backbones while maintaining zero public ingress footprints.

* **Control Plane Formulation:** Provisioned the Amazon EKS cluster backbone using an IAM Control role. Configured the Cluster Endpoint Access parameters strictly to Public and Private, allowing client administration tools to reach the control plane over public networks while forcing internal instance communication to remain within the private subnet boundary.

* **Node Group Deployment:** Attached a managed node fleet named fortress-managed-workers containing two t3.medium instances. Linked the compute tier to the eks-worker-node-role containing core container runtime permissions and explicitly targeted only the private subnets during installation.

### 2. Zero-Trust Pod Identity Federation (IRSA)

To grant containers authorization to access external AWS data blocks without local token injection, I implemented IAM Roles for Service Accounts.

* **OIDC Identity Trust Mapping:** Extracted the unique OpenID Connect provider issuer URL from the EKS control plane overview window and instantiated a trusted OIDC Identity Provider entry inside the IAM management console, targeting the sts.amazonaws.com audience profile.

* **Granular Asset Scoping:** Compiled a customer-managed IAM permission document named AppS3ReadPolicy restricting actions strictly to s3:GetObject and s3:ListBucket operations targeting the secure enterprise asset vault.

* **Federated Trust Definition:** Formulated an AWS IAM role named eks-secure-app-s3-role utilizing a Web Identity trust policy. Configured a strict Condition block that explicitly restricts role assumption capability exclusively to the exact account identifier, OIDC provider ID, logical workspace namespace, and local ServiceAccount token name.

### 3. Client Context Alignment & Container Registry Seeding

I initiated an administrative console session inside AWS CloudShell to establish automated connectivity mappings and upload application components.

* **Kubeconfig Profile Injection:** Synchronized local command-line pathways directly with the active cluster API infrastructure using the AWS CLI configuration management engine:

```bash
aws eks update-kubeconfig --region us-east-1 --name kubernetes-fortress
```

* **Registry Authentication Handshake:** Requested an active security token from AWS IAM and cleanly piped the authorization output straight into the Docker daemon configuration engine to authenticate the terminal session against the private repository registry:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 418272769771.dkr.ecr.us-east-1.amazonaws.com
```

* **Image Asset Seeding:** Pulled a minimal base operating system layer, appended a custom repository tag matching the private ECR vault path precisely, and pushed the immutable code layers up onto the storage shelf:

```bash
docker pull alpine:latest
docker tag alpine:latest 418272769771.dkr.ecr.us-east-1.amazonaws.com/devsecops-secure-app:latest
docker push 418272769771.dkr.ecr.us-east-1.amazonaws.com/devsecops-secure-app:latest
```

### 4. Logical Workspace Segregation & Manifest Architecture

I utilized standard Heredoc terminal blocks to author and execute declarative manifest files, mitigating any risk of syntax indentation corruption during deployment.

* **Namespace Generation:** Formulated a clean logical partition inside the cluster map to isolate all project infrastructure entities from the default cluster workspace:

```bash
kubectl create namespace production-apps
```

* **Identity Manifest Authoring:** Wrote the local identity mapping profile to bind the private pod ecosystem to the secure AWS IAM role ARN:

```bash
cat <<EOF > service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-pod-sa
  namespace: production-apps
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::418272769771:role/eks-secure-app-s3-role"
EOF

kubectl apply -f service-account.yaml
```

* **Core Application Workload Delivery:** Engineered a Deployment manifest configuring two replica pods running our private ECR image layer. To ensure absolute process stability, I injected an explicit, continuous shell loop into the container command execution block:

```bash
cat <<EOF > app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fortress-secure-app
  namespace: production-apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-s3-worker
  template:
    metadata:
      labels:
        app: secure-s3-worker
    spec:
      serviceAccountName: secure-pod-sa
      containers:
      - name: app-worker
        image: 418272769771.dkr.ecr.us-east-1.amazonaws.com/devsecops-secure-app:latest
        command: ["/bin/sh", "-c", "while true; do echo 'Fortress Secure App Running'; sleep 10; done"]
        ports:
        - containerPort: 8080
EOF

kubectl apply -f app-deployment.yaml
```

## Technical Difficulties Faced & Engineering Resolutions

### Challenge 1: Asymmetric Routing Network Blackholes and Node Handshake Timeouts

During the structural environment rebuild phase, the core cluster node group continually logged a critical timeout error, shifting into a red Create failed status window after roughly 35 minutes of silent operation. The internal error message read: NodeCreationFailure: Instances failed to join the kubernetes cluster.

**The Root Cause Analysis:** While the newly generated public NAT Gateway was active and properly attached to the first private availability zone route table (private1-us-east-1a), the secondary availability zone route table (private2-us-east-1b) was pointing outbound 0.0.0.0/0 traffic toward an old, deleted NAT Gateway instance ID. This created an asymmetric network blackhole: EC2 computing hardware spawned successfully within the second subnet, but their automated startup bootstrap scripts were blocked from accessing the internet or routing health registration check-ins back to the EKS control plane API server.

**The Architectural Resolution:** I navigated directly to the VPC Route Tables menu, selected the misconfigured private2 table, selected Edit Routes, and explicitly re-mapped the 0.0.0.0/0 destination pathway to the active public NAT Gateway interface. This immediately re-established consistent outbound internet egress across all private availability zones, allowing subsequent node groups to complete their bootstrap phases and register cleanly with the control plane within minutes.

### Challenge 2: The Stateless Lifecycle Termination Loop (Completed Status)

Upon initial workload deployment, the cluster pods immediately skipped past image pulling but continuously failed to stay online. Running the live stream tracking tool showed that the workloads were exiting with a Completed status, causing the deployment controller to flag a status loop error and trigger a rapid exponential restart backoff.

**The Root Cause Analysis:** Because the private container image warehouse was seeded with a bare-bones, highly optimized Alpine Linux core, the container lacked a native, long-running foreground daemon or listener process (such as an active web server or database engine). In standard Kubernetes process management, if the root execution process (PID 1) finishes its execution stack and exits successfully with code 0, the cluster engine assumes the application container has concluded its runtime lifecycle. The deployment controller immediately destroys the container and boots a replacement instance to satisfy the configured replica counts, causing an infinite loop.

**The Architectural Resolution:** I modified the container configuration profile inside the declarative app-deployment.yaml manifest by injecting an explicit, infinite shell execution block wrapper: command: ["/bin/sh", "-c", "while true; do echo 'Fortress Secure App Running'; sleep 10; done"]. This command forces the container instance to continuously execute an active task, generating lightweight text telemetry lines to stdout while keeping the underlying process permanently alive and perfectly stable at a 1/1 Running metric.

### Challenge 3: Client Context API Disconnection (localhost:8080 Connection Refused)

Following the structural teardown of the initial broken infrastructure environments, running administrative management commands such as kubectl get nodes resulted in a terminal failure message stating: The connection to the server localhost:8080 was refused - did you specify the right host or port?

**The Root Cause Analysis:** The local terminal client tool utilizes a secure mapping configuration database file located at ~/.kube/config to track active cryptographic cluster endpoint paths. Because the entire cluster had been deleted and built anew from a clean slate, the client tool was missing a valid server target profile map. When kubectl cannot detect an explicit cluster target endpoint signature inside its config paths, it defaults back to querying the local hosting terminal environment (127.0.0.1:8080), where no active Kubernetes control services exist.

**The Architectural Resolution:** I executed the AWS EKS deployment command engine aws eks update-kubeconfig --region us-east-1 --name kubernetes-fortress inside the CloudShell window. This command successfully queried the AWS metadata service, generated fresh security credentials, and securely wrote the accurate, newly active EKS control plane API endpoint address directly into the local kubeconfig config file, immediately restoring client control command authority over the infrastructure workspace.

## Verification and Results

### Verified Clean Compute Node Join

Queried the live cluster control plane engine from the command line following the route table alignment. The API server responded proudly with active virtual machines showing a completely stable, healthy Ready status flag, proving the network handshake successfully bypassed all old timeout barriers.

### Validated Image Ingestion from ECR Vault

Inspected the private image management shelf after executing the CloudShell Docker push commands. The registry ledger accurately logged the ingestion of the application layers, confirming flawless authentication and zero network blockages along the ECR ingestion path.

### Confirmed Zero-Trust IRSA Authorization

Inspected the updated IAM Federated trust relationships screen to verify the configuration of the web identity provider conditions. The role securely mapped access parameters to the precise production-apps namespace and secure-pod-sa ServiceAccount identity, enforcing complete zero-trust access control.

### Validated Continuous Pod Workload Stability

Executed the live infrastructure log tracking engine to verify process behavior following the addition of the infinite background task command. The tracking engine returned a rock-solid, permanent 1/1 Running status with exactly 0 Restarts, validating absolute deployment stability across all configured replica tiers.

## Verification Screenshots

### 1. EKS Cluster Configuration with Isolated Private Subnets

Screenshots of EKS Cluster Configuration Showing Only Private Subnets Attached:

<img width="1572" height="712" alt="Screenshot 1" src="https://github.com/user-attachments/assets/6cdb9816-00da-4eaf-9bd5-5e3548d3f88e" />
<img width="1627" height="578" alt="Screenshot 2" src="https://github.com/user-attachments/assets/bc8e1a3e-0701-445d-a3b8-66f9a87c3cfd" />
<img width="1623" height="577" alt="Screenshot 3" src="https://github.com/user-attachments/assets/6b53813f-eb6e-47a1-803c-d64098e314da" />


### 2. VPC Private Route Tables with Active NAT Gateway Target

Screenshots of VPC Route Tables Showing 0.0.0.0/0 Routed to Active NAT Gateway:
<img width="1642" height="726" alt="Screenshot 4" src="https://github.com/user-attachments/assets/67afbc7a-4499-4ae9-a387-e9eb6ff7112e" />
<img width="1651" height="724" alt="Screenshot 5" src="https://github.com/user-attachments/assets/a4509676-71ef-4536-aaca-b9f7bf57bed3" />


### 3. Amazon ECR Registry with Successfully Pushed Image Layer

Screenshot of Amazon ECR Registry Repository Displaying Pushed Image Tag:
<img width="1462" height="456" alt="Screenshot 6" src="https://github.com/user-attachments/assets/fa27dc7f-837b-4910-80bf-18c9fc6a21bb" />


### 4. Kubectl Terminal Displaying Flawless 1/1 Running Pods

Screenshot of CloudShell Terminal Output Confirming 1/1 Running Pod Workloads:
<img width="841" height="248" alt="Screenshot 7" src="https://github.com/user-attachments/assets/97fb2ae2-c5d4-4d78-93fe-ae1a409477e2" />


## Future Improvements

* **Horizontal Pod Autoscaling Integration:** Deploy a native Kubernetes Metrics Server wrapper into the cluster framework to automatically scale pod replica sets up and down dynamically based on live CPU and memory utilization thresholds.

* **Ingress Controller and TLS Termination:** Configure an external AWS Load Balancer Controller linked to a secure NGINX Ingress system to safely expose application routes via TLS encrypted endpoints using Amazon Certificate Manager.

* **Automated GitOps Continuous Delivery:** Integrate a GitOps orchestration framework like ArgoCD to track a private Git code structure repository, automatically synchronizing manifest layout changes to the live cluster workspace with zero human manual intervention.

## Notes

This project demonstrates an end-to-end operational framework for establishing a highly isolated, cryptographically secure container orchestration tier within public cloud ecosystems. It showcases deep infrastructure competencies in mitigating network routing blackholes, configuring precise web identity federated trust relationships (IRSA), managing image asset ingestion layers, and engineering workload container scripts to maintain permanent, self-healing process stability without relying on legacy hardcoded credentials.

**Bottom Line:** The Kubernetes Fortress project transitions modern container orchestration deployments into an airtight, zero-trust infrastructure ecosystem. By isolating the compute worker fleet entirely within private network lanes, routing outbound data packages through a single NAT Gateway, utilizing AWS OIDC federation to dynamically authorize pod identities without static keys, and injecting custom shell loops to ensure continuous process persistence, the architecture delivers comprehensive cloud supply chain protection with absolute runtime stability.
