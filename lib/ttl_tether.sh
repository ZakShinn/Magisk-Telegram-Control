# shellcheck shell=sh
# Gộp TTL gói IPv4/IPv6 ra nhà mạng (rmnet/ccmni) — giảm khả năng DPI phát hiện tether qua chênh TTL.
# Không đảm bảo 100%; một số máy offload/NFC bỏ qua iptables; có thể trái điều khoản nhà mạng.

TTL_CHAIN4="TG_TC_TTL"
TTL_CHAIN6="TG_TC_TTL6"

# Sau ttl_tether_apply (để bot gửi nhật ký); đặt rỗng khi clear/thất bại sớm.
TTL_LAST_APPLY_VALUE=""
TTL_LAST_POSTROUTING_V4=0
TTL_LAST_POSTROUTING_V6=0
TTL_LAST_IPT4=""
TTL_LAST_IPT6=""
TTL_LAST_V4_TARGET=""

_ttl_sysctl_default() {
  v="$(sysctl -n net.ipv4.ip_default_ttl 2>/dev/null || echo "")"
  case "$v" in ''|*[!0-9]*) echo "65" ;; *) echo "$v" ;; esac
}

_find_ipt4() {
  for c in iptables /system/bin/iptables /system/xbin/iptables; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return; }
  done
  echo ""
}

_find_ipt6() {
  for c in ip6tables /system/bin/ip6tables /system/xbin/ip6tables; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return; }
  done
  echo ""
}

ttl_tether_clear() {
  IPT4="$(_find_ipt4)"
  if [ -n "$IPT4" ]; then
    for iface in $(ls /sys/class/net 2>/dev/null); do
      case "$iface" in rmnet*|ccmni*|wlan_rmnet*|ccemni*)
        i=0
        while [ "$i" -lt 24 ]; do
          $IPT4 -t mangle -D POSTROUTING -o "$iface" -j "$TTL_CHAIN4" 2>/dev/null || break
          i=$((i + 1))
        done
        ;;
      esac
    done
    $IPT4 -t mangle -F "$TTL_CHAIN4" 2>/dev/null || true
    $IPT4 -t mangle -X "$TTL_CHAIN4" 2>/dev/null || true
  fi

  IPT6="$(_find_ipt6)"
  if [ -n "$IPT6" ]; then
    for iface in $(ls /sys/class/net 2>/dev/null); do
      case "$iface" in rmnet*|ccmni*|wlan_rmnet*|ccemni*)
        i=0
        while [ "$i" -lt 24 ]; do
          $IPT6 -t mangle -D POSTROUTING -o "$iface" -j "$TTL_CHAIN6" 2>/dev/null || break
          i=$((i + 1))
        done
        ;;
      esac
    done
    $IPT6 -t mangle -F "$TTL_CHAIN6" 2>/dev/null || true
    $IPT6 -t mangle -X "$TTL_CHAIN6" 2>/dev/null || true
  fi

  TTL_LAST_APPLY_VALUE=""
  TTL_LAST_POSTROUTING_V4=0
  TTL_LAST_POSTROUTING_V6=0
  TTL_LAST_IPT4=""
  TTL_LAST_IPT6=""
  TTL_LAST_V4_TARGET=""
}

# Tuỳ chọn $1 = TTL cố định (chỉ số); rỗng = dùng TETHER_TTL_VALUE hoặc sysctl mặc định.
ttl_tether_apply() {
  TTL_OVERRIDE="$(echo "${1:-}" | tr -cd '0-9')"

  TTL_LAST_APPLY_VALUE=""
  TTL_LAST_POSTROUTING_V4=0
  TTL_LAST_POSTROUTING_V6=0
  TTL_LAST_IPT4=""
  TTL_LAST_IPT6=""
  TTL_LAST_V4_TARGET=""

  IPT4="$(_find_ipt4)"
  [ -z "$IPT4" ] && return 1

  if [ -n "$TTL_OVERRIDE" ]; then
    TTLV="$TTL_OVERRIDE"
  else
    TTLV="${TETHER_TTL_VALUE:-}"
    [ -z "$TTLV" ] && TTLV="$(_ttl_sysctl_default)"
  fi
  case "$TTLV" in ''|*[!0-9]*) TTLV=65 ;; esac
  [ "$TTLV" -lt 1 ] && TTLV=1
  [ "$TTLV" -gt 255 ] && TTLV=255

  ttl_tether_clear || true

  if ! $IPT4 -t mangle -N "$TTL_CHAIN4" 2>/dev/null; then
    $IPT4 -t mangle -F "$TTL_CHAIN4" 2>/dev/null || true
  fi

  if $IPT4 -t mangle -A "$TTL_CHAIN4" -j TTL --ttl-set "$TTLV" 2>/dev/null; then
    TTL_LAST_V4_TARGET="TTL (--ttl-set)"
  elif $IPT4 -t mangle -A "$TTL_CHAIN4" -j HL --hl-set "$TTLV" 2>/dev/null; then
    TTL_LAST_V4_TARGET="HL (--hl-set, fallback IPv4)"
  else
    return 1
  fi

  n=0
  for iface in $(ls /sys/class/net 2>/dev/null); do
    case "$iface" in rmnet*|ccmni*|wlan_rmnet*|ccemni*)
      $IPT4 -t mangle -A POSTROUTING -o "$iface" -j "$TTL_CHAIN4" 2>/dev/null && n=$((n + 1))
      ;;
    esac
  done

  n6=0
  IPT6="$(_find_ipt6)"
  if [ -n "$IPT6" ]; then
    if ! $IPT6 -t mangle -N "$TTL_CHAIN6" 2>/dev/null; then
      $IPT6 -t mangle -F "$TTL_CHAIN6" 2>/dev/null || true
    fi
    if $IPT6 -t mangle -A "$TTL_CHAIN6" -j HL --hl-set "$TTLV" 2>/dev/null; then
      for iface in $(ls /sys/class/net 2>/dev/null); do
        case "$iface" in rmnet*|ccmni*|wlan_rmnet*|ccemni*)
          $IPT6 -t mangle -A POSTROUTING -o "$iface" -j "$TTL_CHAIN6" 2>/dev/null && n6=$((n6 + 1))
          ;;
        esac
      done
    fi
  fi

  TTL_LAST_APPLY_VALUE="$TTLV"
  TTL_LAST_POSTROUTING_V4="$n"
  TTL_LAST_POSTROUTING_V6="$n6"
  TTL_LAST_IPT4="$IPT4"
  TTL_LAST_IPT6="$IPT6"

  if [ "$n" -gt 0 ] || [ "$n6" -gt 0 ]; then
    return 0
  fi
  return 1
}
