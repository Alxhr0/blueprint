#!/usr/bin/env bash
set -xeuo pipefail

dnf clean all

bootc container lint --fatal-warnings
