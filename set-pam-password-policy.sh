#!/usr/bin/env bash
set -euo pipefail

# set-pam-password-policy.sh
# Idempotent script to configure PAM password quality on Ubuntu.
# - makes backups of files it modifies
# - ensures libpam-pwquality is installed
# - writes /etc/security/pwquality.conf
# - updates /etc/pam.d/common-password to include pam_pwquality.so

# Usage: sudo /path/to/set-pam-password-policy.sh [--force]

FORCE=${1-}
BACKUP_DIR="/var/backups/pam-password-policy-$(date +%Y%m%d%H%M%S)"
PWQUALITY_CONF_SOURCE="/Users/brayden/Desktop/projects/passpolicyset/pwquality.conf"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "Package $pkg is not installed. Installing..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  else
    echo "Package $pkg already installed."
  fi
}

backup_file() {
  local file="$1"
  mkdir -p "$BACKUP_DIR"
  if [ -e "$file" ]; then
    cp -a "$file" "$BACKUP_DIR/"
    echo "Backed up $file to $BACKUP_DIR/"
  fi
}

install_pwquality_conf() {
  local target="/etc/security/pwquality.conf"
  if [ -e "$target" ] && [ -z "$FORCE" ]; then
    echo "$target already exists. Use --force to overwrite. Skipping."
    return
  fi
  backup_file "$target"
  cp -a "$PWQUALITY_CONF_SOURCE" "$target"
  chmod 0644 "$target"
  echo "Installed pwquality config to $target"
}

ensure_pam_common_password() {
  local file="/etc/pam.d/common-password"
  local marker="# pam_pwquality configured by set-pam-password-policy"
  backup_file "$file"

  if grep -q "pam_pwquality.so" "$file"; then
    echo "pam_pwquality already present in $file"
    if [ -n "$FORCE" ]; then
      echo "--force specified, replacing existing pam_pwquality line(s)."
      # remove existing lines with pam_pwquality.so
      sed -i.bak '/pam_pwquality.so/d' "$file"
    else
      return
    fi
  fi

  # Insert pam_pwquality into the password stack for pam_unix.so
  # On Ubuntu, common-password contains a line like:
  # password [success=1 default=ignore] pam_unix.so obscure sha512
  # We'll append a pam_pwquality.so call before pam_unix.so if possible.

  if grep -q "pam_unix.so" "$file"; then
    # Insert before the first pam_unix.so line
    awk -v marker="$marker" '
      BEGIN{inserted=0}
      /pam_unix.so/ && !inserted {
        print "password requisite pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=" || marker
        inserted=1
      }
      {print}
      END{if(!inserted){print "# Could not find pam_unix.so to hook into - manual review required"}}
    ' "$file" > "$file.new"
    # fix the odd concatenation due to marker variable above
    sed -i "s/try_first_pass local_users_only retry=3 authtok_type=\|\| marker/try_first_pass local_users_only retry=3 authtok_type=//" "$file.new" || true
    # Prepend marker on its own line
    sed -i "1i$marker" "$file.new" || true
    mv "$file.new" "$file"
    chmod 0644 "$file"
    echo "Updated $file to include pam_pwquality"
  else
    echo "Could not find pam_unix.so in $file; adding pam_pwquality at end of file. Manual review recommended." >&2
    echo "$marker" >> "$file"
    echo "password requisite pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=" >> "$file"
  fi
}

verify_setup() {
  echo "Verification steps (basic):"
  echo "- pwquality config: cat /etc/security/pwquality.conf"
  echo "- common-password: grep pam_pwquality /etc/pam.d/common-password || true"
}

main() {
  require_root
  echo "Starting PAM password policy setup"
  ensure_package libpam-pwquality
  install_pwquality_conf
  ensure_pam_common_password
  verify_setup
  echo "Done. Backups saved in $BACKUP_DIR"
}

main "$@"
