package novapay.compliance

# Policy: Encryption compliance gate
# RBI Mapping: Section 5.4 (Encryption of data in transit and at rest)
# PCI-DSS Mapping: Requirement 6.2

# Allowed TLS versions
allowed_tls_versions := {"TLS1.2", "TLS1.3"}

# Weak ciphers that must not be used
blocked_ciphers := {
  "RC4", "DES", "3DES", "MD5", "SHA1",
  "NULL", "EXPORT", "anon"
}

# Weak encryption algorithms for data at rest
blocked_algorithms := {"MD5", "SHA1", "DES", "3DES", "RC4", "Blowfish"}

# Gate: TLS version must be 1.2 or 1.3
deny[msg] {
  config := input.tls_config
  not allowed_tls_versions[config.min_version]
  msg := sprintf("NOVAPAY-ENC-001: TLS minimum version '%v' not allowed. Must be TLS 1.2 or 1.3. RBI 5.4.", [
    config.min_version
  ])
}

# Gate: No weak ciphers in TLS configuration
deny[msg] {
  cipher := input.tls_config.cipher_suites[_]
  blocked_ciphers[_] == cipher
  msg := sprintf("NOVAPAY-ENC-002: Weak cipher '%v' detected in TLS config. RBI 5.4.", [cipher])
}

# Gate: No weak encryption for data at rest
deny[msg] {
  algo := input.encryption_config.algorithm
  blocked_algorithms[_] == algo
  msg := sprintf("NOVAPAY-ENC-003: Weak encryption algorithm '%v' for data at rest. Use AES-256. RBI 5.4.", [algo])
}

# Gate: All compliance gates must pass
all_gates_pass {
  count(deny) == 0
}
