    #!/usr/bin/env bash
    set -Eeuo pipefail

    LOG_FILE="/var/log/cisco_scripts_install.log"
    : "${TARGET_DIR:=/usr/local/cisco_scripts}"

    log()  { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
    warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
    err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }
    require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Must run as root"; exit 1; }; }

    main() {
      require_root

      local docroot="$TARGET_DIR/html"
      [[ -d "$docroot" ]] || docroot="$TARGET_DIR"

      # Apache vhost/conf for RHEL
      cat >/etc/httpd/conf.d/cisco_scripts.conf <<CONF
# Cisco scripts app
ServerName localhost
DocumentRoot "$docroot"
<Directory "$docroot">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# Route PHP to php-fpm (RHEL-style)
<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>
CONF

      # Permissions and SELinux contexts
      chown -R apache:apache "$TARGET_DIR" || true
      # Mark content readable by httpd
      semanage fcontext -a -t httpd_sys_content_t "$TARGET_DIR(/.*)?" || true
      # Common writable dirs
      for w in "$docroot"/uploads "$docroot"/cache "$TARGET_DIR"/storage; do
        [[ -d "$w" ]] || continue
        chown -R apache:apache "$w" || true
        semanage fcontext -a -t httpd_sys_rw_content_t "$w(/.*)?" || true
      done
      restorecon -Rv "$TARGET_DIR" || true

      # Allow outbound connections if app calls remote APIs/DBs
      setsebool -P httpd_can_network_connect on || true

      systemctl restart php-fpm || true
      systemctl restart httpd || true
      systemctl enable httpd php-fpm || true

      log "httpd configured. DocumentRoot=$docroot"
    }

    main "$@"
