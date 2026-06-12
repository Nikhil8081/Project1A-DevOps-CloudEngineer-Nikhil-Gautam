package novapay.kubernetes

# Policy: No privileged containers
# RBI Mapping: Section 4.3 (Segregation of duties / access control)
# PCI-DSS Mapping: Requirement 6.5

deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("NOVAPAY-K8S-001: Privileged container not allowed in pod '%v', container '%v'. RBI 4.3.", [
    input.request.object.metadata.name,
    container.name
  ])
}

# Policy: Memory limits required
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("NOVAPAY-K8S-002: Memory limit required for container '%v' in pod '%v'.", [
    container.name,
    input.request.object.metadata.name
  ])
}

# Policy: CPU limits required
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("NOVAPAY-K8S-003: CPU limit required for container '%v' in pod '%v'.", [
    container.name,
    input.request.object.metadata.name
  ])
}

# Policy: No latest image tag
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("NOVAPAY-K8S-004: 'latest' tag not permitted in production. Container '%v' uses '%v'.", [
    container.name,
    container.image
  ])
}

# Policy: Containers must run as non-root
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := sprintf("NOVAPAY-K8S-005: Container '%v' must set runAsNonRoot: true.", [container.name])
}

# Policy: Read-only root filesystem required
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  msg := sprintf("NOVAPAY-K8S-006: Container '%v' must use readOnlyRootFilesystem: true.", [container.name])
}

# Policy: Image must be from approved registry only
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not startswith(container.image, "novapay.jfrog.io/")
  msg := sprintf("NOVAPAY-K8S-007: Container '%v' image '%v' must be from approved registry 'novapay.jfrog.io'.", [
    container.name,
    container.image
  ])
}
