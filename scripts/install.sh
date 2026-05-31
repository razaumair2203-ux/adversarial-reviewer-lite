#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="adversarial-reviewer-lite"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/skills/${SKILL_NAME}"
SKILLS_ROOT="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"
DEST_DIR="${SKILLS_ROOT}/${SKILL_NAME}"

if [ ! -f "${SOURCE_DIR}/SKILL.md" ]; then
  echo "Could not find ${SOURCE_DIR}/SKILL.md"
  echo "Run this script from a complete adversarial-reviewer-lite checkout."
  exit 1
fi

mkdir -p "${DEST_DIR}"

case "${DEST_DIR}" in
  */"${SKILL_NAME}") ;;
  *)
    echo "Refusing to install: destination does not end with ${SKILL_NAME}: ${DEST_DIR}"
    exit 1
    ;;
esac

if [ -d "${DEST_DIR}" ]; then
  rm -rf "${DEST_DIR}"
fi

mkdir -p "${DEST_DIR}"
cp -R "${SOURCE_DIR}/." "${DEST_DIR}/"

if [ ! -f "${DEST_DIR}/SKILL.md" ]; then
  echo "Install failed: ${DEST_DIR}/SKILL.md was not created."
  exit 1
fi

echo "Installed ${SKILL_NAME} to:"
echo "${DEST_DIR}"
echo ""
echo "Restart Claude Code if it was already open, then run:"
echo "/adversarial-reviewer-lite audit"
echo ""
echo "Optional habit reminder:"
echo "Copy snippets/claude-md-reminder.md into your project's CLAUDE.md."
