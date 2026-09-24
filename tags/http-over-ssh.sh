days=${1:-1}
lifetime=$(( days * 86400 ))

# Find ancestor sshd-session processes (OpenSSH 9.8+)
pids=$(
  pid=$$
  while [ "$pid" -gt 1 ]; do
    line=$(ps -o comm=,pid=,ppid= -p "$pid")
    echo "$line"
    pid=${line##* }
  done | awk '$1 == "sshd-session" { printf "pid=%s,\n", $2 }'
)
if [ -z "$pids" ]; then
  echo "not an ssh session" >&2
  exit 1
fi

secret=$(cat /var/keys/http-over-ssh.token)

while :; do
  # Find ports allocated to sshd-session
  ports=$(sudo -n ss --listening --numeric --tcp --processes --no-header \
            | grep -F "$pids" \
            | awk '{ print $4 }' | awk -F: '{ print $NF }' \
            | sort -un)
  if [ -z "$ports" ]; then
    echo "no forwarded port, use ssh -R 0:localhost:PORT" >&2
    exit 1
  fi

  # For each port, print the URL with token and expiry
  expires=$(( $(date +%s) + lifetime ))
  for port in $ports; do
    token=$(printf '%s %s %s' "$expires" "$port" "$secret" \
              | openssl md5 -binary \
              | openssl base64 \
              | tr +/ -_ | tr -d =)
    echo "https://$token,$expires:@p$port.ssh.luffy.cx/"
  done

  sleep $(( lifetime / 2 ))
done
