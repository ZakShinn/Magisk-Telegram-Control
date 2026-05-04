# shellcheck shell=sh
# /ttl_on: TTL tether chỉ dùng iptables/ip6tables (mangle TTL / HL), không dùng nfqttl/NFQUEUE.
#
# Tuỳ chọn trong config.sh:
#   TETHER_TTL_VALUE       — giá trị TTL/Hop limit (mặc định 64)
#   TETHER_TTL_DROP_WAIT   — giây: FORWARD DROP trước khi gắn rule (mặc định 30; 0 = bỏ qua)
#   TETHER_TTL_OUT_IFACE   — ví dụ rmnet_data0: chỉ áp rule cho giao diện egress (tùy ROM)
#
# Biến do handler đọc khi thất bại:
#   TTL_ON_LAST_ERROR

TTL_CHAIN_V4="tg_ttl_fix"
TTL_CHAIN_V6="tg_ttl_fix6"

# Gỡ rule/chuỗi do bot tạo (IPv4 + IPv6).
ttl_mangle_clear() {
  for t in iptables ip6tables; do
    command -v "$t" >/dev/null 2>&1 || continue
    c="$TTL_CHAIN_V4"
    [ "$t" = "ip6tables" ] && c="$TTL_CHAIN_V6"
    while "$t" -t mangle -D POSTROUTING -j "$c" 2>/dev/null; do :; done
    "$t" -t mangle -F "$c" 2>/dev/null
    "$t" -t mangle -X "$c" 2>/dev/null
  done
}

# Xóa chain NFQUEUE cũ (bản bot trước + nfqttl) để tránh xung đột khi chuyển sang TTL trực tiếp.
ttl_legacy_nfqueue_chains_remove() {
  for BIN in iptables ip6tables; do
    command -v "$BIN" >/dev/null 2>&1 || continue
    while "$BIN" -t mangle -D PREROUTING -j nfqttli 2>/dev/null; do :; done
    while "$BIN" -t mangle -D OUTPUT -j nfqttlo 2>/dev/null; do :; done
    while "$BIN" -t mangle -D POSTROUTING -j nfqttlo 2>/dev/null; do :; done
    "$BIN" -t mangle -F nfqttli 2>/dev/null
    "$BIN" -t mangle -X nfqttli 2>/dev/null
    "$BIN" -t mangle -F nfqttlo 2>/dev/null
    "$BIN" -t mangle -X nfqttlo 2>/dev/null
  done
}

