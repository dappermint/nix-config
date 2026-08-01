let
  logMaxBytes = 5 * 1024 * 1024;
in
{
  rotateLog = ''
    rotate_log() {
      local log=$1
      [ -f "$log" ] || return 0
      if [ "$(wc -c < "$log")" -gt ${toString logMaxBytes} ]; then
        cp "$log" "$log.1"
        : > "$log"
      fi
    }
  '';

  dataVolumeFreePercent = ''
    data_volume_free_percent() {
      local used
      used=$(/bin/df -Pk /System/Volumes/Data | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')
      [[ "$used" =~ ^[0-9]+$ ]] || return 1
      printf '%s\n' "$((100 - used))"
    }
  '';
}
