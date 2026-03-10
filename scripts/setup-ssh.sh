#!/usr/bin/env bash
set -euo pipefail

# setup-ssh.sh - Konfigurerar SSH-anslutning till Hetzner Coolify-server
# Detta script hjälper dig att sätta upp SSH-anslutning från början

SERVER_IP="46.62.206.47"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_coolify"
SSH_CONFIG_PATH="$HOME/.ssh/config"

echo "🔐 SSH Setup Script för Hetzner Coolify"
echo "========================================"
echo ""

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Steg 1: Kontrollera om SSH-nyckel finns
info "Steg 1: Kontrollerar SSH-nyckel..."

if [ -f "$SSH_KEY_PATH" ]; then
    info "SSH-nyckel finns redan: $SSH_KEY_PATH"
    echo "  Fingerprint: $(ssh-keygen -lf "$SSH_KEY_PATH" 2>/dev/null | awk '{print $2}')"
    echo ""
    read -p "Vill du skapa en ny nyckel? (ja/nej): " -r
    if [[ $REPLY =~ ^[Jj]a$ ]]; then
        warn "Detta kommer att skriva över den befintliga nyckeln!"
        read -p "Är du säker? (ja/nej): " -r
        if [[ $REPLY =~ ^[Jj]a$ ]]; then
            rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
            CREATE_KEY=true
        else
            CREATE_KEY=false
        fi
    else
        CREATE_KEY=false
    fi
else
    CREATE_KEY=true
fi

# Skapa ny SSH-nyckel om nödvändigt
if [ "$CREATE_KEY" = true ]; then
    info "Skapar ny SSH-nyckel..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "coolify-hetzner-$(date +%Y%m%d)" -N ""
    info "SSH-nyckel skapad: $SSH_KEY_PATH"
    echo ""
fi

# Steg 2: Visa publika nyckel
info "Steg 2: Publika nyckel (kopiera denna till servern):"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$SSH_KEY_PATH.pub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
warn "VIKTIGT: Du måste lägga till denna publika nyckel på servern!"
echo ""
echo "Alternativ 1: Via Hetzner Cloud Console (om SSH inte fungerar)"
echo "  1. Gå till https://console.hetzner.cloud"
echo "  2. Välj din server"
echo "  3. Klicka på 'Console' för direktåtkomst"
echo "  4. Kör: nano ~/.ssh/authorized_keys"
echo "  5. Klistra in den publika nyckeln ovan"
echo ""
echo "Alternativ 2: Via SSH (om du redan har åtkomst)"
echo "  ssh root@$SERVER_IP"
echo "  echo '$(cat "$SSH_KEY_PATH.pub")' >> ~/.ssh/authorized_keys"
echo ""
read -p "Tryck Enter när du har lagt till nyckeln på servern..."

# Steg 3: Konfigurera SSH config
info "Steg 3: Konfigurerar SSH config..."

# Skapa .ssh-katalog om den inte finns
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Kontrollera om config redan innehåller vår host
if [ -f "$SSH_CONFIG_PATH" ] && grep -q "Host tha" "$SSH_CONFIG_PATH"; then
    warn "SSH config innehåller redan 'tha' host"
    echo ""
    read -p "Vill du uppdatera konfigurationen? (ja/nej): " -r
    if [[ ! $REPLY =~ ^[Jj]a$ ]]; then
        info "Behåller befintlig konfiguration"
        SKIP_CONFIG=true
    else
        SKIP_CONFIG=false
        # Ta bort gammal konfiguration
        sed -i.bak '/^Host tha$/,/^$/d' "$SSH_CONFIG_PATH"
        sed -i.bak '/^Host coolify-tha$/,/^$/d' "$SSH_CONFIG_PATH"
    fi
else
    SKIP_CONFIG=false
fi

# Lägg till ny konfiguration
if [ "$SKIP_CONFIG" = false ]; then
    info "Lägger till SSH config..."
    
    cat >> "$SSH_CONFIG_PATH" <<EOF

# Hetzner Coolify Server
Host tha
    HostName $SERVER_IP
    User root
    IdentityFile $SSH_KEY_PATH
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host coolify-tha
    HostName $SERVER_IP
    User root
    IdentityFile $SSH_KEY_PATH
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

    chmod 600 "$SSH_CONFIG_PATH"
    info "SSH config uppdaterad ✓"
    echo ""
fi

# Steg 4: Testa anslutning
info "Steg 4: Testar SSH-anslutning..."

# Testa ping först
if ! ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
    error "Servern svarar inte på ping"
    echo "Kontrollera att servern är igång i Hetzner Cloud Console"
    exit 1
fi

# Testa SSH
echo "Försöker ansluta..."
if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new root@"$SERVER_IP" 'echo "SSH OK"' 2>/dev/null; then
    info "✅ SSH-anslutning fungerar!"
    echo ""
    
    # Testa med alias
    if ssh -o ConnectTimeout=5 tha 'echo "SSH alias OK"' &>/dev/null; then
        info "✅ SSH alias 'tha' fungerar!"
    else
        warn "SSH alias 'tha' fungerar inte ännu, men direktanslutning fungerar"
    fi
else
    error "SSH-anslutning misslyckades"
    echo ""
    echo "Felsökning:"
    echo "  1. Kontrollera att du har lagt till den publika nyckeln på servern"
    echo "  2. Testa manuellt: ssh -i $SSH_KEY_PATH root@$SERVER_IP"
    echo "  3. Testa med verbose: ssh -vvv -i $SSH_KEY_PATH root@$SERVER_IP"
    echo "  4. Om du har root-lösenord: ssh root@$SERVER_IP (lösenordsbaserad)"
    echo "  4. Använd Hetzner Console för direktåtkomst om SSH inte fungerar"
    exit 1
fi

echo ""
info "✅ SSH-setup klar!"
echo ""
echo "💡 Du kan nu använda:"
echo "  • ssh tha                    # Snabb anslutning"
echo "  • ssh coolify-tha            # Fullständigt namn"
echo "  • ./scripts/quick-ssh.sh     # Snabb status"
echo "  • VS Code Remote-SSH → tha   # Remote development"
echo ""

