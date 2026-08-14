#!/bin/bash

set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

"$root/tests/static.sh"
"$root/tests/behavior.sh"
