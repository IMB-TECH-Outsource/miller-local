#!/bin/bash
set -euo pipefail

dir="$1"
repo="$2"
branch="$3"

if [ ! -d "${dir}/.git" ]; then
  echo "Cloning ${repo} (${branch}) into ${dir}"
  git clone --branch "${branch}" "${repo}" "${dir}"
  exit 0
fi

if [ -n "$(git -C "${dir}" status --porcelain --untracked-files=no)" ]; then
  echo "${dir}: local changes found, pull skipped."
  exit 0
fi

echo "Updating ${dir} (${branch})"
git -C "${dir}" fetch origin "${branch}"
git -C "${dir}" checkout "${branch}"
git -C "${dir}" pull --ff-only origin "${branch}"
