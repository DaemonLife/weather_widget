#!/bin/bash

# --- HOW TO USE ---
#
# Requirements: jq bc wego
# Usage: bash widget.sh [LOCATION]
#
# Examle usage:
# bash widget.sh Toronto

# --- Constants ---

CITY="$1"
OW_KEY=$(cat ow_key) # you need create 'ow_key' file with free Open Weather API key
JSON_DATA=$(wego --owm-api-key $OW_KEY -f json -d 2 -l $1)

# --- Online status check ---

if [ $? -eq 0 ]; then
  printf "%s\n" "$JSON_DATA" >.tmp_widgetw.txt
else
  echo "(Offline) "
  JSON_DATA=$(cat .tmp_widgetw.txt) # read old data
fi

# --- Define ASCII art for different weather conditions ---

get_weather_art() {
  local desc_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$desc_lower" in
  *"sunny" | *"clear"*)
    echo "  \   /  "
    echo "   .-.   "
    echo "― (   ) ―"
    echo "   \`-’   "
    echo "  /   \  "
    ;;
  *"light rain sho"* | *"patchy rain ne"*)
    echo "_\`/\"\".-."
    echo ",\_(   ). "
    echo "/(___(__)"
    echo "  ‘ ‘ ‘ ‘"
    echo " ‘ ‘ ‘ ‘ "
    ;;
  *"partly cloudy"* | *"few clouds"* | *"scattered clouds"* | *"broken clouds"*)
    echo "  \  /    "
    echo "_ /\"\".-."
    echo "  \_(   )."
    echo " /(___(__)"
    echo "          "
    ;;
  *"cloudy"* | *"overcast"*)
    echo "    .--.   "
    echo " .-(    ). "
    echo "(___.__)__)"
    echo "           "
    echo "           "
    ;;
  *"light drizzle"* | *"light rain"*)
    echo "  .-.   "
    echo " (   ). "
    echo "(___(__)"
    echo " ‘ ‘ ‘ ‘"
    echo "‘ ‘ ‘ ‘ "
    ;;
  *"fog" | *"mist"*)
    echo "_ - _ - _ -  "
    echo "   _ - _ - _ "
    echo "  _ - _ - _ -"
    echo "             "
    echo "             "
    ;;
  *"patchy light r"* | *"thundery outbr"*)
    echo "_\`/\"\".-."
    echo " ,\_(   ). "
    echo "  /(___(__)"
    echo "   ⚡️‘‘⚡️‘‘"
    echo "   ‘ ‘ ‘ ‘ "
    ;;
  *)
    # Default art for unknown conditions
    echo -e "  _   "
    echo -e " ( \`) "
    echo -e "(__._)"
    echo -e " ???  "
    echo "             "
    ;;
  esac
  echo -e "$art" | sed "1d"
}

# --- Creating current weather variables ---

CURRENT_DESC=$(echo "${JSON_DATA}" | jq -r '.Current.Desc')
# CURRENT_TEMP=$(echo "${JSON_DATA}" | jq -r '.Current.TempC | round')
CURRENT_FEELS_LIKE=$(echo "${JSON_DATA}" | jq -r '.Current.FeelsLikeC | round')

CURRENT_WIND=$(echo "${JSON_DATA}" | jq -r '.Current.WindspeedKmph | round')
CURRENT_WIND=$(echo "scale=1; $CURRENT_WIND / 3.8" | bc)       # km/h to m/s int
CURRENT_WIND=$(echo "scale=0; ($CURRENT_WIND + 0.5) / 1" | bc) # round
CURRENT_HUMIDITY=$(echo "${JSON_DATA}" | jq -r '.Current.Humidity')
ASTRO_SUNRISE=$(echo "${JSON_DATA}" | jq -r '.Forecast[0].Astronomy.Sunrise' | xargs -I {} date -d {} +"%H:%M")
ASTRO_SUNSET=$(echo "${JSON_DATA}" | jq -r '.Forecast[0].Astronomy.Sunset' | xargs -I {} date -d {} +"%H:%M")
CURRENT_PRECIP=$(echo "${JSON_DATA}" | jq -r '.Current.PrecipM')
CURRENT_PRECIP=$(echo "scale=1; ($CURRENT_PRECIP * 1000)/1" | bc | sed 's/^\./0./') # m to mm float
# Nice look precip format
if (($(echo "$CURRENT_PRECIP == 0" | bc -l))); then
  CURRENT_PRECIP="No precip"
else
  CURRENT_PRECIP=$(echo $CURRENT_PRECIP | sed 's/.0$//')
  CURRENT_PRECIP="Precip ${CURRENT_PRECIP} mm"
fi
# Nice look for f temp
if (($CURRENT_FEELS_LIKE > 0)); then
  CURRENT_FEELS_LIKE="+${CURRENT_FEELS_LIKE}" # add + for positive temperature
fi

# --- Create art array ---

art_array=()
while IFS= read -r line; do
  art_array+=("$line")
done < <(get_weather_art "${CURRENT_DESC}")

# --- Display current conditions with local ASCII art ---

echo "${art_array[0]} ${CURRENT_DESC^} in ${CITY}"
echo "${art_array[1]} ${CURRENT_PRECIP}, feels ${CURRENT_FEELS_LIKE}°C"
echo "${art_array[2]} Humidity ${CURRENT_HUMIDITY}%, wind ${CURRENT_WIND} m/s"
echo "${art_array[3]} Sun from ${ASTRO_SUNRISE} to ${ASTRO_SUNSET}"
arr_len=${#art_array[@]}
for ((i = 4; i < arr_len; i++)); do
  echo "${art_array[i]}"
done

# --- Print hourly forecast table ---

echo "Hs | Tem | Pre | Wi | Description"
echo "—————————————————————————————————"

# Save all days info from json data
FORECAST_SLOTS=$(echo "${JSON_DATA}" | jq '.Forecast | map(.Slots) | add')
# Get the necessary info only from 1-8 elements from the forecast
echo "${FORECAST_SLOTS}" | jq -r '.[1:8] | .[] | "\(.Time) \(.TempC | round) \(.WindspeedKmph | round) \(.PrecipM) \(.Desc)"' | while read -r datetime temp wind precip desc; do

  # Replace null by "0", "-"...
  temp=${temp:-"-"}
  wind=${wind:-"-"}
  precip=${precip:-"0"}
  desc=${desc:-"No information"}

  wind=$(echo "scale=1; $wind/3.8" | bc)                              # km/h to m/s int
  wind=$(echo "scale=0; ($wind+0.5)/1" | bc)                          # round
  precip=$(echo "scale=1; ($precip * 1000)/1" | bc | sed 's/^\./0./') # m to mm, float, round
  precip=$(echo $precip | sed 's/.0$//')

  formatted_time=$(date -d "$datetime" +"%H")

  if (($temp > 0)); then
    temp="+${temp}" # add + for positive temperature
  fi

  # Description max lenght
  max_length=24
  if [ ${#desc} -gt $max_length ]; then
    desc="${desc:0:max_length-1}…"
  fi

  # String output
  printf "%-2s | %-3s | %-3s | %-2s | %s\n" "$formatted_time" "$temp" "$precip" "$wind" "${desc^}"
done
echo "—————————————————————————————————" # end of the table

# --- Print my notes ---

#echo && cat $HOME/Notes/todo.md
