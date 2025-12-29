#!/bin/bash
echo "🚀 StatsGuard M4 Pro v1.0"
mkdir -p "$HOME/bin"
curl -sSL https://raw.githubusercontent.com/luispelaez/StatsGuard-M4-Pro/main/optimize_stats_dynamic.sh > "$HOME/bin/optimize_stats_dynamic.sh"
chmod +x "$HOME/bin/optimize_stats_dynamic.sh"
curl -sSL https://raw.githubusercontent.com/luispelaez/StatsGuard-M4-Pro/main/com.statsguard.plist > "$HOME/Library/LaunchAgents/com.statsguard.plist"
echo '# StatsGuard' >> ~/.zshrc
echo "alias sg-status='$HOME/bin/optimize_stats_dynamic.sh status'" >> ~/.zshrc
echo "alias sg-watch='watch -n 5 $HOME/bin/optimize_stats_dynamic.sh status'" >> ~/.zshrc
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/com.statsguard.plist"
echo "✅ INSTALADO!"
