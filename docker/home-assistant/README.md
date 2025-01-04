# Hone Assistant

## Setup

Run
```
cp example.env .env
```

### Prepare mosquitto

```
mkdir -p appdata/mosquitto/config
cp templates/mosquitto.conf appdata/mosquitto/config/mosquitto.conf

docker compose up -d mosquitto
docker exec -it mosquitto sh

mosquitto_passwd -c /mosquitto/pwfile/pwfile zigbee2mqtt
mosquitto_passwd /mosquitto/pwfile/pwfile homeassistant
chown mosquitto:mosquitto /mosquitto/pwfile/pwfile
chown mosquitto:mosquitto /mosquitto/config/mosquitto.conf
chmod 644 /mosquitto/config/mosquitto.conf
exit
```

Then, edit `appdata/mosquitto/config/mosquitto.conf`
- Set `allow_anonymous` to false
- Uncomment the password file
- `docker compose down`
