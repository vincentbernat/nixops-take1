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

  # For each port, print the signed URL
  for port in $ports; do
    label=$(http-over-ssh-auth -secret /var/keys/http-over-ssh.token sign "$port" "$lifetime")
    echo "https://$label.ssh.luffy.cx/"
  done

  sleep $(( lifetime / 2 ))
done
