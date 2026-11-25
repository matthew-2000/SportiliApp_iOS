#!/bin/sh
# Xcode Cloud discovers this hook automatically. All assertions use local doubles.
set -eu
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"

for runner in \
  run_model_tests.py \
  run_lifecycle_tests.py \
  run_note_tests.py \
  run_image_loader_tests.py \
  run_s05_tests.py \
  run_weight_session_tests.py \
  run_watch_sync_tests.py \
  run_watch_transport_tests.py
do
  printf '\nRunning %s\n' "$runner"
  python3 "Tests/$runner"
done
