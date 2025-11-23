#!/bin/bash

echo "Trying different SSH methods..."

echo "1. Testing with Coolify key..."
timeout 10 ssh -v -i ~/.ssh/id_ed25519_coolify -o ConnectTimeout=10 root@46.62.206.47 'echo "Connected!"' 2>&1 | head -20

echo
echo "2. Testing with default RSA key..."  
timeout 10 ssh -v -i ~/.ssh/id_rsa -o ConnectTimeout=10 root@46.62.206.47 'echo "Connected!"' 2>&1 | head -20

echo
echo "3. Testing basic connectivity..."
ping -c 3 46.62.206.47

echo
echo "4. Testing if SSH port is open..."
nc -zv 46.62.206.47 22

echo
echo "5. Testing HTTP ports..."
nc -zv 46.62.206.47 80
nc -zv 46.62.206.47 443

echo
echo "If SSH hangs but ping works = Server is overloaded or SSH daemon crashed"
echo "If ping fails = Network/server completely down"
echo "Use Hetzner Console for direct access!"