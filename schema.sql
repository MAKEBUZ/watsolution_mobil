-- ========================================
-- TABLE: addresses
-- ========================================
CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    neighborhood VARCHAR(100) NOT NULL,
    street VARCHAR(100),
    house_number VARCHAR(20),
    city VARCHAR(50) NOT NULL,
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6)
);

-- ========================================
-- TABLE: users
-- ========================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    document_number VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    address_id INT REFERENCES addresses(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    CONSTRAINT fk_user_address
        FOREIGN KEY (address_id)
        REFERENCES addresses(id)
        ON DELETE SET NULL
);

-- ========================================
-- TABLE: meters
-- ========================================
CREATE TABLE meters (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    address_id INT REFERENCES addresses(id) ON DELETE SET NULL,
    water_measure DECIMAL(10,2) NOT NULL,         -- cantidad registrada de agua
    reading_date DATE NOT NULL,                   -- fecha de la lectura
    consumption_m3 DECIMAL(10,2) GENERATED ALWAYS AS (water_measure - previous_reading) STORED,
    observation VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_meter_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_meter_address
        FOREIGN KEY (address_id)
        REFERENCES addresses(id)
        ON DELETE SET NULL
);

-- ========================================
-- TABLE: invoices
-- ========================================
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    meter_id INT REFERENCES meters(id) ON DELETE CASCADE,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    consumption_m3 DECIMAL(10,2) NOT NULL,
    amount_due DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_invoice_meter
        FOREIGN KEY (meter_id)
        REFERENCES meters(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_invoice_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);
