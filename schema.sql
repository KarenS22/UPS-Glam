-- ====================================================================
-- SUPABASE POSTGRESQL SCHEMA FOR INSTAGRAM CLONE WITH PYCUDA INTEGRATION
-- ====================================================================

-- Drop tables if they exist (for easy re-running/testing)
DROP TABLE IF EXISTS gpu_metrics CASCADE;
DROP TABLE IF EXISTS processing_history CASCADE;
DROP TABLE IF EXISTS filters CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS publications CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- 1. Profiles Table (Linked with Supabase Auth users)
-- In Supabase, Auth.users contains registered users. 
-- We mirror/link profiles here using their UUIDs.
CREATE TABLE profiles (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Index for username search
CREATE INDEX idx_profiles_username ON profiles(username);

-- 2. Publications Table
CREATE TABLE publications (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    caption TEXT,
    image_url TEXT NOT NULL,          -- URL to the original image in Supabase Storage
    processed_image_url TEXT,        -- URL to the filtered image in Supabase Storage (if processed)
    filter_applied VARCHAR(50),      -- Name of the filter applied (e.g. grayscale, sepia, etc.)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Index for feeding queries (which sort by date)
CREATE INDEX idx_publications_created_at ON publications(created_at DESC);
CREATE INDEX idx_publications_user_id ON publications(user_id);

-- 3. Comments Table
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    publication_id INT NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_gpu BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_comments_publication_id ON comments(publication_id);

-- 4. Likes Table (Many-to-Many relationship between user profiles and publications)
CREATE TABLE likes (
    publication_id INT NOT NULL REFERENCES publications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (publication_id, user_id)
);

-- 5. Available Filters Table
CREATE TABLE filters (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT
);

-- Seed basic filters
INSERT INTO filters (id, name, description) VALUES
('grayscale', 'Grayscale Filter', 'Converts image colors to shades of gray using GPU intensity calculations'),
('sepia', 'Sepia Filter', 'Applies a vintage warm brown sepia effect'),
('invert', 'Invert Color Filter', 'Inverts all color channels to create an artistic negative effect'),
('blur', 'Gaussian Blur Filter', 'Applies an advanced horizontal and vertical box blur algorithm');

-- 6. Image Processing History Table
CREATE TABLE processing_history (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    original_image_url TEXT NOT NULL,
    processed_image_url TEXT NOT NULL,
    filter_id VARCHAR(50) NOT NULL REFERENCES filters(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_processing_history_user_id ON processing_history(user_id);

-- 7. GPU Metrics Table
-- Tracks memory consumption and computation times on the PyCUDA service
CREATE TABLE gpu_metrics (
    id SERIAL PRIMARY KEY,
    processing_id INT NOT NULL REFERENCES processing_history(id) ON DELETE CASCADE,
    kernel_execution_time_ms DOUBLE PRECISION NOT NULL,  -- Time spent strictly running the CUDA kernel
    memory_transfer_time_ms DOUBLE PRECISION NOT NULL,   -- Time spent transferring host-to-device & device-to-host
    total_gpu_time_ms DOUBLE PRECISION NOT NULL,          -- Overall latency in the GPU pipeline (ms)
    memory_used_bytes BIGINT NOT NULL,                    -- Approximate device VRAM allocated during kernel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_gpu_metrics_processing_id ON gpu_metrics(processing_id);
