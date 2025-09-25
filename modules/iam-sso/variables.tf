variable "permission_boundary_policy_json" {
  type = string
}

variable "sso_permission_sets" {
  description = "List of SSO permission sets (name → policy ARNs)."
  type = list(object({
    name             = string
    managed_policies = list(string)
    session_duration = optional(string, "PT8H")
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
