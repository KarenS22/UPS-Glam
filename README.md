# UPSGlam 3.0 - Red Social con Procesamiento de Imágenes en GPU

Este repositorio contiene un backend reactivo de alto rendimiento para una red social de imágenes. El sistema integra un núcleo Java Spring WebFlux no bloqueante, un microservicio de procesamiento de imágenes en Python mediante PyCUDA, y soluciones en la nube de Supabase (Auth, Database, Storage).

---

##  Descripción General de la Arquitectura

El proyecto está estructurado como un sistema desacoplado basado en microservicios, contenedorizado con Docker:

1. **`backend-spring` (Spring WebFlux)**:
   - Construido sobre un **paradigma reactivo y de E/S no bloqueante** (Java 17+, Spring Boot 3.2.x).
   - Integración directa con PostgreSQL usando **R2DBC**.
   - Validación local de firmas JWT de Supabase mediante el secreto HMAC-SHA256.
   - Coordina la carga de archivos con **Supabase Storage** y las llamadas a **Supabase Auth** vía `WebClient`.
   
2. **`cuda-service` (PyCUDA & FastAPI)**:
   - Microservicio en Python de alto rendimiento usando **FastAPI** y **Uvicorn**.
   - Compila y ejecuta **kernels de NVIDIA CUDA** dinámicamente para filtros en tiempo real (`blur`, `sharpen`, `sobel`, `cartooning`, `tricolor`, etc.).
   - Incorpora un **mecanismo automático de fallback a CPU/Numpy** con simulación de métricas técnica cuando no hay hardware NVIDIA presente.
   - Mide uso de memoria VRAM, hilos totales, dimensiones de grid/block y tiempos de ejecución del kernel.

> [!NOTE]
> Para un análisis técnico profundo de los flujos de datos y algoritmos, consulta la [Guía de Arquitectura Detallada](ARCHITECTURE.md).

---

##  Guía de Configuración Paso a Paso

### 1. Inicialización de Supabase
1. Crear un proyecto gratuito en [Supabase](https://supabase.com).
2. Ir a **Database** -> **SQL Editor** -> hacer clic en **New Query**, pegar el contenido completo de [schema.sql](schema.sql) y ejecutarlo. Esto crea las tablas de perfiles, publicaciones, likes, comentarios, historial y métricas.
3. Ir a **Storage** -> **New Bucket** -> crear un bucket público llamado `instagram`.
4. Obtener las claves en **Project Settings** -> **API**:
   - `Project URL`
   - `anon` / `public` API key
   - `service_role` secret API key (requerida por el backend para gestionar archivos).
   - `JWT Secret`

### 2. Configurar Variables de Entorno
Copiar la plantilla y personalízarla:
```bash
cp .env.example .env
```
Abre `.env` y rellena tus parámetros de Supabase:
```env
SUPABASE_URL=https://xxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1Ni...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1Ni...
SUPABASE_JWT_SECRET=tu-secreto-jwt...

SPRING_DATABASE_URL=r2dbc:postgresql://db.xxxxxx.supabase.co:5432/postgres
SPRING_DATABASE_USERNAME=postgres
SPRING_DATABASE_PASSWORD=tu-password-de-db
```

### 3. Orquestación y Lanzamiento (Docker Compose)
Compilar y lanzar los microservicios en una red común:
```bash
docker-compose up --build
```
*   **Backend Spring & Swagger UI**: [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)
*   **Motor PyCUDA & Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)

---

##  Guía de Pruebas de la API (Curl)

###  1. Autenticación

#### Registrar Usuario
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "usuario_test",
    "email": "test@example.com",
    "password": "password123",
    "fullName": "Usuario Test"
  }'
```

#### Iniciar Sesión (Login)
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```
>  **Copiar el token devuelto** y expórtarlo: `export TOKEN="tu_token_aqui"`

---

###  2. Procesamiento GPU y Métricas

#### Aplicar Filtro de Imagen CUDA
Aceptar una imagen y un tipo de filtro (opciones: `blur`, `sharpen`, `sobel`, `cartooning`, `tricolor`, `stripe_overlay`, `recuerdo_historico`).
```bash
curl -X POST http://localhost:8080/api/processing/apply-filter \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@mi_foto.jpg" \
  -F "filter_type=tricolor"
```

#### Consultar Métricas de GPU
Obtener telemetría detallada de la ejecución (tiempos de kernel, hilos, memoria VRAM):
```bash
curl -X GET http://localhost:8080/api/processing/metrics/1 \
  -H "Authorization: Bearer $TOKEN"
```

---

##  Configuración NVIDIA GPU 

Si se tiene una GPU NVIDIA física y se desea ejecutar los kernels nativamente en Docker:

1. Instalar **NVIDIA Container Toolkit** en el host: [Instrucciones](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
2. Abrir [docker-compose.yml](docker-compose.yml).
3. Descomentar el bloque `deploy/reservations` en el servicio `cuda-service`.
4. Reiniciar: `docker-compose down && docker-compose up --build`

---

##  Optimización de Rendimiento
El sistema utiliza **Supabase Image Resizing** para redimensionar imágenes dinámicamente a 600px en el servidor, reduciendo el consumo de datos en un 90%. En la App móvil (`glam`), se aplica **VRAM Cache Limiting** (`cacheWidth: 600`) para garantizar un scroll fluido sin agotar la memoria del dispositivo.
