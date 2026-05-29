#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#  ◈ WEATHER — Open-Meteo backend (keyless, like the caelestia rice)
# -----------------------------------------------------------------------------
# Uses https://open-meteo.com — a free, no-API-key weather service.
# Location is auto-detected from your IP (ipinfo.io); set WEATHER_CITY in
# calendar/.env to override with a specific city. OPENWEATHER_UNIT still
# controls metric/imperial. Output JSON schema is unchanged, so CalendarPopup,
# TopBar and Lock keep working without edits.
# -----------------------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "weather"

export LC_ALL=C

cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
loc_cache="${cache_dir}/location.json"
ENV_FILE="$(dirname "$0")/.env"

mkdir -p "${cache_dir}"

# --- Load .env (safe line-by-line parse; tolerates spaces in values) ---------
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r _k _v; do
        [[ -z "$_k" || "$_k" == \#* ]] && continue
        _v="${_v%\"}"; _v="${_v#\"}"; _v="${_v%\'}"; _v="${_v#\'}"
        export "$_k=$_v"
    done < "$ENV_FILE"
fi

# Optional city override. WEATHER_CITY is preferred; a non-numeric legacy
# OPENWEATHER_CITY_ID is also accepted as a city name.
CFG_CITY="${WEATHER_CITY:-}"
if [[ -z "$CFG_CITY" && -n "${OPENWEATHER_CITY_ID:-}" && ! "$OPENWEATHER_CITY_ID" =~ ^[0-9]+$ ]]; then
    CFG_CITY="$OPENWEATHER_CITY_ID"
fi

# Unit handling (Open-Meteo has no kelvin — "standard" falls back to celsius).
UNIT="${OPENWEATHER_UNIT:-metric}"
case "$UNIT" in
    imperial) TEMP_UNIT="fahrenheit"; WIND_UNIT="mph"; UNIT_SYM="°F" ;;
    *)        TEMP_UNIT="celsius";    WIND_UNIT="kmh"; UNIT_SYM="°C" ;;
esac

# --- WMO weather-code → glyph / colour / description (jq side) ---------------
# These mirror the icon set the rest of the rice already uses.
read -r -d '' JQ_DEFS <<'JQEOF'
def wcat(c):
  if   c <= 1  then "clear"
  elif c <= 3  then "cloud"
  elif c <= 48 then "fog"
  elif c <= 67 then "rain"
  elif c <= 77 then "snow"
  elif c <= 82 then "rain"
  elif c <= 86 then "snow"
  else "storm" end;
def icon(c; day):
  wcat(c) as $k
  | if   $k == "clear" then (if day == 1 then "" else "" end)
    elif $k == "cloud" then ""
    elif $k == "fog"   then "󰖑"
    elif $k == "rain"  then "󰖗"
    elif $k == "snow"  then ""
    else "" end;
def hex(c):
  wcat(c) as $k
  | if   $k == "clear" then "#f9e2af"
    elif $k == "cloud" then "#bac2de"
    elif $k == "fog"   then "#84afdb"
    elif $k == "rain"  then "#74c7ec"
    elif $k == "snow"  then "#cdd6f4"
    else "#f9e2af" end;
def desc(c):
  {"0":"Clear","1":"Mainly Clear","2":"Partly Cloudy","3":"Overcast",
   "45":"Fog","48":"Fog","51":"Drizzle","53":"Drizzle","55":"Drizzle",
   "56":"Freezing Drizzle","57":"Freezing Drizzle","61":"Light Rain",
   "63":"Rain","65":"Heavy Rain","66":"Freezing Rain","67":"Freezing Rain",
   "71":"Light Snow","73":"Snow","75":"Heavy Snow","77":"Snow Grains",
   "80":"Light Showers","81":"Showers","82":"Heavy Showers",
   "85":"Snow Showers","86":"Snow Showers","95":"Thunderstorm",
   "96":"Thunderstorm","99":"Thunderstorm"}[c|tostring] // "Unknown";
JQEOF

