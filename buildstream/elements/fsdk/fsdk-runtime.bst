kind: compose
description: |
  Chisel the FSDK stack down to runtime-only for a unified dev image.
  Shells are intentionally kept — this is a developer image, not distroless.

build-depends:
  - fsdk/fsdk-stack.bst

config:
  exclude:
    - debug
    - devel
    - doc
    - locale
    - static-blocklist
    - vm-only
    - tests
