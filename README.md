# Weather forecast widget
I did it for Termux widget: https://github.com/gardockt/termux-terminal-widget \
But you can use it everywhere with bash.

# How to use

## First install requirements
`jq` `bc` `wego`

## Create a 'ow_key' file with a free Open Weather API key
Create an account and get a free API: https://openweathermap.org/api \
Create a file called 'ow_key' and place your key in it.

## Then run
bash widget.sh [LOCATION]

Examle usage:
`bash widget.sh Toronto`
