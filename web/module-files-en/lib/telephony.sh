# shellcheck shell=sh
# Cellular signal, network type, band, public IP

get_dbm_from_dump() {
  out="$1"
  for key in lteRsrp mLteRsrp rsrp mSignalStrengthDbm cdmaDbm dbm; do
    v="$(echo "$out" | grep -oE "${key}=[-]?[0-9]+" | head -n1 | sed 's/[^-0-9]//g')"
    [ -n "$v" ] && { echo "$v"; return; }
  done
  sigblock="$(echo "$out" | tr '\n' ' ' | sed -n 's/.*SignalStrength{/\n&/p' | head -n1)"
  if [ -n "$sigblock" ]; then
    v="$(echo "$sigblock" | grep -oE '-[0-9]{1,3}' | head -n1 | sed 's/[^-0-9]//g')"
    [ -n "$v" ] && { echo "$v"; return; }
  fi
  asu="$(echo "$out" | grep -oE 'gsmSignalStrength=[0-9]+' | head -n1 | cut -d= -f2)"
  if [ -n "$asu" ]; then echo $(( -113 + 2 * asu )); return; fi
  echo "N/A"
}

get_dbm() {
  v="$(getprop_safe sm.signalstrength)"
  if echo "$v" | grep -qE '^-?[0-9]+'; then echo "$v"; return; fi
  v="$(getprop_safe gsm.signalstrength)"
  if echo "$v" | grep -qE '^-?[0-9]+'; then echo "$v"; return; fi
  out="$(dumpsys telephony.registry 2>/dev/null || dumpsys telephony 2>/dev/null || true)"
  get_dbm_from_dump "$out"
}

map_sig_quality() {
  val="$1"
  if echo "$val" | grep -qE '^-?[0-9]+'; then
    n=$(printf "%d" "$val" 2>/dev/null || echo "")
    if [ -n "$n" ]; then
      if   [ "$n" -ge -85 ]; then echo "Excellent"
      elif [ "$n" -ge -100 ]; then echo "Fair"
      else echo "Poor"
      fi
    else
      echo "N/A"
    fi
  else
    echo "N/A"
  fi
}

get_signal_bars() {
  dbm="$1"
  ql="$(map_sig_quality "$dbm")"
  if   [ "$ql" = "Excellent" ]; then echo "📶📶📶 (${ql})"
  elif [ "$ql" = "Fair" ]; then echo "📶📶 (${ql})"
  elif [ "$ql" = "Poor" ]; then echo "📶 (${ql})"
  else echo "N/A"
  fi
}

is_nr_connected() {
  out="$(dumpsys telephony 2>/dev/null || true)"
  reg="$(dumpsys telephony.registry 2>/dev/null || true)"
  all="$out
$reg"
  echo "$all" | grep -qiE 'nrState[=: ]+CONNECTED|CellIdentityNr|CellInfoNr|PUBLIC_NR|TYPE_NR|DATA_NETWORK_TYPE_NR|NETWORK_TYPE_NR|EN-DC|ENDC|RAT_NR|NrArfcn|SsRsrp' && return 0
  echo "$all" | grep -qiE 'isNrConnected[=: ]+true|mNrState[=: ]+CONNECTED|PhysicalChannelConfig[^
]*[=: ]NR|bandwidth.*NR|Mmwave' && return 0
  echo "$all" | grep -qiE 'mDataNetworkType=20|mVoiceNetworkType=20|TransportBlock.*NR' && return 0
  getprop gsm.network.type 2>/dev/null | grep -qiE 'NR|5G' && return 0
  return 1
}

rat_num_to_name() {
  case "$1" in
    20) echo "5G";;
    13) echo "LTE";;
    8|9|10|15|3) echo "3G";;
    1|2) echo "2G";;
    *) echo "Unknown";;
  esac
}

get_nettype() {
  NETTYPE_RAW="$(getprop_safe gsm.network.type)"
  REG="$(dumpsys telephony.registry 2>/dev/null || true)"
  TEL="$(dumpsys telephony 2>/dev/null || true)"
  COMBINED="$REG
$TEL"
  DATA_NUM="$(echo "$REG" | grep -oE 'mDataNetworkType=[0-9]+' | head -n1 | cut -d= -f2)"
  ntu="$(echo "$NETTYPE_RAW" | tr '[:lower:]' '[:upper:]')"
  ntc="$(echo "$NETTYPE_RAW" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"

  case "$ntc" in
    *LTE*NR*|*NR*LTE*)
      echo "LTE+NR (NSA)"
      return
      ;;
  esac

  if echo "$COMBINED" | grep -qiE 'EN-DC|ENDC' \
    && echo "$COMBINED" | grep -qiE 'CellIdentityNr|CellInfoNr|RAT_NR|SsRsrp|NrArfcn'; then
    echo "LTE+NR (NSA)"
    return
  fi

  case "$ntc" in
    NR|NR_SA|5G|5G_SA|SA|SA_NR)
      echo "5G (SA)"
      return
      ;;
  esac

  case "$ntu" in
    *NR*|*5G*)
      echo "5G"
      return
      ;;
  esac

  if [ "$DATA_NUM" = "20" ]; then
    echo "5G"
    return
  fi

  if is_nr_connected; then
    echo "5G"
    return
  fi

  if echo "$DATA_NUM" | grep -qE '^[0-9]+$'; then
    rat="$(rat_num_to_name "$DATA_NUM")"
    if [ "$rat" = "LTE" ]; then
      if echo "$COMBINED" | grep -qiE 'CellIdentityNr|CellInfoNr|PUBLIC_NR|TYPE_NR|EN-DC|ENDC|NETWORK_TYPE_NR|PHY.*[=: ]NR|RAT_NR|SsRsrp'; then
        echo "LTE+NR (NSA)"
        return
      fi
    fi
    if [ "$rat" != "Unknown" ]; then
      echo "$rat"
      return
    fi
  fi

  if [ -n "$NETTYPE_RAW" ]; then
    up="$(echo "$NETTYPE_RAW" | tr '[:lower:]' '[:upper:]')"
    case "$up" in
      *NR*|*5G*) echo "5G";;
      *LTE*) echo "LTE";;
      *HSPA*|*UMTS*|*3G*) echo "3G";;
      *EDGE*|*GPRS*|*2G*) echo "2G";;
      *) echo "$NETTYPE_RAW";;
    esac
  else
    echo "Unknown"
  fi
}

