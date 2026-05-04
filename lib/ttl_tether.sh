# shellcheck shell=sh
# /ttl_on: cùng luồng module Magisk NFQTTL (customize.sh + service.sh) nhưng KHÔNG chạy nhị phân nfqttl
# (không phụ thuộc bản quyền nfqttl). Thay NFQUEUE --queue-num 6464 bằng TTL / HL trong chain nfqttli/nfqttlo.
#
# Giống service.sh: FORWARD DROP → sleep 30 → bỏ DROP → gắn mangle.
# Giống customize.sh: IPv4 PREROUTING→nfqttli, OUTPUT→nfqttlo; IPv6 PREROUTING→nfqttli, POSTROUTING→nfqttlo.
#
# Tuỳ chọn config.sh:
#   TETHER_MODDIR hoặc TETHER_NFQTTL_DIR — thư mục module (chỉ để tương thích cấu hình cũ; bot không gọi nfqttl).
#   TETHER_TTL_VALUE        — TTL / hop limit (mặc định 64)
#   TETHER_TTL_DROP_WAIT    — giây FORWARD DROP (mặc định 30; 0 = tắt)
#   TETHER_TTL_OUT_IFACE    — tuỳ chọn, ví dụ rmnet_data0 (áp vào rule trong nfqttli/nfqttlo)
#   TETHER_TTL_POST_DROP_SLEEP — giây chờ sau khi gỡ DROP, trước khi gắn rule (mặc định 0; một số ROM/modem ổn định hơn nếu 1–3)
#
#   TTL_ON_LAST_ERROR — handler đọc khi thất bại

# MODDIR tương đương Magisk (không bắt buộc cho iptables).
ttl_get_moddir() {
  for v in "${TETHER_MODDIR:-}" "${TETHER_NFQTTL_DIR:-}"; do
    [ -n "$v" ] && [ -d "$v" ] && { echo "$v"; return; }
  done
  echo ""
}

# Gỡ hoàn toàn nfqttli / nfqttlo (NFQUEUE cũ hoặc TTL của bot).
ttl_nfqttl_chains_remove() {
  for BIN in iptables ip6tables; do
    command -v "$BIN" >/dev/null 2>&1 || continue
    if [ "$BIN" = "iptables" ]; then
      while "$BIN" -t mangle -D PREROUTING -j nfqttli 2>/dev/null; do :; done
      while "$BIN" -t mangle -D OUTPUT -j nfqttlo 2>/dev/null; do :; done
    else
      while "$BIN" -t mangle -D PREROUTING -j nfqttli 2>/dev/null; do :; done
      while "$BIN" -t mangle -D POSTROUTING -j nfqttlo 2>/dev/null; do :; done
    fi
    "$BIN" -t mangle -F nfqttli 2>/dev/null
    "$BIN" -t mangle -X nfqttli 2>/dev/null
    "$BIN" -t mangle -F nfqttlo 2>/dev/null
    "$BIN" -t mangle -X nfqttlo 2>/dev/null
  done
}

# Gỡ chuỗi tg_ttl_* nếu còn từ bản bot cũ.
_ttl_legacy_tg_chains_remove() {
  for BIN in iptables ip6tables; do
    command -v "$BIN" >/dev/null 2>&1 || continue
    for c in tg_ttl_fix tg_ttl_fix6; do
      while "$BIN" -t mangle -D POSTROUTING -j "$c" 2>/dev/null; do :; done
      "$BIN" -t mangle -F "$c" 2>/dev/null
      "$BIN" -t mangle -X "$c" 2>/dev/null
    done
  done
}

ttl_mangle_clear() {
  ttl_nfqttl_chains_remove
  _ttl_legacy_tg_chains_remove
}

