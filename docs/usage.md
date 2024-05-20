# Usage

Understand how to plan, install and operate Semgr8s.

## Considerations

Before integrating Semgr8s, it is important to bear a few considerations in mind:

* Semgr8s is still in an early stage of development with exciting ideas for improvement :rocket:
* There is only limited operational experience so far and there might be breaking changes. We are happy for any feedback, bug reports, feature requests, and contributions via [GitHub discussions](https://github.com/sse-secure-systems/semgr8s/discussions),  [issues](https://github.com/sse-secure-systems/semgr8s/issues) and PRs :pray:
* Semgrep's *yaml* support is currently [experimental](https://semgrep.dev/docs/supported-languages#semgrep-code-language-support).
* Semgr8s (like any other Kubernetes admission controller) can break a cluster when misconfigured. Therefore, testing should be rigorous and happen on a dedicated test cluster.
* Semgr8s can be used with remote rules. Those introduce an external dependence for validation which can affect performance and availability.
* Kubernetes admission controllers have [maximum timeout of 30s](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#timeouts) which can require special attention for large deployments.

## Setup

Semgr8s is installed via *Helm*, but instructions can be adapted for usage with `kubectl apply` or your method of choice.

### Requirements

- [git](https://git-scm.com/)
- Kubernetes cluster for testing (e.g. [kind](https://kind.sigs.k8s.io/), [microk8s](https://microk8s.io/docs), or [minikube](https://minikube.sigs.k8s.io/docs/start/))
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Helm](https://helm.sh/)
- *(optional)* [make](https://www.gnu.org/software/make/) (e.g. via [build-essential](https://packages.ubuntu.com/focal/build-essential))
- (optional) [yq v4.x](https://mikefarah.gitbook.io/yq/)
- *(optional)* [docker](https://docs.docker.com/get-docker/)

### Get Code

The Helm charts are contained within the Semgr8s repository:

```bash
git clone https://github.com/sse-secure-systems/semgr8s.git
cd semgr8s
```

### Configuration

Semgr8s comes preconfigured with some basic rules.
However, configuration can be adjusted to your needs.
Central configuration is maintained in `charts/semgr8s/values.yaml`:

??? abstract "`values.yaml` chart"

    ```yaml title="charts/semgr8s/values.yaml"
    --8<-- "charts/semgr8s/values.yaml"
    ```

Configuration aims to provide the most native integration of Semgrep's functionality into Kubernetes.
Working knowledge of Kubernetes and the [Semgrep documentation](https://semgrep.dev/docs/) should be sufficient to understand the concepts and options being used. In `charts/semgr8s/values.yaml`:

* `.deployment` and `.service` only affect the Semgr8s deployment itself.
* `.webhooks` allows configuration of validation scope (resources, operations, ...).
* `.application` provides application-specific configuration (features, remote rules).

!!! tip

    Use `.webhooks` to configure the overall Semgr8s scope.
    In production, this should be a careful trade-off between desired policy scope, availability, performance, and security.

Rules form the basis to construct your policy.
It is possible to either reference remote rules or add custom rules locally.
[Remote Semgrep](https://registry.semgrep.dev/rule) rules, rulesets, or [repository rules](https://github.com/returntocorp/semgrep-rules) are configured via `.application.remoteRules` in `charts/semgr8s/values.yaml`, e.g. set to `"r/yaml.kubernetes.security.allow-privilege-escalation.allow-privilege-escalation"` or `"p/kubernetes"`, or `"r/yaml.kubernetes"` respectively.
[Custom Semgrep rules](#writing-rules) can be placed in `charts/semgr8s/rules/` and will be auto-mounted into the admission controller or [added later as configmaps](#adding-local-rules).
Additional information on rule creation and management is shared [below](#rules).
Some useful example rules are provided under `./rules/`.

At present, Semgr8s is shipped with one local test rule detecting a unique label and Semgrep's `p/kubernetes` ruleset.

### Installation

To deploy the preconfigured admission controller simply run:

```bash
helm install semgr8s charts/semgr8s --create-namespace --namespace semgr8ns
```
<details>
  <summary>output</summary>
  
  ```bash
  NAME: semgr8s
  LAST DEPLOYED: Tue Apr 25 00:16:04 2023
  NAMESPACE: semgr8ns
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  NOTES:
  Successfully installed semgr8s!
  ```
</details>

You can check successful deployment of semgr8s via:

```bash
kubectl get all -n semgr8ns
```
<details>
  <summary>output</summary>
  
  ```bash
  NAME                           READY   STATUS    RESTARTS   AGE
  pod/semgr8s-665dbb8756-qhqv6   1/1     Running   0          7s

  NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
  service/semgr8s-service   ClusterIP   10.96.135.157   <none>        443/TCP   7s

  NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/semgr8s   1/1     1            1           7s

  NAME                                 DESIRED   CURRENT   READY   AGE
  replicaset.apps/semgr8s-665dbb8756   1         1         1       7s
  ```
</details>

Once all resources are in `READY` state, you have successfully installed Semgr8s.

### Enable namespaces

To activate Semgr8s admission control for a namespace in default configuration, it is required to set the label `semgr8s/validation=enabled`.
Either update the labels for existing namespaces directly via `kubectl`:

```bash
kubectl label namespace test-semgr8s semgr8s/validation=enabled --overwrite
```

Or extend the Kubernetes yaml files for target namespaces:

```yaml title="namespace.yaml" hl_lines="6-7"
--8<-- "tests/demo/00_test-namespace.yaml"
```

It is recommended to exclude cluster operation critical namespaces such `kube-system` to avoid interruptions.

### Testing

Several test resources are provided under `tests/demo/`.
Semgr8s only validates resources in namespaces with label `semgr8s/validation=enabled`:

```bash
kubectl apply -f tests/demo/00_test-namespace.yaml
```
<details>
  <summary>output</summary>
  
  ```bash
  namespace/test-semgr8s created
  ```
</details>

It denies creating pods with non-compliant configuration according to the local rules in `charts/semgr8s/rules` and `.application.remoteRules`  `charts/semgr8s/values.yaml`:

```bash
kubectl apply -f tests/demo/40_failing-deployment.yaml
```
<details>
  <summary>output</summary>
  
  ```bash
  Error from server: error when creating "tests/demo/40_failing-deployment.yaml": admission webhook "semgr8s-svc.semgr8ns.svc" denied the request: Found 1 violation(s) of the following policies: 
  * rules.test-semgr8s-forbidden-label
  Error from server: error when creating "tests/demo/40_failing-deployment.yaml": admission webhook "semgr8s-svc.semgr8ns.svc" denied the request: Found 1 violation(s) of the following policies: 
  * yaml.kubernetes.security.writable-filesystem-container.writable-filesystem-container
  Error from server: error when creating "tests/demo/40_failing-deployment.yaml": admission webhook "semgr8s-svc.semgr8ns.svc" denied the request: Found 1 violation(s) of the following policies: 
  * yaml.kubernetes.security.privileged-container.privileged-container
  Error from server: error when creating "tests/demo/40_failing-deployment.yaml": admission webhook "semgr8s-svc.semgr8ns.svc" denied the request: Found 1 violation(s) of the following policies: 
  * yaml.kubernetes.security.hostnetwork-pod.hostnetwork-pod
  ```
</details>

Compliantly configured resources on the other hand are permitted to the cluster:

```bash
kubectl apply -f tests/demo/20_passing-deployment.yaml
```
<details>
  <summary>output</summary>
  
  ```bash
  pod/passing-testpod-1 created
  ```
</details>


### Cleanup

To remove all resources of the admission controller run:

```bash
helm uninstall semgr8s -n semgr8ns
kubectl delete ns semgr8ns
```
<details>
  <summary>output</summary>
  
  ```bash
  release "semgr8s" uninstalled
  ```
</details>

Test resources are deleted via:

```bash
kubectl delete -f tests/demo/
```
<details>
  <summary>output</summary>
  
  ```bash
  namespace "test-semgr8s" deleted
  pod "passing-testpod-1" deleted
  Error from server (NotFound): error when deleting "tests/demo/40_failing-deployment.yaml": pods "forbiddenlabel-pod" not found
  Error from server (NotFound): error when deleting "tests/demo/40_failing-deployment.yaml": pods "failing-testpod-1" not found
  Error from server (NotFound): error when deleting "tests/demo/40_failing-deployment.yaml": pods "failing-testpod-2" not found
  Error from server (NotFound): error when deleting "tests/demo/40_failing-deployment.yaml": pods "failing-testpod-3" not found

  ```
</details>

## Features

### Autofix

Semgr8s supports the Semgrep [autofix feature](https://semgrep.dev/docs/writing-rules/autofix/).
To use autofix, simply set `.application.autofix=true` in the `charts/semgr8s/values.yaml` before installation and provide `fix` instructions for your rules.
Semgr8s will attempt to fix resources before validation.

Technically, this is implemented via an additional mutating admission controller that is called before the validating admission controller.

## Rules

Rules form the core of Semgr8s functionality.
They follow [Semgrep syntax](https://semgrep.dev/docs/writing-rules/overview) that provides an extensive pattern language.
As admission requests resemble Kubernetes manifests, standard Kubernetes patterns can be directly used for Semgr8s.
It is however important to keep [some differences](./concept.md/#admission-requests) in mind.
Rules can be provided in two different ways: remote rules and local rules.
Remote rules are directly implemented from their external sources such the [Semgrep registry](https://semgrep.dev/r).
Local rules are provided as configmaps directly to Semgr8s.

### Remote rules

Remote rules are directly used from external sources.
They can be individual rules (e.g. `r/yaml.kubernetes.security.allow-privilege-escalation.allow-privilege-escalation`) or entire rulesets (e.g. `p/kubernetes`).
Common sources are:

* [Semgrep registry](https://semgrep.dev/r)
* [Semgrep registry repository](https://github.com/semgrep/semgrep-rules/)

For inspiration checkout Semgreps [Kubernetes ruleset](https://semgrep.dev/p/kubernetes) or the [Kubernetes repository folder](https://github.com/semgrep/semgrep-rules/tree/develop/yaml/kubernetes).
They are added as a list under `.application.remoteRules` `charts/semgr8s/values.yaml`.
Simply reference the respective rule(set) as you would for a local installation, e.g. `p/kubernetes`.
Remote rules can currently only be configured prior to deployment and changes require re-installation of Semgr8s.

!!! warning
    Remote rules require requests to external resources.
    This introduces delays, may lead to unexpected denial for rules modified by the external authority, and can cause failures if these resources become unavailable.

### Local rules

Local rules are your custom written rules and added as configmaps with label `semgr8s/rule=true` to Semgr8s's namespace `semgr8ns`.
They can either be provided prior to installation as files under `charts/semgr8s/rules/` or added after deployment.
Templates and selected rules are available under [`./rules/`](https://github.com/sse-secure-systems/semgr8s/tree/main/rules).

!!! tip "Share your own rules :writing_hand:"
    We hope to continuously extend the list of selected rules to facilitate policy creation.
    So, please contribute your own favorite rules via PR :pray:

#### Adding local rules

Local rules are provided as configmaps that are frequently mapped as files into the semgr8s pod.
Therefore, adding, modifying, or deleting local rules does not require an update of the deployment.

To add a new rule, simply create a configmap from a standard semgrep rule yaml file and add the label `semgr8s/rule=true`:
```bash
kubectl create configmap -n semgr8ns my-local-rule --from-file=path/to/rule.yaml
kubectl label configmap -n semgr8ns my-local-rule semgr8s/rule=true
```
!!! info
    Semgr8s only updates its rules every 1min.
    Consequently, it can take up to 1min until the changes take effect.
    This accounts for adding, modifying, and deleting local rules.

To delete the rule again, run:
```bash
kubectl delete configmap -n semgr8ns my-local-rule
```

#### Writing rules

Semgr8s rules follow [Semgrep syntax](https://semgrep.dev/docs/writing-rules/rule-syntax/) and, therefore, must comply with the Semgrep [rule requirements](https://semgrep.dev/docs/writing-rules/rule-syntax/#required).
For convenience, admission requests converted to yaml and consequently all rules should define yaml as language.
A basic rule takes the form:

```yaml title="rules/template-rule.yaml"
--8<-- "rules/template-rule.yaml"
```

In order to use the autofix feature, a fix value must be specified additionally:

```yaml title="rules/template-autofix-rule.yaml"
--8<-- "rules/template-autofix-rule.yaml"
```

While admission requests purposely share similarities with Kubernetes resource files, there is critical differences and additional information to consider when writing semgr8s rules.
More details on admission requests are provided in the [respective conceptual section](./concept.md#admission-requests).
Rules should be carefully tested before rollout to production.

!!! tip
    Semgrep provides provides [extensive learning resources](https://semgrep.dev/docs/writing-rules/overview/) for writing your own rules.
    Interactive development without local setup is supported via the [online playground](https://semgrep.dev/playground/).

#### Testing rules

Semgrep provides some convenient [testing mechanisms](https://semgrep.dev/docs/writing-rules/testing-rules/) out of the box.
These can be leveraged to test rules locally before deployment.
To validate rule syntax, Semgrep offers linting patterns:

```bash
semgrep scan --metrics-off --validate ./rules/
```

Testing functionality of rules requires tests.
To assess the example rules, run:

```bash
semgrep scan --metrics=off --test ./rules/
```

#### Typical patterns

##### Restrict to resource type

In order to restrict a rule to only certain resource types, simply prepend a `pattern-inside` expression for the desired resource type.
In case of `Pod` resources, this takes the following form:

```yaml title="rules/forbidden-pod-label.yaml" hl_lines="7-10"
--8<-- "rules/forbidden-pod-label.yaml"
```

It is also possible to use `pattern-not-inside` to only exclude a rule for one specific resource type.
Multiple in-scope resource types can be defined via metavariable regular expressions:


```yaml title="rules/forbidden-workload-label.yaml" hl_lines="7-13"
--8<-- "rules/forbidden-workload-label.yaml"
```

##### Restrict to specific namespaces

By prepending a `pattern-inside`, it is possible to restrict a rule to selected namespaces:

```yaml title="rules/forbidden-namespaced-label.yaml" hl_lines="7-14"
--8<-- "rules/forbidden-namespaced-label.yaml"
```

This cannot extend beyond the [enabled namespaces](#enable-namespaces), but allows for more granular control on a per rule basis.

#### Delete all local rules

```bash
kubectl delete -n semgr8ns cm -l semgr8s/rule=true
```