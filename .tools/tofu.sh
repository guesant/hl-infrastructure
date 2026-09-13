#!/usr/bin/env bash
set -euo pipefail

# IMPORTANT: no OpenTofu root module exists yet in this repository; this
# script only wires the Docker-based tofu binary so a real module can call
# it later, without duplicating the docker invocation at that point.
exec tofu "$@"
