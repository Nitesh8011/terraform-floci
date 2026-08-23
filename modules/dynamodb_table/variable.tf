variable "module_table_names" {
  type = list(string)
  #   default = ["module-table-1", "module-table-2", "module-table-3"]
}

variable "module_billing_mode" {
  type = string
}

variable "module_region" {
  type = string
}