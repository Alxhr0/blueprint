kind: stack
description: |
  Seed for a future libc-free static tier. NOT libc-free today.

  The intent is CA certificates and timezone data only, for statically
  compiled binaries (Go with CGO_ENABLED=0), mirroring
  gcr.io/distroless/static. That is NOT what this builds: depending on
  runtime-gnu.bst pulls in full glibc, so the resulting image ships 88
  shared objects and is a byte-near-duplicate of `base`. See issue 116.

depends:
  - freedesktop-sdk.bst:public-stacks/runtime-gnu.bst
  - freedesktop-sdk.bst:components/ca-certificates.bst
  - freedesktop-sdk.bst:components/tzdata.bst
  - freedesktop-sdk.bst:components/os-release.bst
  - freedesktop-sdk.bst:integration/extra-fs.bst
