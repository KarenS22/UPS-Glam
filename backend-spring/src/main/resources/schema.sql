-- Clean schema recreation (Drop existing tables in reverse dependency order)
DROP TABLE IF EXISTS gpu_metrics CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS publications CASCADE;
DROP TABLE IF EXISTS processing_history CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS filters CASCADE;

-- 1. Create filters table
CREATE TABLE filters (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT
);

-- 2. Create profiles table (maps to Supabase authenticated users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create publications table
CREATE TABLE publications (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    caption TEXT,
    image_url TEXT NOT NULL,
    processed_image_url TEXT,
    filter_applied VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create comments table
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Create likes table
CREATE TABLE likes (
    publication_id INTEGER NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (publication_id, user_id)
);

-- 6. Create processing history table
CREATE TABLE processing_history (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    original_image_url TEXT NOT NULL,
    processed_image_url TEXT NOT NULL,
    filter_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Create gpu metrics table (optimized telemetry metrics)
CREATE TABLE gpu_metrics (
    id SERIAL PRIMARY KEY,
    processing_id INTEGER NOT NULL REFERENCES processing_history(id) ON DELETE CASCADE,
    image_size VARCHAR(50) NOT NULL,
    block_dim VARCHAR(50) NOT NULL,
    grid_dim VARCHAR(50) NOT NULL,
    total_threads BIGINT NOT NULL,
    execution_time_ms DOUBLE PRECISION NOT NULL,
    memory_used_bytes BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
