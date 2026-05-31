# Instagram Clone Reactive Backend & PyCUDA Filter Service

This repository houses a high-performance, containerized, reactive backend for an Instagram clone. The system integrates a non-blocking Java Spring WebFlux core, a Python PyCUDA image processing microservice, and Supabase cloud solutions (Auth, Database, Storage).

---

## 🌟 Architecture Overview

The project is structured as a decoupled, microservice-based system containerized with Docker:

1. **`backend-spring` (Spring WebFlux)**:
   - Built on a **reactive, non-blocking I/O paradigm** (Java 17+, Spring Boot 3.2.x).
   - Direct PostgreSQL integration using **R2DBC** (Reactive Relational Database Connectivity).
   - Local, high-speed **Supabase JWT signature validation** using the HMAC-SHA256 secret.
   - Coordinates file uploads and fetches with **Supabase Storage** and coordinates calls to **Supabase Auth** via `WebClient`.
   
2. **`cuda-service` (PyCUDA & FastAPI)**:
   - High-throughput Python microservice using **FastAPI** and **Uvicorn**.
   - Compiles and runs **NVIDIA CUDA kernels** dynamically for real-time image filtering (Grayscale, Sepia, Invert, Blur).
   - Incorporates a **graceful CPU/Numpy execution fallback** with microsecond-level metrics simulation when no NVIDIA graphics card or host drivers are present.
   - Measures exact memory utilization, H2D/D2H transfer latency, and kernel execution times.

---

## 🛠️ Step-by-Step Setup Guide

### 1. Supabase Initialization
1. Create a free project on [Supabase](https://supabase.com).
2. Go to **Database** -> **SQL Editor** -> click **New Query**, paste the entire contents of [schema.sql](schema.sql), and run it. This creates the profiles, posts, likes, comments, processing history, and GPU metric logs tables and seeds the standard filters list.
3. Go to **Storage** -> **New Bucket** -> create a public bucket named `instagram`.
4. Retrieve your keys under **Project Settings** -> **API**:
   - `Project URL`
   - `anon` / `public` API key
   - `service_role` secret API key (required by the backend to write files without client policy blockers)
   - `JWT Secret`

### 2. Configure Environment Variables
Copy the env template and customize it:
```bash
cp .env.example .env
```
Open `.env` and fill in your Supabase project parameters:
```env
SUPABASE_URL=https://xxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1Ni...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1Ni...
SUPABASE_JWT_SECRET=super-secret-jwt-key...

SPRING_DATABASE_URL=r2dbc:postgresql://db.xxxxxx.supabase.co:5432/postgres
SPRING_DATABASE_USERNAME=postgres
SPRING_DATABASE_PASSWORD=your-db-password
```

### 3. Container Orchestration & Launch
Compile and launch the microservices on a single Docker network:
```bash
docker-compose up --build
```
*   **Spring WebFlux Gateway & Interactive Docs**: [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)
*   **PyCUDA Processing Engine & Interactive Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 🧪 Comprehensive API Testing Guide (Curl)

Below are ready-to-run terminal commands to test the entire reactive flow.

### 🔑 1. Authentication Endpoints

#### Register a New User
Registers the credentials in Supabase Auth and automatically creates a corresponding row in the local `profiles` table:
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "siryorch",
    "email": "siryorch@example.com",
    "password": "securepassword123",
    "fullName": "Sir Yorch"
  }'
```

#### User Login
Authenticates through Supabase Auth, returning a valid JWT access token and user profile info:
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "siryorch@example.com",
    "password": "securepassword123"
  }'
```
> ⚠️ **Copy the returned token**! Export it to your environment variables to authorize subsequent API calls:
> `export TOKEN="your-access-token-here"`

#### Get Current Active Session Profile
```bash
curl -X GET http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

---

### 📸 2. Publications & Global Feed

#### Create a New Publication
Uploads an image, saves details to PostgreSQL, and binds it to your profile:
```bash
# Create a dummy image for testing
echo "fake-image-bytes" > test_image.jpg

