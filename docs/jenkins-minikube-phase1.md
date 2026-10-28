# Jenkins inside Minikube: Phase 1 Setup Note

Status: Jenkins controller is running inside Minikube. Kubernetes dynamic-agent configuration is installed, but the dynamic-agent execution test is still pending.

## Objective

Run Jenkins and its temporary build agents inside the same local Minikube cluster. This avoids the Docker-host-to-Minikube-pod callback problem encountered when Jenkins ran outside Kubernetes.

Target topology:

```text
GitHub / repository
        |
        v
Jenkins controller pod (namespace: jenkins)
        |
        +--> Kubernetes API (`https://kubernetes.default`)
        |
        +--> temporary Jenkins agent pods
```

The controller is persistent. Agent pods are ephemeral: Jenkins creates them when a pipeline requests an agent and removes them after the build.

## What was done

### 1. Local Kubernetes baseline

- Used the existing Minikube profile named `minikube`.
- Verified the Minikube Kubernetes node was healthy and `Ready`.
- Confirmed local experiments use the `minikube` Kubernetes context, not the production EKS context.
- Minikube Kubernetes version used during this setup: `v1.34.0`.

Useful checks:

```bash
kubectl config current-context
kubectl get nodes -o wide
minikube status
```

Expected context:

```text
minikube
```

### 2. Jenkins Helm repository

Added the Jenkins chart repository and refreshed chart metadata:

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
```

The official Jenkins Helm chart was used instead of maintaining a separate controller Deployment for this proof of concept.

### 3. Jenkins values file

Created:

```text
jenkins/values-minikube.yaml
```

Important settings:

```yaml
controller:
  serviceType: NodePort
  nodePort: 32080
  agentListenerServiceType: ClusterIP

persistence:
  enabled: true
  size: 8Gi

rbac:
  create: true

serviceAccount:
  create: true

serviceAccountAgent:
  create: true

agent:
  jenkinsUrl: http://jenkins:8080
  jenkinsTunnel: jenkins-agent:50000
```

Meaning:

- `NodePort 32080`: exposes the Jenkins web UI through the Minikube node.
- `8Gi PVC`: keeps Jenkins configuration, jobs, plugins, and credentials across pod restarts.
- `rbac.create`: creates the permissions needed by the Jenkins Kubernetes integration.
- `serviceAccountAgent`: gives temporary agent pods a service account.
- `jenkinsUrl`: the in-cluster URL used by agents to reach the controller.
- `jenkinsTunnel`: the in-cluster service and port used for Jenkins agent communication.

### 4. Jenkins plugins

The Helm values request these plugins:

```text
kubernetes
workflow-aggregator
git
configuration-as-code
```

The important plugin for this phase is `kubernetes`. It provides the Jenkins cloud integration that creates temporary Kubernetes agent pods.

### 5. Render validation

Rendered the chart before installation:

```bash
helm template jenkins jenkinsci/jenkins \
  -n jenkins \
  -f jenkins/values-minikube.yaml
```

The rendered output contained the expected StatefulSet, Services, PVC, and service accounts.

### 6. Jenkins installation

Installed Jenkins into its own namespace:

```bash
helm upgrade --install jenkins jenkinsci/jenkins \
  -n jenkins \
  --create-namespace \
  -f jenkins/values-minikube.yaml \
  --wait \
  --timeout 10m
```

Observed Helm result:

```text
Release: jenkins
Namespace: jenkins
Status: deployed
Revision: 1
```

### 7. Runtime verification

Verified the controller and services:

```bash
kubectl get pods -n jenkins -o wide
kubectl get svc -n jenkins
kubectl get pvc -n jenkins
```

Current expected resources:

```text
jenkins-0       2/2   Running
jenkins         NodePort    8080:32080/TCP
jenkins-agent   ClusterIP   50000/TCP
jenkins PVC     Bound       8Gi
```

Jenkins URL for this Minikube profile:

```text
http://192.168.58.2:32080
```

It can also be obtained without assuming the node IP:

```bash
minikube service jenkins -n jenkins --url
```

## How dynamic agents work

The `jenkins-0` pod is the controller. It is not the build agent.

No agent pod is created merely because the Kubernetes plugin is installed. A pipeline must request a Kubernetes agent. During a build, the sequence is:

```text
1. Jenkins receives a pipeline build.
2. Pipeline requests a Kubernetes pod template.
3. Jenkins uses the Kubernetes API to create a temporary pod.
4. The pod starts a Jenkins inbound agent container.
5. Jenkins schedules build steps on that pod.
6. The build completes or fails.
7. Jenkins deletes the temporary agent pod.
```

Therefore, seeing only `jenkins-0` before running an agent-backed pipeline is expected.

## Remaining Phase 1 test

Create a temporary Pipeline job in Jenkins using this smoke-test pipeline:

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: shell
    image: alpine:3.20
    command:
    - sleep
    args:
    - 99d
'''
            defaultContainer 'shell'
        }
    }

    stages {
        stage('Dynamic agent test') {
            steps {
                sh 'hostname'
                sh 'uname -a'
                sh 'cat /etc/os-release'
            }
        }
    }
}
```

While the build is running, verify the temporary pod:

```bash
kubectl get pods -n jenkins -w
```

Expected pattern:

```text
jenkins-0                    2/2   Running
<generated-agent-name>       1/1   Running
```

After the build finishes, verify cleanup:

```bash
kubectl get pods -n jenkins
```

The generated agent pod should no longer be present after Jenkins applies its pod-retention cleanup.

## Phase 1 acceptance criteria

Phase 1 is complete when all of these are verified:

- [x] Minikube is healthy.
- [x] Jenkins controller runs inside Minikube.
- [x] Jenkins web UI is reachable.
- [x] Jenkins controller has persistent storage.
- [x] Kubernetes plugin is installed.
- [x] Jenkins Kubernetes cloud configuration points to the in-cluster API and services.
- [x] Agent listener Service exists on port `50000`.
- [ ] A pipeline creates a temporary Kubernetes agent pod.
- [ ] Build steps execute inside the temporary agent pod.
- [ ] The temporary agent pod is removed after the build.

## Deliberately not included yet

These are later phases, not prerequisites for the Phase 1 agent test:

- GitHub webhook and Multibranch Pipeline configuration.
- Feature branch naming and PR environment namespaces.
- Helm deployment of the application.
- Image registry integration.
- Staging database dump and restore automation.
- Production or staging kubeconfig credentials.
- Preview ingress and public feature URLs.
- Automated cleanup triggered by PR closure.

## Important safety notes

- Do not run local commands while the current Kubernetes context points to production.
- Do not delete the existing Docker Jenkins controller or its volume without explicit approval.
- Do not commit Jenkins passwords, kubeconfigs, tokens, or other credentials.
- The local Jenkins instance is for development and proof of concept, not production use.
