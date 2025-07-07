#!/bin/bash

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting Dobby setup...${NC}"

# 1. Install Go if it's missing
if ! command -v go &> /dev/null; then
    echo -e "${GREEN}[1/4] Installing Go...${NC}"
    sudo apt update && sudo apt install -y golang
else
    echo -e "${GREEN}✔ Go is already installed.${NC}"
fi

# Add Go to PATH if needed
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
    export PATH=$PATH:$HOME/go/bin
    echo "✔ PATH updated with Go binaries."
fi

# 2. Install Go-based tools
GO_TOOLS=(
  github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  github.com/tomnomnom/assetfinder@latest
  github.com/tomnomnom/httprobe@latest
  github.com/lc/gau/v2/cmd/gau@latest
  github.com/tomnomnom/waybackurls@latest
  github.com/tomnomnom/anew@latest
)

echo -e "${GREEN}[2/4] Installing Go-based tools...${NC}"
for tool in "${GO_TOOLS[@]}"; do
    go install "$tool"
done

# 3. Install grep (just in case)
echo -e "${GREEN}[3/4] Ensuring grep is installed...${NC}"
sudo apt install -y grep

# 4. Install amass (optional)
read -p "Do you want to install Amass (optional)? [y/N]: " install_amass
if [[ "$install_amass" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installing Amass...${NC}"
    sudo apt install -y amass
else
    echo "Skipping Amass installation."
fi

# Final: Make main script executable
echo -e "${GREEN}[4/4] Making dobby.sh executable...${NC}"
chmod +x dobby.sh

echo -e "${GREEN}✅ Setup complete! You can now run ./dobby.sh <domain>${NC}"
