# shellcheck shell=sh
# /ttl_on: chạy đúng flow Magisk (MODDIR, DROP→sleep 30, nfqttl, NFQUEUE 6464).
# Đường dẫn module: TETHER_NFQTTL_DIR (như MODDIR) hoặc suy ra từ TETHER_NFQTTL_BIN.
# ttl_tether_apply/clear: no-op (để usb_wifi ttl_tether_sync không chạy script nặng).

# Thư mục module (= MODDIR trong script gốc).
ttl_get_moddir() {
  if [ -n "${TETHER_NFQTTL_DIR:-}" ] && [ -d "${TETHER_NFQTTL_DIR}" ]; then
    echo "${TETHER_NFQTTL_DIR}"
    return
  fi
  if [ -n "${TETHER_NFQTTL_BIN:-}" ]; then
    d="$(dirname "${TETHER_NFQTTL_BIN}")"
    if [ -d "$d" ]; then
      echo "$d"
      return
    fi
  fi
  echo ""
}

# Theo đúng script bạn cung cấp (bash/sh tương đương).
ttl_on_run_script() {
  MODDIR="$(ttl_get_moddir)"
  if [ -z "$MODDIR" ] || [ ! -x "$MODDIR/nfqttl" ]; then
    return 1
  fi

  iptables -t mangle -I FORWARD -j DROP
  ip6tables -t mangle -I FORWARD -j DROP
  sleep 30
  iptables -t mangle -D FORWARD -j DROP
  ip6tables -t mangle -D FORWARD -j DROP

  count=0
  while true; do
    if ps 2>/dev/null | grep -v grep | grep -Fq "$MODDIR/nfqttl"
    then
      break
    fi
    if [ "$count" -ge 8 ]; then
      return 1
    fi
    count=$((count + 1))
    "$MODDIR/nfqttl" -d -s -u
    sleep 5
  done

  iptables -t mangle -N nfqttli
  iptables -t mangle -A nfqttli -j NFQUEUE --queue-num 6464
  iptables -t mangle -N nfqttlo
  iptables -t mangle -A nfqttlo -j NFQUEUE --queue-num 6464
  iptables -t mangle -A PREROUTING -j nfqttli
  iptables -t mangle -A OUTPUT -j nfqttlo

  ip6tables -t mangle -N nfqttli
  ip6tables -t mangle -A nfqttli -j NFQUEUE --queue-num 6464
  ip6tables -t mangle -N nfqttlo
  ip6tables -t mangle -A nfqttlo -j NFQUEUE --queue-num 6464
  ip6tables -t mangle -A PREROUTING -j nfqttli
  ip6tables -t mangle -A POSTROUTING -j nfqttlo
  return 0
}

ttl_tether_apply() {
  return 0
}

ttl_tether_clear() {
  return 0
}
