#!/usr/bin/env bash
set -e

# Install packages
sudo apt-get update -y
sudo apt-get install -y curl unzip

# Download Vault into some temporary directory
curl -L "${vault_download_url}" > /tmp/vault.zip

# Unzip it
cd /tmp
sudo unzip vault.zip
sudo mv vault /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault
sudo chown root:root /usr/local/bin/vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

# Setup the configuration
cat <<EOF >/tmp/vault-config
${vault_config}
EOF
sudo mv /tmp/vault-config /usr/local/etc/vault-config.json

# Setup the init script
cat <<EOF >/tmp/upstart
description "Vault server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

script
  if [ -f "/etc/service/vault" ]; then
    . /etc/service/vault
  fi

  exec /usr/local/bin/vault server \
    -config="/usr/local/etc/vault-config.json" \
    >>/var/log/vault.log 2>&1
end script
EOF
sudo mv /tmp/upstart /etc/init/vault.conf

# Extra install steps (if any)
${vault_extra_install}

# Download Consul into some temporary directory
curl -L "${consul_download_url}" > /tmp/consul.zip

# Unzip it
cd /tmp
sudo unzip consul.zip
sudo mv consul /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul

# Setup the configuration
cat <<EOF >/tmp/consul-config
${consul_config}
EOF
IP_ADDRESS=$(curl http://instance-data/latest/meta-data/local-ipv4)
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" /tmp/consul-config
sudo mv /tmp/consul-config /usr/local/etc/consul-config.json

# Setup the init script
cat <<EOF >/tmp/upstart
description "Consul server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

script
  if [ -f "/etc/service/consul" ]; then
    . /etc/service/consul
  fi

  exec /usr/local/bin/consul agent  \
    -config-file="/usr/local/etc/consul-config.json" \
    >>/var/log/consul.log 2>&1
end script
EOF
sudo mv /tmp/upstart /etc/init/consul.conf

# Extra install steps (if any)
${consul_extra_install}

# Start Consul
sudo start consul

# Start Vault
sudo start vault
