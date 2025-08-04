mock "tfplan/v2" {
  module {
    source = "./mock-edge-case-computed.sentinel"
  }
}

mock "tfrun" {
  module {
    source = "./mock-tfrun-dev.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}