get_nettype_with_desc() {
  base="$(get_nettype)"
  case "$base" in
    "5G (SA)")
      echo "5G (SA) – Standalone 5G"
      ;;
    "LTE+NR (NSA)")
      echo "LTE+NR (NSA) – 4G LTE + 5G (Non-Standalone)"
      ;;
    "5G")
      echo "5G – (connection mode unknown)"
      ;;
    "LTE")
      echo "LTE – 4G LTE"
      ;;
    "3G")
      echo "3G – UMTS/HSPA"
      ;;
    "2G")
      echo "2G – GSM/EDGE"
      ;;
    *)
      echo "$base"
      ;;
  esac
}

get_operator_name() {
  op="$(getprop_safe gsm.operator.alpha)"
  if [ -n "$op" ] && [ "$op" != "null" ]; then
    echo "$op"
    return
  fi

  op="$(getprop_safe gsm.sim.operator.alpha)"
  if [ -n "$op" ] && [ "$op" != "null" ]; then
    echo "$op"
    return
  fi

  out="$(dumpsys telephony.registry 2>/dev/null || dumpsys telephony 2>/dev/null || true)"
  op="$(echo "$out" \
    | grep -oE 'operatorAlpha(Long|Short)=[^,]+' \
    | head -n1 \
    | sed 's/.*=//')"

  if [ -n "$op" ]; then
    echo "$op"
  else
    echo "Unknown"
  fi
}

get_band_info_from_dump() {
  out="$1"

  nr_band="$(
    echo "$out" | grep -oiE 'nr[Bb]and[: =][nN]?[0-9]+' | head -n1 | sed -E 's/.*[=: ]//; s/^n?([0-9]+)$/n\1/'
  )"
  if [ -n "$nr_band" ]; then
    echo "NR band ${nr_band}"
    return
  fi

  pcc_nr_band="$(
    echo "$out" | tr '\n' ' ' | sed -n 's/.*PhysicalChannelConfig{/&\n/p' | head -n1 | grep -oiE 'band[:= ][nN]?[0-9]+' | head -n1 | sed -E 's/.*[ =]//; s/^n?([0-9]+)$/n\1/'
  )"
  if [ -n "$pcc_nr_band" ]; then
    echo "NR band ${pcc_nr_band}"
    return
  fi

  lte_band="$(
    echo "$out" | grep -oiE '(lte[Bb]and|mLteBand|bandLTE|eutranBand)[: =][0-9]+' | head -n1 | grep -oE '[0-9]+'
  )"
  if [ -n "$lte_band" ]; then
    echo "LTE band ${lte_band}"
    return
  fi

  pcc_lte_band="$(
    echo "$out" | tr '\n' ' ' | sed -n 's/.*PhysicalChannelConfig{/&\n/p' | head -n1 | grep -oiE 'band[:= ][0-9]+' | head -n1 | grep -oE '[0-9]+'
  )"
  if [ -n "$pcc_lte_band" ]; then
    echo "LTE band ${pcc_lte_band}"
    return
  fi

  echo ""
}

get_band_info() {
  out="$(dumpsys telephony 2>/dev/null || true; dumpsys telephony.registry 2>/dev/null || true)"
  get_band_info_from_dump "$out"
}

get_rsrq_db_from_dump() {
  echo "$1" | grep -oiE '(ssRsrq|lteRsrq|rsrq)[=:]-?[0-9]+' | head -n1 | grep -oE '-?[0-9]+' | head -n1
}

get_sinr_db_from_dump() {
  echo "$1" | grep -oiE '(ssSinr|ssSNR|lteRssnr|rssnr|nrSsSinr)[=:]-?[0-9]+' | head -n1 | grep -oE '-?[0-9]+' | head -n1
}

# Keep function name for compatibility (used by handlers.sh).
get_roaming_status_vi_from_dump() {
  dump="$1"
  if echo "$dump" | grep -qiE '(isVoiceRoaming|isDataRoaming|mVoiceRoaming|mDataRoaming)[=: ]+true'; then
    echo "Roaming"
  else
    echo "Home"
  fi
}

format_dbm_strength_meter() {
  dbm="$1"
  if ! echo "$dbm" | grep -qE '^-?[0-9]+$'; then
    echo ""
    return
  fi
  n=$(printf "%d" "$dbm")
  pct=$(( (n + 120) * 100 / 70 ))
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  filled=$(( (pct * 8 + 50) / 100 ))
  [ "$filled" -gt 8 ] && filled=8
  empty=$(( 8 - filled ))
  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}█"
    i=$(( i + 1 ))
  done
  i=0
  while [ "$i" -lt "$empty" ]; do
    bar="${bar}░"
    i=$(( i + 1 ))
  done
  echo "${bar} ${pct}%"
}

get_public_ip() {
  for url in "https://api.ipify.org" "https://ifconfig.me" "https://ipinfo.io/ip"; do
    ip="$(curl -s --max-time 5 "$url" 2>/dev/null | tr -d '\n\r ')"
    echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[0-9a-fA-F:]+$' && { echo "$ip"; return; }
  done
  echo ""
}

