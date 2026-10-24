# Mapa y recorridos

La pantalla `lib/field/routes_screen.dart` está disponible en el panel de trabajo solo para administradores. Usa el mismo backend que la web, `https://api.watsolution.online`.

1. Abrir **Mapa y recorridos**.
2. Buscar viviendas y confirmar su ubicación, usando la búsqueda de dirección o coordenadas manuales.
3. Seleccionar de 2 a 25 viviendas y colocar el inicio primero y el destino al final.
4. Generar el recorrido. El mapa muestra el trazado y la lista indica el orden, distancia y tiempo estimado de conducción.

Se necesita conexión para buscar direcciones, cargar el mapa y calcular rutas. Las ubicaciones se guardan en el servidor y se comparten con la web. Revisar ubicaciones antiguas antes de usarlas: la nueva precisión de la base no recupera decimales previamente redondeados.

## Android — entrega 24/10/2026

- APK de actualización: versión 1.0.1, código 20261025.
- Descarga publicada: https://watsolution.online/descargas/watsolution-mapas-20261024.apk.
- Paquete y certificado idénticos a la actualización del 23/10/2026. Instalar sobre la app anterior, sin desinstalarla, para conservar datos locales.
- SHA256: `2c981b7f377e0d7d3729f683edf79c68f9d21516684a6099031c579cfbe2767c`.
- Tamaño: 118704143 bytes. Arquitecturas ARM, ARM64 y x86_64.
- APK release no depurable; sin archivos .env ni almacenes de claves empaquetados.
- Compilación con JDK 21 verificado de Eclipse Adoptium, requerido por MapLibre. No se cambió el Java global.
- Configuración pública: perfil field-v2, origen API de producción y la misma clave pública de verificación offline de la entrega anterior. La firma privada permanece fuera del código y del APK.
- Pruebas: 91 aprobadas y una omitida preexistente; análisis estático de los archivos integrados sin incidencias. No había dispositivo físico conectado.
- Evidencia y artefactos locales: `maps-release/` (excluido de Git).

Esta entrega distribuye un APK Android. No es una publicación en Google Play o App Store.

Actualización en dispositivo: instalada correctamente sobre la versión anterior en la tablet Lenovo TB351FU mediante `adb install -r`. Android confirma la versión 1.0.1 / 20261025 y mantiene la fecha de instalación original. La app reconoce la jornada guardada; la comprobación del mapa en el dispositivo queda pendiente del desbloqueo de identidad por el usuario.
