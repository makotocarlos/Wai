# 📚 WAI - Plataforma de Escritura Colaborativa con IA

**WAI** (Write with AI) es una aplicación móvil de escritura colaborativa que permite a los autores crear, compartir y recibir feedback sobre sus historias, con asistencia de Inteligencia Artificial.

---

## 🚀 Características Principales

- ✍️ **Editor de Texto Rico**: Escribe capítulos con formato avanzado usando Flutter Quill
- 🤖 **Asistencia con IA**: Feedback automático de tus escritos mediante Google Gemini AI
- 👥 **Red Social para Autores**: Sigue autores, comenta capítulos y comparte historias
- 💬 **Mensajería Directa**: Comunícate con otros autores en tiempo real
- 🔔 **Notificaciones Push**: Recibe alertas de comentarios, likes y seguidores
- 📱 **Modo Offline**: Escribe sin conexión y sincroniza automáticamente
- 🌓 **Tema Claro/Oscuro**: Personaliza tu experiencia visual
- 🔒 **Autenticación Segura**: Login con email/contraseña y Google Sign-In

---

## 📋 Requisitos Previos

Antes de ejecutar la aplicación, asegúrate de tener instalado:

- **Flutter SDK** (>= 3.0.0) - [Instalar Flutter](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (>= 3.0.0)
- **Android Studio** o **Xcode** (para emuladores)
- **Git**
- **Cuenta de Supabase** - [Crear cuenta gratuita](https://supabase.com/)
- **Proyecto Firebase** - [Crear proyecto Firebase](https://console.firebase.google.com/)
- **API Key de Google Gemini** - [Obtener API Key](https://ai.google.dev/)


## ▶️ Ejecutar la Aplicación

### En Emulador/Dispositivo Android

flutter run

## 👤 Cómo Usar la Aplicación

### 1. **Registro de Usuario**

1. Abre la aplicación
2. Toca en **"Crear cuenta"**
3. Completa el formulario:
   - Nombre de autor
   - Correo electrónico
   - Contraseña (mínimo 6 caracteres)
4. Presiona **"Crear cuenta"**
5. **Revisa tu correo** y confirma tu email
6. Vuelve a la app y haz login

### 2. **Iniciar Sesión**

- **Con Email/Contraseña**: Ingresa tus credenciales
- **Con Google**: Presiona el botón de Google Sign-In

### 3. **Crear un Libro**

1. En la pantalla principal, toca el botón **"+"**
2. Completa los datos:
   - Título del libro
   - Descripción
   - Género
   - Imagen de portada (opcional)
3. Presiona **"Crear"**

### 4. **Escribir Capítulos**

1. Entra a tu libro
2. Toca **"Nuevo Capítulo"**
3. Escribe tu contenido usando el editor
4. Usa las herramientas de formato (negrita, cursiva, etc.)
5. Guarda el capítulo

### 5. **Obtener Feedback con IA**

1. Abre un capítulo
2. Toca el ícono de **IA** 🤖
3. Selecciona el tipo de análisis:
   - Gramática y ortografía
   - Estructura narrativa
   - Desarrollo de personajes
   - Sugerencias de mejora
4. Recibe feedback instantáneo

### 6. **Publicar y Compartir**

1. Marca tu libro como **"Publicado"**
2. Otros usuarios podrán:
   - Leer tus capítulos
   - Dejar comentarios
   - Dar "Me gusta"
   - Seguir tu perfil

### 7. **Explorar Contenido**

- **Explorar**: Descubre libros de otros autores
- **Buscar**: Filtra por género o título
- **Seguir Autores**: Mantente al tanto de sus publicaciones

### 8. **Modo Offline**

- Escribe sin conexión a internet
- Los cambios se guardan localmente
- Se sincronizan automáticamente cuando vuelvas online

---

## 🏗️ Estructura del Proyecto

```
lib/
├── core/                    # Configuraciones globales
│   ├── di/                 # Inyección de dependencias
│   ├── supabase/           # Cliente Supabase
│   └── errors/             # Manejo de errores
├── features/               # Funcionalidades por módulos
│   ├── auth/              # Autenticación
│   ├── books/             # Gestión de libros
│   ├── chapters/          # Gestión de capítulos
│   ├── comments/          # Sistema de comentarios
│   ├── profile/           # Perfil de usuario
│   ├── notifications/     # Notificaciones
│   └── settings/          # Configuraciones
├── screens/               # Pantallas principales
├── shared/                # Widgets y utilidades compartidas
│   ├── theme/            # Temas de la app
│   └── widgets/          # Widgets reutilizables
└── main.dart             # Punto de entrada
```

---

## 🔧 Tecnologías Utilizadas

### Frontend
- **Flutter** - Framework UI multiplataforma
- **Dart** - Lenguaje de programación
- **BLoC** - Gestión de estado
- **Flutter Quill** - Editor de texto rico

### Backend & Servicios
- **Supabase** - Backend as a Service (PostgreSQL, Auth, Storage, Realtime)
- **Firebase** - Notificaciones Push, Analytics
- **Google Gemini AI** - Inteligencia Artificial generativa

### Bases de Datos
- **PostgreSQL** (Supabase) - Base de datos principal
- **SQLite** (Local) - Cache offline

### Otras Librerías
- `google_sign_in` - Autenticación con Google
- `image_picker` / `image_cropper` - Manejo de imágenes
- `connectivity_plus` - Detección de conectividad
- `share_plus` - Compartir contenido

---

## 🐛 Solución de Problemas

### Error: "Row violates row-level security policy"

**Causa**: Las políticas RLS de Supabase no están configuradas.

**Solución**: Ejecuta los scripts SQL de configuración mencionados en la sección **5️⃣ Configurar Base de Datos Supabase**.

---

### Error: "MissingPluginException"

**Causa**: Plugins nativos no compilados.

**Solución**:
```bash
flutter clean
flutter pub get
flutter run
```

---

### Error al cargar imágenes

**Causa**: Bucket de almacenamiento no configurado en Supabase.

**Solución**:
1. Ve a Supabase Dashboard → Storage
2. Crea un bucket llamado `avatars` (público)
3. Crea un bucket llamado `book-covers` (público)

---

### Notificaciones no funcionan

**Causa**: Firebase no configurado correctamente.

**Solución**:
1. Verifica que `google-services.json` (Android) y `GoogleService-Info.plist` (iOS) estén en las carpetas correctas
2. Ejecuta: `flutterfire configure`
3. Habilita Cloud Messaging en Firebase Console

---

## 📱 Capturas de Pantalla

_Próximamente..._

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto es privado y de uso personal.

---

## 👨‍💻 Autor

**Makoto Carlos**  
GitHub: [@makotocarlos](https://github.com/makotocarlos)

---

## 📞 Soporte

Si tienes problemas o preguntas:

1. Revisa la sección **Solución de Problemas**
2. Abre un Issue en GitHub
3. Consulta la documentación de [Flutter](https://docs.flutter.dev/) y [Supabase](https://supabase.com/docs)

---

## 🎯 Roadmap

- [ ] Chat grupal para comunidades de escritores
- [ ] Exportar libros a PDF/EPUB
- [ ] Modo colaborativo (edición múltiple)
- [ ] Análisis de métricas de escritura
- [ ] Integración con más modelos de IA
- [ ] Versión Web (Progressive Web App)

---

**¡Feliz escritura con WAI! ✨📖**
