#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Instalando StatsGuard M4 Pro v2.0"

REPO="https://raw.githubusercontent.com/Lluviaicloud/StatsGuard-M4-Pro/main"
BIN="$HOME/bin"
LA="$HOME/Library/LaunchAgents"
PLIST="$LA/com.statsguard.plist"
SCRIPT_DEST="$BIN/optimize_stats_dynamic.sh"
USER_ID="$(id -u)"
TMP_DIR="$(mktemp -d)"

mkdir -p "$BIN" "$LA" "$HOME/Library/Logs"

# Descargar script principal de forma atómica
echo "📥 Descargando script principal..."
if curl -fsSL "$REPO/optimize_stats_dynamic.sh" -o "$TMP_DIR/optimize_stats_dynamic.sh"; then
  mv "$TMP_DIR/optimize_stats_dynamic.sh" "$SCRIPT_DEST"
  chmod +x "$SCRIPT_DEST"
  echo "✅ Script instalado en: $SCRIPT_DEST"
else
  echo "❌ Error descargando optimize_stats_dynamic.sh"
  rm -rf "$TMP_DIR"
  exit 1
fi

# Detectar agentes/plists relacionados con "stats"
echo "🔎 Comprobando agentes existentes relacionados con Stats..."
existing_agent="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -Ei 'stats|exelban' || true)"
existing_plist="$(ls "$HOME/Library/LaunchAgents" 2>/dev/null | grep -Ei 'stats|com.statsguard' || true || true)"
# Buscar en /Library (puede no existir)
system_plist="$( (ls /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null || true) | grep -Ei 'stats|com.statsguard' || true )"

if [ -n "$existing_agent" ] || [ -n "$existing_plist" ] || [ -n "$system_plist" ]; then
  echo "⚠️ Agente relacionado detectado:"
  [ -n "$existing_agent" ] && echo "  - launchctl: $existing_agent"
  [ -n "$existing_plist" ] && echo "  - user LaunchAgents: $existing_plist"
  [ -n "$system_plist" ] && echo "  - system LaunchAgents/Daemons: $system_plist"
  echo "Se instalará el script y los helpers, pero NO se registrará un LaunchAgent adicional para evitar duplicidad."
  INSTALL_PLIST=false
else
  INSTALL_PLIST=true
fi

# Si no hay agente existente, descargar y preparar el plist
if [ "$INSTALL_PLIST" = true ]; then
  echo "📥 Descargando plantilla LaunchAgent..."
  if curl -fsSL "$REPO/com.statsguard.plist" -o "$TMP_DIR/com.statsguard.plist"; then
    # Backup del plist existente si lo hay
    if [ -f "$PLIST" ]; then
      cp -a "$PLIST" "${PLIST}.bak.$(date +%Y%m%d%H%M%S)"
      echo "🔁 Backup del plist anterior creado."
    fi

    # Reemplazar marcador %HOME% por ruta real
    sed "s|%HOME%|$HOME|g" "$TMP_DIR/com.statsguard.plist" > "$TMP_DIR/com.statsguard.rendered.plist"

    # Inyectar ProgramArguments / EnvironmentVariables si la plantilla no los define
    # Asegurar que ProgramArguments use /bin/bash y ruta absoluta al script
    if ! grep -q "<key>ProgramArguments</key>" "$TMP_DIR/com.statsguard.rendered.plist"; then
      # insertar ProgramArguments antes del cierre del dict
      awk -v script="$SCRIPT_DEST" '
        /<\/dict>/ && !x { print "  <key>ProgramArguments</key>\n  <array>\n    <string>/bin/bash</string>\n    <string>" script "</string>\n    <string>auto</string>\n  </array>\n"; x=1 }
        { print }
      ' "$TMP_DIR/com.statsguard.rendered.plist" > "$TMP_DIR/com.statsguard.final.plist"
    else
      cp -a "$TMP_DIR/com.statsguard.rendered.plist" "$TMP_DIR/com.statsguard.final.plist"
      # Reemplazar cualquier ruta con %HOME% ya hecha; si ProgramArguments existe, preferimos /bin/bash + script
      perl -0777 -pe 's{<key>ProgramArguments</key>\s*<array>.*?</array>}{<key>ProgramArguments</key>\n  <array>\n    <string>/bin/bash</string>\n    <string>'"$SCRIPT_DEST"'</string>\n    <string>auto</string>\n  </array>}s' "$TMP_DIR/com.statsguard.final.plist" > "$TMP_DIR/com.statsguard.final2.plist" && mv "$TMP_DIR/com.statsguard.final2.plist" "$TMP_DIR/com.statsguard.final.plist"
    fi

    # Añadir EnvironmentVariables PATH si no existe
    if ! grep -q "<key>EnvironmentVariables</key>" "$TMP_DIR/com.statsguard.final.plist"; then
      awk -v path="$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin" '
        /<\/dict>/ && !y { print "  <key>EnvironmentVariables</key>\n  <dict>\n    <key>PATH</key>\n    <string>" path "</string>\n  </dict>\n"; y=1 }
        { print }
      ' "$TMP_DIR/com.statsguard.final.plist" > "$TMP_DIR/com.statsguard.withenv.plist"
    else
      cp -a "$TMP_DIR/com.statsguard.final.plist" "$TMP_DIR/com.statsguard.withenv.plist"
    fi

    mv "$TMP_DIR/com.statsguard.withenv.plist" "$PLIST"
    rm -rf "$TMP_DIR/com.statsguard.plist" "$TMP_DIR/com.statsguard.rendered.plist" "$TMP_DIR/com.statsguard.final.plist" 2>/dev/null || true
    echo "✅ LaunchAgent preparado en $PLIST"
  else
    echo "❌ Error descargando com.statsguard.plist"
    rm -rf "$TMP_DIR"
    INSTALL_PLIST=false
  fi
