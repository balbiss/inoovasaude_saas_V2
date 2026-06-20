#!/bin/sh
# Gera config.js com as variáveis de ambiente do comprador
# Isso permite que a mesma imagem Docker sirva múltiplas marcas
cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  apiUrl:       "${API_URL:-http://localhost:3000}",
  appName:      "${APP_NAME:-CRM Imobiliário}",
  logoUrl:      "${APP_LOGO_URL:-}",
  primaryColor: "${APP_PRIMARY_COLOR:-#1f93ff}",
  accentColor:  "${APP_ACCENT_COLOR:-#8b5cf6}",
  supportEmail: "${APP_SUPPORT_EMAIL:-}",
  footerText:   "${APP_FOOTER_TEXT:-© 2025 CRM Imobiliário}"
};
EOF

exec nginx -g 'daemon off;'
