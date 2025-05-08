#!/usr/bin/env bash

set -e

#======================#
#=== CONFIG SECTION ===#
#======================#
NOCKCHAIN_DIR="$HOME/nockchain"
RUST_INSTALL_URL="https://sh.rustup.rs"
NOCKCHAIN_REPO="https://github.com/zorp-corp/nockchain"
LOG_FILE="miner.log"
MINER_SCRIPT="run-miner.sh"
NODE_CONFIG_FILE="$NOCKCHAIN_DIR/node_wallet.key"
USE_MAINNET=false
INSTALL_HETRIX=true

# === YOUR EMBEDDED WALLET PUBLIC KEY ===
EMBEDDED_WALLET_KEY="0x1.88a5.28a2.fd8d.6dd6.c76f.242e.1495.15b3.8b42.5fb5.d882.ceaa.7406.140f.216c.ebf3.3388.6151.8ffe.1ee8.d23e.f2fc.2cdd.b4d0.53e6.4dee.61f6.ba79.6260.f634.55f3.b01d.c620.9129.abd1.8e74.5aac.b59b.f69a.2478.b6aa.b0c5.540f.ea8d.1d8a.9459.4be5.6564"

#===============================#
#=== SYSTEM & DEP SETUP ========#
#===============================#
echo "🔧 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing dependencies..."
sudo apt install -y build-essential curl git pkg-config libssl-dev tmux clang libclang-dev libz3-dev python3-pygments llvm llvm-dev llvm-runtime

#===========================#
#=== INSTALL RUST TOOLCHAIN ===#
#===========================#
if ! command -v cargo &> /dev/null; then
    echo "🦀 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf "$RUST_INSTALL_URL" | sh -s -- -y
    export PATH="$HOME/.cargo/bin:$PATH"
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi

#===================================#
#=== CLONE or UPDATE NOCKCHAIN ====#
#===================================#
if [ -d "$NOCKCHAIN_DIR" ]; then
    echo "📁 NockChain exists. Pulling latest changes..."
    cd "$NOCKCHAIN_DIR"
    git pull
else
    echo "📥 Cloning NockChain..."
    git clone "$NOCKCHAIN_REPO" "$NOCKCHAIN_DIR"
    cd "$NOCKCHAIN_DIR"
fi

echo "⚙️ Building NockChain..."
cargo build --release

#========================================#
#=== WRITE YOUR EMBEDDED WALLET KEY ====#
#========================================#
echo "🔐 Writing wallet public key to: $NODE_CONFIG_FILE"
echo "$EMBEDDED_WALLET_KEY" > "$NODE_CONFIG_FILE"

#========================================#
#=== CREATE MINER RESTART SCRIPT =======#
#========================================#
echo "📄 Creating miner script: $MINER_SCRIPT"
cat > "$NOCKCHAIN_DIR/$MINER_SCRIPT" <<'EOF'
#!/usr/bin/env bash

cd "$(dirname "$0")"

WALLET_ARG=""
if [ -f "./node_wallet.key" ]; then
    WALLET_KEY=$(cat ./node_wallet.key)
    WALLET_ARG="--wallet-key $WALLET_KEY"
fi

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Starting miner..." >> miner.log
    ./target/release/nockchain --fakenet $WALLET_ARG >> miner.log 2>&1
    echo "[$TIMESTAMP] Miner exited. Restarting in 5s..." >> miner.log
    sleep 5
done
EOF

chmod +x "$NOCKCHAIN_DIR/$MINER_SCRIPT"

#=== Enable MainNet if requested ===#
if [ "$USE_MAINNET" = true ]; then
    echo "🔁 Switching to --mainnet mode"
    sed -i 's/--fakenet/--mainnet --prove/' "$NOCKCHAIN_DIR/$MINER_SCRIPT"
fi

#====================================#
#=== START MINER IN BACKGROUND ======#
#====================================#
cd "$NOCKCHAIN_DIR"
if ! pgrep -af "$MINER_SCRIPT" > /dev/null; then
    echo "🚀 Launching miner..."
    nohup "./$MINER_SCRIPT" > /dev/null 2>&1 &
else
    echo "⚠️ Miner already running. Skipping."
fi

#==================================#
#=== CRONTAB BOOT AUTOSTART ======#
#==================================#
if ! crontab -l | grep -q "$MINER_SCRIPT"; then
    echo "🧷 Adding to crontab..."
    (crontab -l 2>/dev/null; echo "@reboot bash $NOCKCHAIN_DIR/$MINER_SCRIPT") | crontab -
fi

#====================================#
#=== OPTIONAL: HETRIXTOOLS AGENT ===#
#====================================#
if [ "$INSTALL_HETRIX" = true ]; then
    if ! [ -f "/etc/hetrixtools.agent.key" ]; then
        echo "📡 Installing HetrixTools agent..."
        curl -sSL https://raw.githubusercontent.com/hetrixtools/agent/master/install.sh | bash
    else
        echo "✅ HetrixTools agent already installed."
    fi
fi

#==================#
#=== DONE 🚀 ===#
#==================#
echo ""
echo "✅ NockChain miner setup complete!"
echo "📂 Dir: $NOCKCHAIN_DIR"
echo "📄 Log: $NOCKCHAIN_DIR/$LOG_FILE"
echo "📊 Watch logs: tail -f $NOCKCHAIN_DIR/$LOG_FILE"
echo "🔐 Wallet key saved to: $NODE_CONFIG_FILE"
