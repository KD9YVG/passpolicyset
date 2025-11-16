## ⚠️ This whole repo was vibe-coded. Use at your own risk

set-pam-password-policy

This small utility writes a conservative pwquality config and ensures PAM uses pam_pwquality.so on Ubuntu.

Files created:
- set-pam-password-policy.sh: idempotent script to apply the changes
- pwquality.conf: sample configuration that will be copied to /etc/security/pwquality.conf

Usage:
1. Inspect the sample config: cat /Users/brayden/Desktop/projects/passpolicyset/pwquality.conf
2. Run with sudo: sudo bash /Users/brayden/Desktop/projects/passpolicyset/set-pam-password-policy.sh
   - Use --force to overwrite existing /etc/security/pwquality.conf and existing pam_pwquality lines.
3. Verify:
   - cat /etc/security/pwquality.conf
   - grep pam_pwquality /etc/pam.d/common-password

Notes and safety:
- The script makes backups in /var/backups/pam-password-policy-<timestamp>.
- Test on a non-production machine first. Misconfiguring PAM can lock you out.
- If you use custom PAM stacks or non-Debian-based systems, manual tuning is required.
