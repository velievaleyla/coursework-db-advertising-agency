-- ============================================================================
-- Модуль 1: Створення таблиць бази даних та обмежень цілісності
-- ============================================================================

-- 3. СТВОРЕННЯ ТАБЛИЦЬ (TABLES)
-- ============================================================================

-- 3.1 Таблиця співробітників агентства (employees)
CREATE TABLE employees (
    id_employee INT PRIMARY KEY DEFAULT NEXTVAL('seq_employees'),
    full_name VARCHAR(100) NOT NULL,
    position VARCHAR(50) NOT NULL,
    phone dm_phone NOT NULL,
    email dm_email NOT NULL UNIQUE,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    commission_rate NUMERIC(4, 2) NOT NULL DEFAULT 5.00 
        CHECK (commission_rate BETWEEN 0.00 AND 30.00)
);

-- 3.2 Таблиця рекламодавців (advertisers)
CREATE TABLE advertisers (
    id_advertiser INT PRIMARY KEY DEFAULT NEXTVAL('seq_advertisers'),
    client_type dm_client_type NOT NULL DEFAULT 'Юридична особа',
    company_name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100) NOT NULL,
    legal_code VARCHAR(20) UNIQUE, -- ЄДРПОУ або ІПН
    address VARCHAR(200) NOT NULL,
    phone dm_phone NOT NULL,
    email dm_email,
    discount_percent NUMERIC(4, 2) NOT NULL DEFAULT 0.00 
        CHECK (discount_percent BETWEEN 0.00 AND 50.00)
);

-- 3.3 Таблиця типів рекламних видань (publication_types)
CREATE TABLE publication_types (
    id_publication_type INT PRIMARY KEY DEFAULT NEXTVAL('seq_publication_types'),
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    base_coefficient NUMERIC(3, 2) NOT NULL DEFAULT 1.00 
        CHECK (base_coefficient BETWEEN 0.50 AND 3.00)
);

