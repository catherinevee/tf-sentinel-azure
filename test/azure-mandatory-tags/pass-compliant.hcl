mock "tfplan/v2" {
  module {
    source = "./mock-pass-compliant.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}