# -----------------------------------------------------------------------------
write_dummy_data() {
    local final_json="["
    for i in {0..4}; do
        local fd; fd=$(date -d "+$i days")
        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"$(date -d "$fd" '+%a')\",
            \"day_full\": \"$(date -d "$fd" '+%A')\",
            \"date\": \"$(date -d "$fd" '+%d %b')\",
            \"max\": \"0\", \"min\": \"0\", \"feels_like\": \"0\",
            \"wind\": \"0\", \"humidity\": \"0\", \"pop\": \"0\",
            \"icon\": \"\", \"hex\": \"#cdd6f4\", \"desc\": \"No API Key\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"current_temp\": \"0\", \"current_icon\": \"\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

# Resolve LAT/LON/CITY into globals. Cached so we don't hit ipinfo every run.
resolve_location() {
    LAT=""; LON=""; CITY=""

    if [[ -n "$CFG_CITY" ]]; then
        local enc geo
        enc=$(printf '%s' "$CFG_CITY" | jq -sRr @uri)
        geo=$(curl -sf --max-time 10 "https://geocoding-api.open-meteo.com/v1/search?name=${enc}&count=1&format=json")
        LAT=$(echo "$geo" | jq -r '.results[0].latitude // empty' 2>/dev/null)
        LON=$(echo "$geo" | jq -r '.results[0].longitude // empty' 2>/dev/null)
        CITY=$(echo "$geo" | jq -r '.results[0].name // empty' 2>/dev/null)
    fi

    if [[ -z "$LAT" || -z "$LON" ]] && [ -f "$loc_cache" ]; then
        LAT=$(jq -r '.lat // empty' "$loc_cache" 2>/dev/null)
        LON=$(jq -r '.lon // empty' "$loc_cache" 2>/dev/null)
        CITY=$(jq -r '.city // empty' "$loc_cache" 2>/dev/null)
    fi

    if [[ -z "$LAT" || -z "$LON" ]]; then
        local ip loc
        ip=$(curl -sf --max-time 10 "https://ipinfo.io/json")
        loc=$(echo "$ip" | jq -r '.loc // empty' 2>/dev/null)
        LAT="${loc%,*}"; LON="${loc#*,}"
        CITY=$(echo "$ip" | jq -r '.city // empty' 2>/dev/null)
    fi

    if [[ -n "$LAT" && -n "$LON" ]]; then
        jq -n --arg lat "$LAT" --arg lon "$LON" --arg city "$CITY" \
            '{lat:$lat, lon:$lon, city:$city}' > "$loc_cache"
    fi
}

get_data() {
    resolve_location
    if [[ -z "$LAT" || -z "$LON" ]]; then
        [ -f "$json_file" ] || write_dummy_data
        return
    fi

    local url raw
    url="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}"
    url+="&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
    url+="&hourly=temperature_2m,weather_code,relative_humidity_2m"
    url+="&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max"
    url+="&timezone=auto&forecast_days=5&temperature_unit=${TEMP_UNIT}&wind_speed_unit=${WIND_UNIT}"

    raw=$(curl -sf --max-time 15 "$url")

    # Network/API failure → keep the last good cache; only dummy if nothing cached.
    if [[ -z "$raw" ]] || [[ "$(echo "$raw" | jq -r 'has("current")' 2>/dev/null)" != "true" ]]; then
        [ -f "$json_file" ] || write_dummy_data
        return
    fi

    local out
    out=$(echo "$raw" | jq -c "
        ${JQ_DEFS}
        . as \$r
        | \$r.current as \$cur
        | {
            current_temp: (\$cur.temperature_2m | round | tostring),
            current_icon: icon(\$cur.weather_code; \$cur.is_day),
            current_hex:  hex(\$cur.weather_code),
            forecast: [
              \$r.daily.time | to_entries[] | .key as \$i | .value as \$date
              | (\$date | strptime(\"%Y-%m-%d\") | mktime | gmtime) as \$bt
              | ([ \$r.hourly.time | to_entries[] | select(.value | startswith(\$date)) | .key ]) as \$hidx
              | {
                  id:         (\$i | tostring),
                  day:        (\$bt | strftime(\"%a\")),
                  day_full:   (\$bt | strftime(\"%A\")),
                  date:       (\$bt | strftime(\"%d %b\")),
                  max:        (\$r.daily.temperature_2m_max[\$i]   | round | tostring),
                  min:        (\$r.daily.temperature_2m_min[\$i]   | round | tostring),
                  feels_like: (\$r.daily.apparent_temperature_max[\$i] | round | tostring),
                  wind:       (\$r.daily.wind_speed_10m_max[\$i]   | round | tostring),
                  humidity:   (if (\$hidx | length) > 0
                               then ([ \$hidx[] as \$h | \$r.hourly.relative_humidity_2m[\$h] ] | add / (\$hidx | length) | round)
                               else 0 end | tostring),
                  pop:        ((\$r.daily.precipitation_probability_max[\$i] // 0) | round | tostring),
                  icon:       icon(\$r.daily.weather_code[\$i]; 1),
                  hex:        hex(\$r.daily.weather_code[\$i]),
                  desc:       desc(\$r.daily.weather_code[\$i]),
                  hourly: [ \$hidx[] as \$h | {
                      time: (\$r.hourly.time[\$h] | split(\"T\")[1]),
                      temp: (\$r.hourly.temperature_2m[\$h] | round | tostring),
                      icon: icon(\$r.hourly.weather_code[\$h]; 1),
                      hex:  hex(\$r.hourly.weather_code[\$h])
                  } ]
                }
            ]
          }
    " 2>/dev/null)

    if [[ -n "$out" && "$out" != "null" ]]; then
        echo "$out" > "$json_file"
    elif [ ! -f "$json_file" ]; then
        write_dummy_data
    fi
}

# --- MODE HANDLING -----------------------------------------------------------
case "$1" in
    --getdata)
        get_data
        ;;

    --json)
        CACHE_LIMIT=900          # 15 min for valid data
        PENDING_RETRY_LIMIT=3600 # 1 h for dummy/failed state
        if [ -f "$json_file" ]; then
            diff=$(( $(date +%s) - $(stat -c %Y "$json_file") ))
            if grep -q '"desc": "No API Key"' "$json_file"; then
                if [ "$diff" -gt "$PENDING_RETRY_LIMIT" ]; then touch "$json_file"; get_data & fi
            else
                if [ "$diff" -gt "$CACHE_LIMIT" ]; then touch "$json_file"; get_data & fi
            fi
            cat "$json_file"
        else
            get_data
            cat "$json_file"
        fi
        ;;

    --view-listener)
        [ -f "$view_file" ] || echo "0" > "$view_file"
        tail -F "$view_file"
        ;;

    --nav)
        [ -f "$view_file" ] || echo "0" > "$view_file"
        current=$(cat "$view_file"); max_idx=4
        if [[ "$2" == "next" && "$current" -lt "$max_idx" ]]; then
            echo "$((current + 1))" > "$view_file"
        elif [[ "$2" == "prev" && "$current" -gt 0 ]]; then
            echo "$((current - 1))" > "$view_file"
        fi
        ;;

    --icon)
        jq -r '.forecast[0].icon' "$json_file" 2>/dev/null
        ;;

    --temp)
        t=$(jq -r '.forecast[0].max' "$json_file" 2>/dev/null)
        echo "${t}${UNIT_SYM}"
        ;;

    --hex)
        jq -r '.forecast[0].hex' "$json_file" 2>/dev/null
        ;;

    --current-icon)
        icon=$(jq -r '.current_icon // empty' "$json_file" 2>/dev/null)
        if [[ -z "$icon" || "$icon" == "null" ]]; then get_data; icon=$(jq -r '.current_icon' "$json_file" 2>/dev/null); fi
        echo "$icon"
        ;;

    --current-temp)
        t=$(jq -r '.current_temp // empty' "$json_file" 2>/dev/null)
        if [[ -z "$t" || "$t" == "null" ]]; then get_data; t=$(jq -r '.current_temp' "$json_file" 2>/dev/null); fi
        echo "${t}${UNIT_SYM}"
        ;;

    --current-hex)
        hex=$(jq -r '.current_hex // empty' "$json_file" 2>/dev/null)
        if [[ -z "$hex" || "$hex" == "null" ]]; then get_data; hex=$(jq -r '.current_hex' "$json_file" 2>/dev/null); fi
        echo "$hex"
        ;;
esac
