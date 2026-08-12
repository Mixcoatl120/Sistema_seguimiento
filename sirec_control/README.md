# Sirec Control

**Sistema de Seguridad Personal y Familiar** - Aplicación móvil con botón de pánico, geolocalización y grabación de audio.

## 📱 ¿Qué es Sirec Control?

Sirec Control es una aplicación de seguridad que permite a los usuarios:

- **Activar un botón de pánico** para alertar rápidamente a contactos de emergencia
- **Compartir tu ubicación en tiempo real** con familiares en un mapa
- **Grabar audio y video** como evidencia de emergencias
- **Mantener una red familiar segura** con gestión de contactos
- **Funcionar en segundo plano** monitoreando continuamente tu ubicación

## 🎯 Características Principales

- ✅ **Autenticación** - Crea cuenta y verifica tu email
- 🗺️ **Mapas Interactivos** - Visualiza ubicaciones en tiempo real
- 📍 **GPS en Tiempo Real** - Comparte tu ubicación automáticamente
- 🎙️ **Grabación de Audio** - Documenta incidentes
- 🚨 **Botón de Pánico** - Alerta de emergencia con un toque
- 👨‍👩‍👧‍👦 **Gestión de Familia** - Agrega y administra contactos de emergencia
- 🔔 **Notificaciones** - Recibe alertas de tus contactos
- 🔋 **Funciona en Background** - La app continúa monitoreando en segundo plano

## 📦 Requisitos

- **Flutter** versión 3.9.2 o superior
- **Android** (versión 5.0 o superior recomendada)
- **iOS** (versión 11.0 o superior recomendada)
- **Conexión a Internet** para sincronizar datos

## 🚀 Instalación

### Paso 1: Descargar Flutter
Si no tienes Flutter instalado, descárgalo desde: https://flutter.dev/docs/get-started/install

### Paso 2: Clonar el proyecto
```bash
git clone <tu-repositorio>
cd sirec_control
```

### Paso 3: Instalar dependencias
```bash
flutter pub get
```

### Paso 4: Ejecutar la aplicación

**En Android:**
```bash
flutter run
```

**En iOS:**
```bash
flutter run -d iPhone
```

**En web:**
```bash
flutter run -d chrome
```

## 💡 Cómo Usar

### 1. **Registrarse**
   - Abre la app y selecciona "Registrarse"
   - Ingresa tu email y contraseña
   - Verifica tu email desde el enlace que recibirás

### 2. **Configurar Contactos de Emergencia**
   - Ve a la sección "Familia"
   - Agrega números telefónicos o emails de contactos de confianza
   - Estos recibirán alertas cuando presiones el botón de pánico

### 3. **Compartir Ubicación**
   - Abre la sección "Mapa"
   - Tu ubicación se mostrará automáticamente
   - Los contactos agregados podrán ver tu posición

### 4. **Usar el Botón de Pánico**
   - En la pantalla principal encontrarás un botón rojo grande
   - Presiona para enviar una alerta de emergencia
   - Se enviarán notificaciones a todos tus contactos con tu ubicación

### 5. **Grabar Evidencia**
   - Ve a "Audios"
   - Presiona grabar para capturar audio o video
   - Las grabaciones se guardaran en la app

## 📁 Estructura de la App

- **Login/Registro** - Acceso seguro con email
- **Inicio** - Pantalla principal con botón de pánico
- **Mapa** - Visualiza ubicaciones en tiempo real
- **Audios** - Gestiona grabaciones
- **Familia** - Administra contactos de emergencia
- **Perfil** - Información del usuario
- **Opciones** - Configuración general

## ⚙️ Permisos Necesarios

La app solicita permisos para:
- 📍 **Ubicación** - Para compartir tu posición en tiempo real
- 🎙️ **Micrófono** - Para grabar audio en emergencias
- 📷 **Cámara** - Para grabar video
- 💾 **Almacenamiento** - Para guardar archivos multimedia

## 🔒 Privacidad y Seguridad

- Todos los datos se encuentran encriptados
- Solo contactos autorizados ven tu información
- Las grabaciones se almacenan de forma segura
- Puedes eliminar datos en cualquier momento desde Opciones

## 📞 Soporte

Para reportar errores o sugerencias, abre un issue en el repositorio.

---

**Versión:** 0.0.10+1  
**Plataforma:** Flutter  
**Última actualización:** 2026-08-11
