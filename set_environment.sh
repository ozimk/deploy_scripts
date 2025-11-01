    #!/usr/bin/env bash
    set -Eeuo pipefail

    : "${TARGET_DIR:=/usr/local/cisco_scripts}"
    LOG_FILE="/var/log/cisco_scripts_install.log"
    log()  { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }  # logging only
    err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }
    require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Must run as root"; exit 1; }; }

    main() {
      require_root
      install -d -m 0755 /etc/profile.d
      cat >/etc/profile.d/cisco.sh <<EOF
# Cisco Scripts env
export CISCO_PATH="${TARGET_DIR}"
if [ -d "\$CISCO_PATH/bin" ]; then
  case ":\$PATH:" in
    *:"\$CISCO_PATH/bin":*) : ;;
    *) export PATH="\$PATH:\$CISCO_PATH/bin" ;;
  esac
fi
EOF
      chmod 0644 /etc/profile.d/cisco.sh
      printf "[INFO] Environment file created at /etc/profile.d/cisco.sh\n" | tee -a "$LOG_FILE"
    }

    main "$@"
