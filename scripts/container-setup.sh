#!/bin/sh

print_breaker() {
  echo "-----------------------------------------------"
}
# #####################################################################
# Step 1: set up timezone
if [ -z "$TZ" ]; then
  echo "TZ environment variable not set. Using default: UTC"
else
  echo "Setting timezone to $TZ"
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
  echo $TZ > /etc/timezone
fi

echo "Starting Cloudflare DDNS container: [$(date)]"
print_breaker
# #####################################################################
echo "Performing basic container parameter check..."
# Step 2: Check API keys
if [ -f "$API_KEY_FILE" ]; then
  API_KEY=$(cat "$API_KEY_FILE")
fi
if [ -z "$API_KEY" ]; then
  echo "Please enter valid API_KEY env variable or API_KEY_FILE secret"
  exit 1
fi
echo "API Key  ---  OK"
if [ -f "$SECRET_API_KEY_FILE" ]; then
  SECRET_API_KEY=$(cat "$SECRET_API_KEY_FILE")
fi
if [ -z "$SECRET_API_KEY" ]; then
  echo "Please enter valid SECRET_API_KEY env variable or SECRET_API_KEY_FILE secret"
  exit 1
fi
echo "SECRET API Key  ---  OK"
# #####################################################################
# Step 3: Check domain
if [ -f "$DOMAIN_FILE" ]; then
  DOMAIN=$(cat "$DOMAIN_FILE")
fi
if [ -z "$DOMAIN" ]; then
  echo "Please enter valid DOMAIN env variable or DOMAIN_FILE secret"
  exit 1
fi
echo "Domain  ---  OK"
if [ -f "$SUBDOMAIN_FILE" ]; then
  SUBDOMAIN=$(cat "$SUBDOMAIN_FILE")
fi
if [ -z "$SUBDOMAIN" ]; then
  echo "Please enter valid SUBDOMAIN env variable or SUBDOMAIN_FILE secret"
  exit 1
fi
echo "Subdomain  ---  OK"
# #####################################################################
# Step 4: Record type
if [ "$RECORD_TYPE" == "A" ]; then
  echo "Record type to be updated: A (IPv4)"
elif [ "$RECORD_TYPE" == "AAAA" ]; then
  echo "Record type to be updated: AAAA (IPv6)"
else
  RECORD_TYPE="A"
  echo "Unknown record type, assuming A-record (IPv4)"
fi
# #####################################################################
# Step 5: validate
echo -n "Validating Porkbun access"
AUTH=$(curl -sSL -X POST "$ENDPOINT/ping"\
  --data "{\"secretapikey\":\"$SECRET_API_KEY\",\"apikey\":\"$API_KEY\"}")

if [ $(echo "$AUTH" | jq -r '.status') != "SUCCESS" ]; then
  echo "Authentication failed. Please check your API keys."
  exit 1
else
  echo "  ---  OK"
fi

echo -n "Validating Porkbun dns record details"
RECORD=$(curl -sSL -X POST "$ENDPOINT/dns/retrieveByNameType/$DOMAIN/$RECORD_TYPE/$SUBDOMAIN"\
  --data "{\"secretapikey\":\"$SECRET_API_KEY\",\"apikey\":\"$API_KEY\"}")

if [ $(echo "$RECORD" | jq -r '.status') != "SUCCESS" ]; then
  echo "Record not found. Please check your domain and subdomain."
  exit 1
else
  ZONE_ID=$(echo "$RECORD" | jq -r '.records[0].id')
  TTL=$(echo "$RECORD" | jq -r '.records[0].ttl')
  echo "  ---  OK"
fi
# #####################################################################
# Step 6: Write config file
touch /old_record_ip
echo "SECRET_API_KEY=\"$SECRET_API_KEY\"" > /config.sh
echo "API_KEY=\"$API_KEY\"" >> /config.sh
echo "DOMAIN=\"$DOMAIN\"" >> /config.sh
echo "SUBDOMAIN=\"$SUBDOMAIN\"" >> /config.sh
echo "RECORD_TYPE=\"$RECORD_TYPE\"" >> /config.sh
echo "ZONE_ID=\"$ZONE_ID\"" >> /config.sh
echo "TTL=\"$TTL\"" >> /config.sh
# #####################################################################
print_breaker
echo "Container setup complete. Starting DDNS updater..."
print_breaker
