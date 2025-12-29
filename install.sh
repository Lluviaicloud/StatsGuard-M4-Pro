#!/bin/bash
# 🚀 StatsGuard M4 Pro v1.0 - Optimizador Apple Silicon
# https://github.com/Lluviaicloud/StatsGuard-M4-Pro

echo "🚀 StatsGuard M4 Pro v1.0"

# Crear directorio logs
mkdir -p ~/Library/Logs

# Descargar script principal
curl -sSL -o ~/optimize_stats_dynamic.sh \
  https://raw.githubusercontent.com/Lluviaicloud/StatsGuard-M4-Pro/main/optimize_stats_dynamic.sh && \
chmod +x ~/optimize_stats_dynamic.sh

# Crear plist LaunchAgent
cat > ~/Library/LaunchAgents/com.statsguard.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.statsguard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/$USER/optimize_stats_dynamic.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/$USER/Library/Logs/statsguard.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$USER/Library/Logs/statsguard.log</string>
</dict>
</plist>
EOF

# Cargar LaunchAgent
launchctl load ~/Library/LaunchAgents/com.statsguard.plist 2>/dev/null || true

# Crear comandos helpers
cat > ~/sg-status << 'EOF'
#!/bin/bash
echo "=== StatsGuard M4 Pro - Estado ==="
ps aux | grep optimize_stats_dynamic | grep -v grep || echo "❌ No activo"
echo "--- Logs recientes ---"
tail -5 ~/Library/Logs/statsguard.log
EOF

cat > ~/sg-watch << 'EOF'
#!/bin/bash
watch -n 2 'echo "=== StatsGuard LIVE ==="; sg-status'
EOF

chmod +x ~/sg-status ~/sg-watch

echo "✅ INSTALADO!"
echo "🔧 Comandos: sg-status | sg-watch"
echo "📊 Logs: ~/Library/Logs/statsguard.log"
