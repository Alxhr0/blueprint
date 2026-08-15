kind: stack
description: |
  Unified FSDK development image: base + python + static + buildah + skopeo.
  Composed from all fsdk-containers tiers into a single image.

depends:
  - base/base-stack.bst
  - python/python-stack.bst
  - static/static-stack.bst
  - buildah/buildah-stack.bst
  - skopeo/skopeo-stack.bst
