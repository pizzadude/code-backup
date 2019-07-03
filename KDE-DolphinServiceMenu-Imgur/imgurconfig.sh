#!/usr/bin/env bash

SCRIPTNAME=$(basename "$0")
CONFIG_FILE="${HOME}/.config/imgurrc"
SERVICE_PATH="$(kf5-config --path services | cut -d':' -f1)ServiceMenus"
ICON_PATH="$(kf5-config --path icon | cut -d':' -f1)hicolor/scalable/apps"

case "$1" in
anon)
    read -rp "client id: " client_id
    echo "$client_id" > "$CONFIG_FILE"
    echo "the config file was created successfully"
    ;;

user)
    read -rp "client id: " client_id
    read -rp "client secret: " client_secret
    xdg-open "https://api.imgur.com/oauth2/authorize?client_id=${client_id}&response_type=token" \
        &>/dev/null

    read -rp "insert the full url from browser (https://imgur.com#access_token=...): " url
    access_token=$(echo "$url" | cut -d'&' -f1 | sed -r 's/^.*=//g')
    refresh_token=$(echo "$url" | cut -d'&' -f4 | sed -r 's/^.*=//g')

    {
        echo "$client_id"
        echo "$client_secret"
        echo "$refresh_token"
        echo "$access_token"
    } > "$CONFIG_FILE"

    echo "the config file was created successfully"
    ;;

refresh)
    client_id=$(sed -n 1p "$CONFIG_FILE")
    client_secret=$(sed -n 2p "$CONFIG_FILE")
    refresh_token=$(sed -n 3p "$CONFIG_FILE")

    access_token=$(curl --silent -X POST \
        -F "client_id=$client_id" \
        -F "client_secret=$client_secret" \
        -F "grant_type=refresh_token" \
        -F "refresh_token=$refresh_token" \
        https://api.imgur.com/oauth2/token \
        | jq -r '.access_token')

    sed -i '$d' "$CONFIG_FILE"
    echo "$access_token" >> "$CONFIG_FILE"

    echo "the config file was updated successfully"
    ;;

install)
    [ ! -d "$SERVICE_PATH" ] && mkdir --verbose --parents "$SERVICE_PATH"
    [ ! -d "$ICON_PATH" ] && mkdir --verbose --parents "$ICON_PATH"

    if [ ! -f "./imgur.desktop" ] || [ ! -f "./dsm-imgur" ]; then
        echo "error: no files to install"
        exit 1
    fi
    if [ ! -f "/usr/share/icons/hicolor/scalable/apps/kipi-imgur.svgz" ]; then
        if ! install --verbose -m 644 ./kipi-imgur.svgz "$ICON_PATH" 2>/dev/null; then
            echo "error: no icon file found"
        fi
    fi
    install --verbose -m 644 ./imgur.desktop "$SERVICE_PATH"
    sudo install --verbose -m 755 ./dsm-imgur /usr/bin/
    ;;

uninstall)
    rm --verbose "${SERVICE_PATH}/imgur.desktop"
    rm --verbose "${HOME}/.config/imgurrc"
    rm --verbose "${ICON_PATH}/kipi-imgur.svgz" 2>/dev/null
    sudo rm --verbose /usr/bin/dsm-imgur
    ;;

*|-h)
    echo "usage:"
    echo "  $SCRIPTNAME anon"
    echo "  $SCRIPTNAME user"
    echo "  $SCRIPTNAME refresh"
    echo
    echo "  $SCRIPTNAME install"
    echo "  $SCRIPTNAME uninstall"
    echo
    echo "settings:"
    echo "  anon       anonymous upload without an user account"
    echo
    echo "  user       upload with an user account"
    echo "             (here you get an 'access token' that expires after some time)"
    echo "  refresh    whenever your 'access token' expires, just re-run this "
    echo "  install    install the service"
    echo "  uninstall  uninstall the service"
esac