-- 3.4 Таблиця рекламних видань (publications)
CREATE TABLE publications (
    id_publication INT PRIMARY KEY DEFAULT NEXTVAL('seq_publications'),
    id_publication_type INT NOT NULL,
    publication_name VARCHAR(100) NOT NULL,
    periodicity VARCHAR(50) NOT NULL, -- Щоденно, Щотижня, Двічі на місяць, Щомісяця
    circulation INT NOT NULL CHECK (circulation > 0),
    format_size VARCHAR(20) NOT NULL DEFAULT 'A4',
    chief_editor VARCHAR(100),
    contact_phone dm_phone NOT NULL,
    email dm_email,
    rating_score NUMERIC(3, 1) DEFAULT 5.0 CHECK (rating_score BETWEEN 1.0 AND 10.0),
    CONSTRAINT fk_publication_type 
        FOREIGN KEY (id_publication_type) 
        REFERENCES publication_types(id_publication_type) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.5 Таблиця тематичних рубрик / категорій реклами (ad_categories)
CREATE TABLE ad_categories (
    id_category INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_categories'),
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3.6 Таблиця місць розміщення реклами та розцінок (ad_placements)
CREATE TABLE ad_placements (
    id_placement INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_placements'),
    id_publication INT NOT NULL,
    placement_name VARCHAR(100) NOT NULL,
    unit_type VARCHAR(30) NOT NULL, -- кв.см, шпальта, колонка, блок
    base_price_per_unit dm_money NOT NULL CHECK (base_price_per_unit > 0.00),
    color_mode VARCHAR(30) NOT NULL DEFAULT 'Повноколір' 
        CHECK (color_mode IN ('Повноколір', 'Чорно-білий', 'Двоколір')),
    max_volume INT NOT NULL DEFAULT 1000 CHECK (max_volume > 0),
    CONSTRAINT fk_placement_publication 
        FOREIGN KEY (id_publication) 
        REFERENCES publications(id_publication) 
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 3.7 Таблиця договорів про співпрацю (contracts)
CREATE TABLE contracts (
    id_contract INT PRIMARY KEY DEFAULT NEXTVAL('seq_contracts'),
    contract_number VARCHAR(30) NOT NULL UNIQUE,
    id_advertiser INT NOT NULL,
    id_employee INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_budget dm_money NOT NULL DEFAULT 0.00,
    contract_status VARCHAR(25) NOT NULL DEFAULT 'Діючий' 
        CHECK (contract_status IN ('Проєкт', 'Діючий', 'Завершений', 'Розірваний')),
    CONSTRAINT chk_contract_dates CHECK (end_date >= start_date),
    CONSTRAINT fk_contract_advertiser 
        FOREIGN KEY (id_advertiser) 
        REFERENCES advertisers(id_advertiser) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contract_employee 
        FOREIGN KEY (id_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.8 Таблиця заявок на розміщення реклами (ad_orders)
CREATE TABLE ad_orders (
    id_order INT PRIMARY KEY DEFAULT NEXTVAL('seq_ad_orders'),
    order_number VARCHAR(30) NOT NULL UNIQUE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    id_contract INT,
    id_advertiser INT NOT NULL,
    id_employee INT NOT NULL,
    id_category INT NOT NULL,
    ad_title VARCHAR(150) NOT NULL,
    ad_content_text TEXT NOT NULL,
    total_cost dm_money NOT NULL DEFAULT 0.00,
    paid_amount dm_money NOT NULL DEFAULT 0.00,
    payment_status dm_payment_status NOT NULL DEFAULT 'Не оплачено',
    order_status dm_order_status NOT NULL DEFAULT 'Нова',
    CONSTRAINT fk_order_contract 
        FOREIGN KEY (id_contract) 
        REFERENCES contracts(id_contract) 
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_order_advertiser 
        FOREIGN KEY (id_advertiser) 
        REFERENCES advertisers(id_advertiser) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_employee 
        FOREIGN KEY (id_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_category 
        FOREIGN KEY (id_category) 
        REFERENCES ad_categories(id_category) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.9 Таблиця публікацій за заявкою / графік виходів (order_items)
CREATE TABLE order_items (
    id_order_item INT PRIMARY KEY DEFAULT NEXTVAL('seq_order_items'),
    id_order INT NOT NULL,
    id_publication INT NOT NULL,
    id_placement INT NOT NULL,
    target_release_date DATE NOT NULL,
    volume_units NUMERIC(8, 2) NOT NULL CHECK (volume_units > 0),
    applied_price_per_unit dm_money NOT NULL,
    calculated_cost dm_money NOT NULL DEFAULT 0.00,
    is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
    publication_status VARCHAR(25) NOT NULL DEFAULT 'Заплановано'
        CHECK (publication_status IN ('Заплановано', 'В верстці', 'Вийшло друком', 'Скасовано')),
    CONSTRAINT fk_item_order 
        FOREIGN KEY (id_order) 
        REFERENCES ad_orders(id_order) 
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_item_publication 
        FOREIGN KEY (id_publication) 
        REFERENCES publications(id_publication) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_item_placement 
        FOREIGN KEY (id_placement) 
        REFERENCES ad_placements(id_placement) 
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3.10 Таблиця платежів та квитанцій (payments)
CREATE TABLE payments (
    id_payment INT PRIMARY KEY DEFAULT NEXTVAL('seq_payments'),
    payment_number VARCHAR(30) NOT NULL UNIQUE,
    id_order INT NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_amount dm_money NOT NULL CHECK (payment_amount > 0.00),
    payment_type VARCHAR(30) NOT NULL 
        CHECK (payment_type IN ('Безготівковий розрахунок', 'Банківська картка', 'Готівка в касу')),
    payer_name VARCHAR(150) NOT NULL,
    receipt_code VARCHAR(50) UNIQUE,
    processed_by_employee INT,
    CONSTRAINT fk_payment_order 
        FOREIGN KEY (id_order) 
        REFERENCES ad_orders(id_order) 
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_payment_employee 
        FOREIGN KEY (processed_by_employee) 
        REFERENCES employees(id_employee) 
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- 3.11 Таблиця журналу аудиту (audit_log)
CREATE TABLE audit_log (
    id_log INT PRIMARY KEY DEFAULT NEXTVAL('seq_audit_log'),
    table_name VARCHAR(50) NOT NULL,
    operation_type VARCHAR(15) NOT NULL,
    record_id INT NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user VARCHAR(50) NOT NULL DEFAULT CURRENT_USER,
    details TEXT
);

-- ============================================================================