fi

# Detectar shell rc
if [ -n "${ZSH_VERSION:-}" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ]; then
  SHELL_RC="$HOME/.bash_profile"
else
  SHELL_RC="$HOME/.zshrc"
fi
touch "$SHELL_RC"

# Asegurar PATH en rc
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC"; then
  echo "" >> "$SHELL_RC"
  echo "# Añadir bin local para StatsGuard" >> "$SHELL_RC"
  echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
  echo "✅ PATH añadido en $SHELL_RC"
fi

# Crear helpers
echo "🔧 Creando helpers en $BIN..."
cat > "$BIN/sg-status" <<'EOF'
#!/usr/bin/env bash
echo "=== StatsGuard M4 Pro - Estado ==="
if [ -x "$HOME/bin/optimize_stats_dynamic.sh" ]; then
  "$HOME/bin/optimize_stats_dynamic.sh" status
else
  ps aux | grep -i 'Stats' | grep -v grep || echo "❌ No activo"
fi
echo "--- Logs recientes ---"
tail -n 10 "$HOME/Library/Logs/statsguard.log" 2>/dev/null || true
EOF

cat > "$BIN/sg-watch" <<'EOF'
#!/usr/bin/env bash
if command -v watch >/dev/null 2>&1; then
  watch -n 5 "$HOME/bin/sg-status"
else
  while true; do
    clear
    date '+%Y-%m-%d %H:%M:%S'
    echo
    "$HOME/bin/sg-status"
    sleep 5
  done
fi
EOF

chmod +x "$BIN/sg-status" "$BIN/sg-watch" || true

# Registrar LaunchAgent si corresponde
if [ "$INSTALL_PLIST" = true ] && [ -f "$PLIST" ]; then
  echo "🔁 Registrando LaunchAgent (usuario $USER_ID)..."
  launchctl bootout "gui/$USER_ID" "$PLIST" >/dev/null 2>&1 || true

  if launchctl bootstrap "gui/$USER_ID" "$PLIST" 2>/dev/null; then
    echo "✅ LaunchAgent registrado con bootstrap."
  else
    echo "⚠️ bootstrap no disponible o falló, usando fallback load -w..."
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load -w "$PLIST"
    echo "✅ LaunchAgent cargado con load -w (fallback)."
  fi

  # Forzar ejecución inicial
  launchctl kickstart -k "gui/$USER_ID/com.statsguard" 2>/dev/null || true
else
  echo "ℹ️ No se registró LaunchAgent (agente existente detectado o error al preparar plist)."
fi

rm -rf "$TMP_DIR"

echo
echo "✅ StatsGuard M4 Pro v2.0 instalado correctamente."
echo "👉 Ejecuta: source $SHELL_RC"
echo "👉 Luego prueba: sg-status"
echo
echo "📌 Si no quieres que Stats se reabra automáticamente:"
echo "touch ~/.statsguard_no_autostart"
echo
echo "ℹ️ Notas:"
echo "- El script principal está en: $SCRIPT_DEST"
echo "- Helpers: $BIN/sg-status  $BIN/sg-watch"
echo "- Logs: $HOME/Library/Logs/statsguard.log"
