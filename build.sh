#!/bin/bash

# Define Nomes
APP_NAME="CommandTracker"
BUNDLE_DIR="${APP_NAME}.app"
MACOS_DIR="${BUNDLE_DIR}/Contents/MacOS"
RESOURCES_DIR="${BUNDLE_DIR}/Contents/Resources"

echo "Limpar build anterior..."
rm -rf "$BUNDLE_DIR"

echo "Criar estrutura da App..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "A compilar ficheiros Swift..."
swiftc Sources/main.swift Sources/AppDelegate.swift Sources/VoiceController.swift Sources/ActionHandler.swift -o "$MACOS_DIR/$APP_NAME"

if [ $? -eq 0 ]; then
    echo "Compilação de executável concluída."
    
    echo "A copiar Info.plist e Ícone de App..."
    cp Info.plist "${BUNDLE_DIR}/Contents/"
    cp MyIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
    
    echo "A assinar aplicação para permitir Acessibilidade/Automação..."
    codesign --entitlements entitlements.plist --force --deep --sign - "${BUNDLE_DIR}"
    
    
    
    echo "Sucesso! Aplicação '$BUNDLE_DIR' pronta a executar no seu sistema."
else
    echo "Erro durante a compilação."
    exit 1
fi