# Áp dụng TTL (IPv4) và Hop limit (IPv6) vào POSTROUTING qua custom chain. Không chạy DROP.
# Thất bại IPv4 → return 1 + TTL_ON_LAST_ERROR. IPv6: nếu HL lỗi thì bỏ qua, vẫn thành công nếu IPv4 ổn.
ttl_mangle_apply_core() {
  TTL_ON_LAST_ERROR=""
  val="${TETHER_TTL_VALUE:-64}"
  case "$val" in ''|*[!0-9]*) val=64 ;; esac
  out="${TETHER_TTL_OUT_IFACE:-}"
  out="$(echo "$out" | tr -d '[:space:]')"

  ttl_mangle_clear
  ttl_legacy_nfqueue_chains_remove

  if ! command -v iptables >/dev/null 2>&1; then
    TTL_ON_LAST_ERROR="không có lệnh iptables (PATH / hệ thống)"
    return 1
  fi

  if ! iptables -t mangle -N "$TTL_CHAIN_V4" 2>/dev/null; then
    err="$(iptables -t mangle -N "$TTL_CHAIN_V4" 2>&1)"
    TTL_ON_LAST_ERROR="iptables -N $TTL_CHAIN_V4: $err"
    return 1
  fi

  if [ -n "$out" ]; then
    err="$(iptables -t mangle -A "$TTL_CHAIN_V4" -o "$out" -j TTL --ttl-set "$val" 2>&1)"
    rc=$?
    if [ "$rc" != "0" ]; then
      TTL_ON_LAST_ERROR="TTL IPv4 (--ttl-set trên -o $out): $err"
      iptables -t mangle -F "$TTL_CHAIN_V4" 2>/dev/null
      iptables -t mangle -X "$TTL_CHAIN_V4" 2>/dev/null
      return 1
    fi
  else
    err="$(iptables -t mangle -A "$TTL_CHAIN_V4" -j TTL --ttl-set "$val" 2>&1)"
    rc=$?
    if [ "$rc" != "0" ]; then
      TTL_ON_LAST_ERROR="TTL IPv4 (--ttl-set): $err — thiếu module TTL hoặc không đủ quyền iptables"
      iptables -t mangle -F "$TTL_CHAIN_V4" 2>/dev/null
      iptables -t mangle -X "$TTL_CHAIN_V4" 2>/dev/null
      return 1
    fi
  fi

  if ! iptables -t mangle -I POSTROUTING 1 -j "$TTL_CHAIN_V4" 2>/dev/null; then
    err="$(iptables -t mangle -I POSTROUTING 1 -j "$TTL_CHAIN_V4" 2>&1)"
    TTL_ON_LAST_ERROR="gắn POSTROUTING → $TTL_CHAIN_V4: $err"
    iptables -t mangle -F "$TTL_CHAIN_V4" 2>/dev/null
    iptables -t mangle -X "$TTL_CHAIN_V4" 2>/dev/null
    return 1
  fi

  if command -v ip6tables >/dev/null 2>&1; then
    if ip6tables -t mangle -N "$TTL_CHAIN_V6" 2>/dev/null; then
      if [ -n "$out" ]; then
        if ! ip6tables -t mangle -A "$TTL_CHAIN_V6" -o "$out" -j HL --hl-set "$val" 2>/dev/null \
          || ! ip6tables -t mangle -I POSTROUTING 1 -j "$TTL_CHAIN_V6" 2>/dev/null; then
          ip6tables -t mangle -F "$TTL_CHAIN_V6" 2>/dev/null
          ip6tables -t mangle -X "$TTL_CHAIN_V6" 2>/dev/null
        fi
      else
        if ! ip6tables -t mangle -A "$TTL_CHAIN_V6" -j HL --hl-set "$val" 2>/dev/null \
          || ! ip6tables -t mangle -I POSTROUTING 1 -j "$TTL_CHAIN_V6" 2>/dev/null; then
          ip6tables -t mangle -F "$TTL_CHAIN_V6" 2>/dev/null
          ip6tables -t mangle -X "$TTL_CHAIN_V6" 2>/dev/null
        fi
      fi
    fi
  fi

  return 0
}

ttl_tether_apply() {
  ttl_mangle_apply_core
}

ttl_tether_clear() {
  ttl_mangle_clear
  ttl_legacy_nfqueue_chains_remove
}

# /ttl_on: tuỳ chọn DROP FORWARD (mặc định 30s) rồi áp mangle TTL.
ttl_on_run_script() {
  TTL_ON_LAST_ERROR=""
  uid="$(id -u 2>/dev/null)" || uid=""
  if [ "$uid" != "0" ]; then
    TTL_ON_LAST_ERROR="cần UID 0 (root/su). Hiện uid=${uid:-?}"
    return 1
  fi

  if ! command -v iptables >/dev/null 2>&1; then
    TTL_ON_LAST_ERROR="không có iptables trong PATH"
    return 1
  fi

  dw="${TETHER_TTL_DROP_WAIT:-30}"
  case "$dw" in ''|*[!0-9]*) dw=30 ;; esac

  if [ "$dw" -gt 0 ]; then
    if ! iptables -t mangle -I FORWARD -j DROP 2>/dev/null; then
      err="$(iptables -t mangle -I FORWARD -j DROP 2>&1)"
      TTL_ON_LAST_ERROR="FORWARD DROP (chuẩn bị TTL): $err"
      return 1
    fi
    ip6tables -t mangle -I FORWARD -j DROP 2>/dev/null || true
    sleep "$dw"
    iptables -t mangle -D FORWARD -j DROP 2>/dev/null || true
    ip6tables -t mangle -D FORWARD -j DROP 2>/dev/null || true
  fi

  ttl_mangle_apply_core || return 1
  return 0
}
