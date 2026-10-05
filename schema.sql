-- ========================================
-- WATSOLUTION BACKEND SCHEMA (NestJS/TypeORM)
-- Compatible con PostgreSQL y SQLite
-- ========================================

-- ========================================
-- TABLE: addresses
-- ========================================
CREATE TABLE address (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    neighborhood VARCHAR(100) NOT NULL,
    street VARCHAR(100),
    house_number VARCHAR(20),
    city VARCHAR(50) NOT NULL,
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6)
);

-- ========================================
-- TABLE: people (person)
-- ========================================
CREATE TABLE person (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name VARCHAR(100) NOT NULL,
    document_number VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    subscriber_number VARCHAR(50) UNIQUE,
    stratum INTEGER DEFAULT 1,
    user_id VARCHAR(50),
    green_points INTEGER DEFAULT 0,
    days_since_last_debt INTEGER DEFAULT 0,
    savings_percent DECIMAL(5,2) DEFAULT 0,
    address_id INTEGER,
    FOREIGN KEY (address_id) REFERENCES address(id) ON DELETE SET NULL
);

-- ========================================
-- TABLE: meters
-- ========================================
CREATE TABLE meter (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    water_measure DECIMAL(10,2) NOT NULL,
    reading_date DATE NOT NULL,
    observation VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    person_id INTEGER,
    address_id INTEGER,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (address_id) REFERENCES address(id) ON DELETE SET NULL
);

-- ========================================
-- TABLE: invoices
-- ========================================
CREATE TABLE invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    consumption_m_3 DECIMAL(10,2) NOT NULL,
    amount_due DECIMAL(10,2) NOT NULL,
    rate_per_m3 DECIMAL(10,2),
    fixed_charge DECIMAL(10,2),
    subsidy_percent DECIMAL(5,4),
    additional_charges DECIMAL(10,2),
    pdf_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    bold_order_id VARCHAR(100),
    bold_transaction_id VARCHAR(100),
    meter_id INTEGER,
    person_id INTEGER,
    FOREIGN KEY (meter_id) REFERENCES meter(id) ON DELETE SET NULL,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ========================================
-- TABLE: jhi_user (auth users)
-- ========================================
CREATE TABLE jhi_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    login VARCHAR(50) NOT NULL UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) NOT NULL,
    activated BOOLEAN DEFAULT FALSE,
    lang_key VARCHAR(10) DEFAULT 'es',
    password VARCHAR(255) NOT NULL,
    image_url VARCHAR(500),
    activation_key VARCHAR(50),
    reset_key VARCHAR(50),
    reset_date TIMESTAMP
);

-- ========================================
-- TABLE: jhi_authority
-- ========================================
CREATE TABLE jhi_authority (
    name VARCHAR(50) PRIMARY KEY
);

-- ========================================
-- TABLE: jhi_user_authority (ManyToMany)
-- ========================================
CREATE TABLE jhi_user_authority (
    user_id INTEGER NOT NULL,
    authority_name VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, authority_name),
    FOREIGN KEY (user_id) REFERENCES jhi_user(id) ON DELETE CASCADE,
    FOREIGN KEY (authority_name) REFERENCES jhi_authority(name) ON DELETE CASCADE
);

-- ========================================
-- TABLE: noticia
-- ========================================
CREATE TABLE noticia (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(200) NOT NULL,
    summary TEXT,
    content TEXT,
    category VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    publish_date DATE,
    image_url VARCHAR(500)
);

-- ========================================
-- TABLE: reporte
-- ========================================
CREATE TABLE reporte (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    person_id INTEGER,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ========================================
-- TABLE: activity_log
-- ========================================
CREATE TABLE activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    reference VARCHAR(100),
    amount DECIMAL(12,2),
    person_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- SEED DATA
-- ========================================
INSERT INTO jhi_authority (name) VALUES ('ROLE_USER'), ('ROLE_ADMIN');
