kind: stack
description: |
  Unified FSDK development image: base runtime + Python + Skopeo + Buildah + OSTree.
  Composed from all individual stacks into a single image.

depends:
  - base/base-stack.bst
  - freedesktop-sdk.bst:components/python3.bst
  - freedesktop-sdk.bst:components/skopeo.bst
  - freedesktop-sdk.bst:components/buildah.bst
  - freedesktop-sdk.bst:components/containers-common.bst
  - freedesktop-sdk.bst:components/gpgme.bst
  - freedesktop-sdk.bst:components/libassuan.bst
  - freedesktop-sdk.bst:components/sqlite.bst
  - freedesktop-sdk.bst:components/libgpg-error.bst
  - freedesktop-sdk.bst:components/libseccomp.bst
  - freedesktop-sdk.bst:components/glib.bst
  - freedesktop-sdk.bst:components/pkg-config.bst
  - freedesktop-sdk.bst:components/ostree.bst
