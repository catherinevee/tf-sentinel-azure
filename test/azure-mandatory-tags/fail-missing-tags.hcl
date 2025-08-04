mock "tfplan/v2" {
  module {
    source = "./mock-fail-missing-tags.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
