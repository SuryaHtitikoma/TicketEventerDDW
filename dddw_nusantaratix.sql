CREATE DATABASE IF NOT EXISTS nusantaratix;
USE nusantaratix;

-- ==========================================
-- 1. TABEL MASTER
-- ==========================================
CREATE TABLE users (
    user_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'OPERATOR', 'CUSTOMER', 'ANALYST')),
    region VARCHAR(30) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE events (
    event_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    event_name VARCHAR(150) NOT NULL,
    venue VARCHAR(150) NOT NULL,
    city VARCHAR(50) NOT NULL,
    region VARCHAR(30) NOT NULL,
    event_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ticket_tiers (
    tier_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    event_id INT8 NOT NULL REFERENCES events(event_id),
    tier_name VARCHAR(50) NOT NULL,
    price DECIMAL(12, 2) NOT NULL,
    total_quota INT4 NOT NULL,
    available_quota INT4 NOT NULL CHECK (available_quota >= 0) -- Proteksi anti-overselling!
);

-- ==========================================
-- 2. TIGA TABEL PERANG (Target >= 1 Juta Baris)
-- ==========================================
CREATE TABLE bookings (
    booking_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    user_id INT8 NOT NULL REFERENCES users(user_id),
    event_id INT8 NOT NULL REFERENCES events(event_id),
    region VARCHAR(30) NOT NULL,
    booking_status VARCHAR(20) NOT NULL CHECK (booking_status IN ('PENDING', 'PAID', 'EXPIRED', 'CANCELLED')),
    total_amount DECIMAL(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    INDEX idx_bookings_created (created_at DESC),
    INDEX idx_bookings_region (region, booking_status)
);

CREATE TABLE booking_tickets (
    ticket_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    booking_id INT8 NOT NULL REFERENCES bookings(booking_id),
    tier_id INT8 NOT NULL REFERENCES ticket_tiers(tier_id),
    attendee_name VARCHAR(100) NOT NULL,
    ticket_code VARCHAR(32) UNIQUE NOT NULL,
    is_checked_in BOOL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    INDEX idx_tickets_booking (booking_id)
);

CREATE TABLE payment_transactions (
    payment_id INT8 PRIMARY KEY DEFAULT unique_rowid(),
    booking_id INT8 NOT NULL REFERENCES bookings(booking_id),
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('QRIS', 'VA_BCA', 'VA_MANDIRI', 'GOPAY', 'OVO')),
    amount_paid DECIMAL(12, 2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('SUCCESS', 'FAILED', 'REFUNDED')),
    paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    INDEX idx_payments_paid_at (paid_at DESC)
);

-- ==========================================
-- 3. RBAC LEVEL DATABASE
-- ==========================================
CREATE ROLE admin_role WITH LOGIN PASSWORD 'AdminPassword123!';
CREATE ROLE operator_role WITH LOGIN PASSWORD 'OperatorPassword123!';
CREATE ROLE analyst_role WITH LOGIN PASSWORD 'AnalystPassword123!';

-- Admin: Hak penuh seluruh tabel
GRANT ALL ON DATABASE nusantaratix TO admin_role;
GRANT ALL ON TABLE users, events, ticket_tiers, bookings, booking_tickets, payment_transactions TO admin_role;

-- Operator / Aplikasi Transaksi: Baca master, tulis & update tabel perang + potong kuota
GRANT SELECT ON TABLE users, events, ticket_tiers TO operator_role;
GRANT UPDATE (available_quota) ON TABLE ticket_tiers TO operator_role;
GRANT SELECT, INSERT, UPDATE ON TABLE bookings, booking_tickets, payment_transactions TO operator_role;

-- Analyst (Untuk tarik data ke DuckDB saat UAS): Hanya boleh SELECT
GRANT SELECT ON TABLE users, events, ticket_tiers, bookings, booking_tickets, payment_transactions TO analyst_role;