# Post the publication
curl -X POST http://localhost:8080/api/publications \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test_image.jpg" \
  -F "caption=Feeling reactive today!"
```

#### Fetch Publications Feed
Asynchronously fetches posts, creator information, like metrics, and whether the logged-in user liked them:
```bash
curl -X GET http://localhost:8080/api/publications/feed \
  -H "Authorization: Bearer $TOKEN"
```

---

### 💬 3. Social Interaction (Likes & Comments)

#### Like a Publication
```bash
curl -X POST http://localhost:8080/api/publications/1/like \
  -H "Authorization: Bearer $TOKEN"
```

#### Unlike a Publication
```bash
curl -X DELETE http://localhost:8080/api/publications/1/like \
  -H "Authorization: Bearer $TOKEN"
```

#### Comment on a Publication
```bash
curl -X POST http://localhost:8080/api/publications/1/comments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "This is an amazing reactive post!"}'
```

#### Fetch Comments
```bash
curl -X GET http://localhost:8080/api/publications/1/comments \
  -H "Authorization: Bearer $TOKEN"
```

---

### ⚡ 4. GPU Image Processing & Performance Metrics

#### Apply CUDA Image Filter
Accepts an image and a filter target (options: `grayscale`, `sepia`, `invert`, `blur`). It triggers the CUDA pipelines, uploads both images to Supabase storage, saves log metrics, and returns the results:
```bash
curl -X POST http://localhost:8080/api/processing/apply-filter \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test_image.jpg" \
  -F "filter_type=sepia"
```

#### List Supported Filters
```bash
curl -X GET http://localhost:8080/api/processing/filters
```

#### Fetch User's Filtering History
```bash
curl -X GET http://localhost:8080/api/processing/history \
  -H "Authorization: Bearer $TOKEN"
```

#### Fetch GPU Metrics
Fetches detailed hardware execution benchmarks (latencies and memory consumption in bytes) for a specific filter task:
```bash
curl -X GET http://localhost:8080/api/processing/metrics/1 \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🚀 NVIDIA GPU Setup (Optional)

To execute the image filter operations strictly on a physical NVIDIA GPU inside Docker:

1. Install the **NVIDIA Container Toolkit** on your host:
   [Installation Instructions](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
2. Open the [docker-compose.yml](docker-compose.yml) file.
3. Uncomment the GPU reservation block inside the `cuda-service` specification:
   ```yaml
   deploy:
     resources:
       reservations:
         devices:
           - driver: nvidia
             count: all
             capabilities: [gpu]
   ```
4. Rebuild and restart the containers:
   ```bash
   docker-compose down && docker-compose up --build
   ```

---

## 🖼️ Optimización de Imágenes en Clientes (Web/Móvil)

Para asegurar una experiencia de usuario extremadamente rápida y un consumo de red y memoria eficiente en dispositivos de gama media/baja, el sistema cuenta con optimizaciones de rendimiento avanzadas:
- **Redimensionamiento Dinámico en Servidor (Supabase Image Resizing):** Las imágenes del feed global se solicitan dinámicamente al servicio de renderizado de Supabase con parámetros `width=600&quality=80`. Esto reduce el tamaño de descarga de datos en hasta un 95% (gracias al escalado y a la conversión automática a WebP) sin pérdida perceptible de nitidez en pantalla.
- **Límites de Decodificación en Memoria (Flutter VRAM Cache):** En la aplicación móvil `glam`, las imágenes se cargan con `cacheWidth: 600`. Esto obliga al motor gráfico (Impeller/Skia) a decodificar la imagen en la RAM física a una resolución reducida, disminuyendo el uso de memoria de aproximadamente `48MB` a tan solo `1.44MB` por tarjeta del feed, garantizando un scroll fluido y libre de crashes OOM.
