# popperscuv2 (Android)
App de inventario y ventas con SQLite y exportación CSV.
- Inventario
- Ventas (historial, recientes primero)
- Reportes (exportar CSV)
- Utilidad ajustada a descuento y comisión 3.2% cuando pago es tarjeta

## Build local
flutter pub get
flutter build apk --release

## GitHub Actions
Al subir a main o master, el workflow compila y publica el APK como artifact.