# Gắn nfqttli/nfqttlo với TTL (v4) và HL (v6), cùng hook như customize.sh.
ttl_mangle_apply_core() {
  TTL_ON_LAST_ERROR=""
  val="${TETHER_TTL_VALUE:-64}"
  case "$val" in ''|*[!0-9]*) val=64 ;; esac
  out="${TETHER_TTL_OUT_IFACE:-}"
  out="$(echo "$out" | tr -d '[:space:]')"

  ttl_mangle_clear

  if ! command -v iptables >/dev/null 2>&1; then
    TTL_ON_LAST_ERROR="không có lệnh iptables (PATH / hệ thống)"
    return 1
  fi

  if ! iptables -t mangle -N nfqttli 2>/dev/null; then
    err="$(iptables -t mangle -N nfqttli 2>&1)"
    TTL_ON_LAST_ERROR="iptables -N nfqttli: $err"
    return 1
  fi
  if [ -n "$out" ]; then
    err="$(iptables -t mangle -A nfqttli -o "$out" -j TTL --ttl-set "$val" 2>&1)"
  else
    err="$(iptables -t mangle -A nfqttli -j TTL --ttl-set "$val" 2>&1)"
  fi
  rc=$?
  if [ "$rc" != "0" ]; then
    TTL_ON_LAST_ERROR="nfqttli TTL: $err"
    iptables -t mangle -F nfqttli 2>/dev/null
    iptables -t mangle -X nfqttli 2>/dev/null
    return 1
  fi

  if ! iptables -t mangle -N nfqttlo 2>/dev/null; then
    TTL_ON_LAST_ERROR="iptables -N nfqttlo: $(iptables -t mangle -N nfqttlo 2>&1)"
    iptables -t mangle -F nfqttli 2>/dev/null
    iptables -t mangle -X nfqttli 2>/dev/null
    return 1
  fi
  if [ -n "$out" ]; then
    err="$(iptables -t mangle -A nfqttlo -o "$out" -j TTL --ttl-set "$val" 2>&1)"
  else
    err="$(iptables -t mangle -A nfqttlo -j TTL --ttl-set "$val" 2>&1)"
  fi
  rc=$?
  if [ "$rc" != "0" ]; then
    TTL_ON_LAST_ERROR="nfqttlo TTL: $err"
    iptables -t mangle -F nfqttlo 2>/dev/null
    iptables -t mangle -X nfqttlo 2>/dev/null
    iptables -t mangle -F nfqttli 2>/dev/null
    iptables -t mangle -X nfqttli 2>/dev/null
    return 1
  fi

  if ! iptables -t mangle -A PREROUTING -j nfqttli 2>/dev/null; then
    TTL_ON_LAST_ERROR="PREROUTING→nfqttli: $(iptables -t mangle -A PREROUTING -j nfqttli 2>&1)"
    ttl_nfqttl_chains_remove
    return 1
  fi
  if ! iptables -t mangle -A OUTPUT -j nfqttlo 2>/dev/null; then
    TTL_ON_LAST_ERROR="OUTPUT→nfqttlo: $(iptables -t mangle -A OUTPUT -j nfqttlo 2>&1)"
    ttl_nfqttl_chains_remove
    return 1
  fi

  if command -v ip6tables >/dev/null 2>&1; then
    if ip6tables -t mangle -N nfqttli 2>/dev/null; then
      ok=1
      if [ -n "$out" ]; then
        ip6tables -t mangle -A nfqttli -o "$out" -j HL --hl-set "$val" 2>/dev/null || ok=0
      else
        ip6tables -t mangle -A nfqttli -j HL --hl-set "$val" 2>/dev/null || ok=0
      fi
      if [ "$ok" = "1" ] && ip6tables -t mangle -N nfqttlo 2>/dev/null; then
        ok2=1
        if [ -n "$out" ]; then
          ip6tables -t mangle -A nfqttlo -o "$out" -j HL --hl-set "$val" 2>/dev/null || ok2=0
        else
          ip6tables -t mangle -A nfqttlo -j HL --hl-set "$val" 2>/dev/null || ok2=0
        fi
        if [ "$ok2" = "1" ] \
          && ip6tables -t mangle -A PREROUTING -j nfqttli 2>/dev/null \
          && ip6tables -t mangle -A POSTROUTING -j nfqttlo 2>/dev/null; then
          :
        else
          while ip6tables -t mangle -D PREROUTING -j nfqttli 2>/dev/null; do :; done
          while ip6tables -t mangle -D POSTROUTING -j nfqttlo 2>/dev/null; do :; done
          ip6tables -t mangle -F nfqttlo 2>/dev/null
          ip6tables -t mangle -X nfqttlo 2>/dev/null
          ip6tables -t mangle -F nfqttli 2>/dev/null
          ip6tables -t mangle -X nfqttli 2>/dev/null
        fi
      else
        ip6tables -t mangle -F nfqttli 2>/dev/null
        ip6tables -t mangle -X nfqttli 2>/dev/null
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
}

# Giống service.sh: DROP 30s → (không có nfqttl / không vòng ps) → gắn nfqttli/nfqttlo như trên.
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
      TTL_ON_LAST_ERROR="FORWARD DROP (IPv4): $(iptables -t mangle -I FORWARD -j DROP 2>&1)"
      return 1
    fi
    ip6tables -t mangle -I FORWARD -j DROP 2>/dev/null || true
    sleep "$dw"
    iptables -t mangle -D FORWARD -j DROP 2>/dev/null || true
    ip6tables -t mangle -D FORWARD -j DROP 2>/dev/null || true
  fi

  pds="${TETHER_TTL_POST_DROP_SLEEP:-0}"
  case "$pds" in ''|*[!0-9]*) pds=0 ;; esac
  if [ "$pds" -gt 0 ]; then
    sleep "$pds"
  fi

  # Module gốc: while + nfqttl -d -s -u tối đa 8 lần, chờ ps thấy tiến trình. Không dùng nfqttl → bỏ vòng.

  ttl_mangle_apply_core || return 1
  return 0
}
