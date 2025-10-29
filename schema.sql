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
CREATE TABLE people (
  id SERIAL PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  document_number VARCHAR(20) UNIQUE NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(100),
  address_id INT,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_people_address
    FOREIGN KEY (address_id)
    REFERENCES addresses(id)
    ON DELETE SET NULL
);

-- ========================================
-- TABLE: meters
-- ========================================
CREATE TABLE meters (
    id SERIAL PRIMARY KEY,
    people_id INT REFERENCES people(id) ON DELETE CASCADE,
    address_id INT REFERENCES addresses(id) ON DELETE SET NULL,
    water_measure DECIMAL(10,2) NOT NULL,         -- cantidad registrada de agua
    reading_date DATE NOT NULL,                   -- fecha de la lectura
    observation VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_meter_user
        FOREIGN KEY (people_id)
        REFERENCES people(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_meter_address
        FOREIGN KEY (address_id)
        REFERENCES addresses(id)
        ON DELETE SET NULL
);



-- ========================================
-- TABLE: invoices
-- ========================================
CREATE TABLE meters (
    id SERIAL PRIMARY KEY,
    people_id INT REFERENCES people(id) ON DELETE CASCADE,
    address_id INT REFERENCES addresses(id) ON DELETE SET NULL,
    water_measure DECIMAL(10,2) NOT NULL,         -- cantidad registrada de agua
    reading_date DATE NOT NULL,                   -- fecha de la lectura
    observation VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_meter_user
        FOREIGN KEY (people_id)
        REFERENCES people(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_meter_address
        FOREIGN KEY (address_id)
        REFERENCES addresses(id)
        ON DELETE SET NULL
);

