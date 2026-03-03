# Limpieza
rm -rf CounterApp.app CounterApp

# 1. Variables
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
TARGET="arm64-apple-ios17.0-simulator" # Ajusta a tu versión si es necesario

# 2. Compilar con el flag -parse-as-library
xcrun swiftc -sdk $SDK_PATH -target $TARGET \
    -parse-as-library \
    CounterApp.swift -o CounterApp

# 3. Crear el Bundle correctamente
mkdir -p CounterApp.app
mv CounterApp CounterApp.app/
cp Info.plist CounterApp.app/

# 4. Instalar y Lanzar
xcrun simctl install booted CounterApp.app
xcrun simctl launch booted com.test.counter

sleep 3
xcrun simctl io booted screenshot snapshot.png