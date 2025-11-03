#!/bin/bash
set -e

echo "🚀 Build para Vercel iniciado..."

# Instalar Flutter si no está disponible
if ! command -v flutter &> /dev/null; then
    echo "📦 Instalando Flutter..."
    
    # Descargar Flutter SDK
    FLUTTER_SDK_PATH="/tmp/flutter"
    
    if [ ! -d "$FLUTTER_SDK_PATH" ]; then
        echo "Clonando Flutter SDK..."
        git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $FLUTTER_SDK_PATH
    fi
    
    export PATH="$FLUTTER_SDK_PATH/bin:$PATH"
    
    # Verificar instalación
    flutter --version
    flutter doctor -v || true
fi

# Habilitar web
echo "🌐 Habilitando soporte web..."
flutter config --enable-web || true

# Obtener dependencias
echo "📦 Obteniendo dependencias..."
flutter pub get

# Limpiar builds anteriores
echo "🧹 Limpiando builds anteriores..."
flutter clean || true

# Build para web
echo "🔨 Construyendo para web..."
flutter build web --release --base-href="/" --web-renderer canvaskit

echo "✅ Build completado! Archivos en build/web/"
ls -la build/web/ || true

