# Present the guided Lumen installer as soon as the live ISO root shell opens.
if [[ -z "${LUMEN_INSTALLER_STARTED:-}" && -t 0 ]]; then
  export LUMEN_INSTALLER_STARTED=1
  /usr/local/bin/lumen-install
fi
