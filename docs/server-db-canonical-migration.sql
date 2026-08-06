-- Canonical schema alignment for admin/API DB to match Flutter app local schema.
-- Target names are based on app schema in lib/services/database_helper.dart.
-- Review in staging first and adapt types/indexes to your production schema.

-- =========================
-- payments
-- =========================
ALTER TABLE payments CHANGE invoice_id invoiceId BIGINT UNSIGNED NOT NULL;
ALTER TABLE payments CHANGE payment_date paymentDate DATETIME NOT NULL;
ALTER TABLE payments CHANGE user_id userId BIGINT UNSIGNED NULL;
ALTER TABLE payments CHANGE payment_method method VARCHAR(191) NOT NULL;

-- Ensure canonical support columns exist
ALTER TABLE payments ADD COLUMN IF NOT EXISTS created_at DATETIME NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS is_voided TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS voided_at DATETIME NULL;

-- =========================
-- schedules
-- =========================
ALTER TABLE schedules CHANGE student_id student BIGINT UNSIGNED NOT NULL;
ALTER TABLE schedules CHANGE instructor_id instructor BIGINT UNSIGNED NOT NULL;
ALTER TABLE schedules CHANGE course_id course BIGINT UNSIGNED NOT NULL;
ALTER TABLE schedules CHANGE vehicle_id car BIGINT UNSIGNED NULL;
ALTER TABLE schedules CHANGE lesson_type class_type VARCHAR(191) NOT NULL;
ALTER TABLE schedules CHANGE lessons_completed lessonsCompleted INT NULL;
ALTER TABLE schedules CHANGE lessons_deducted lessonsDeducted INT NULL;

-- =========================
-- fleet
-- =========================
ALTER TABLE fleet CHANGE car_plate carplate VARCHAR(191) NOT NULL;
ALTER TABLE fleet CHANGE model_year modelyear VARCHAR(191) NOT NULL;
ALTER TABLE fleet ADD COLUMN IF NOT EXISTS school_id VARCHAR(191) NULL;

-- =========================
-- invoices
-- =========================
ALTER TABLE invoices CHANGE student_id student BIGINT UNSIGNED NOT NULL;
ALTER TABLE invoices CHANGE course_id course BIGINT UNSIGNED NOT NULL;
ALTER TABLE invoices CHANGE amount_paid amountpaid DECIMAL(12,2) NOT NULL DEFAULT 0;

ALTER TABLE invoices ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(191) NULL;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS used_lessons INT NOT NULL DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS school_id VARCHAR(191) NULL;

-- =========================
-- users/courses tenant keys
-- =========================
ALTER TABLE users ADD COLUMN IF NOT EXISTS school_id VARCHAR(191) NULL;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS school_id VARCHAR(191) NULL;

-- Optional index suggestions
CREATE INDEX idx_users_school_id ON users (school_id);
CREATE INDEX idx_courses_school_id ON courses (school_id);
CREATE INDEX idx_fleet_school_id ON fleet (school_id);
CREATE INDEX idx_invoices_school_id ON invoices (school_id);
CREATE INDEX idx_payments_invoiceId ON payments (invoiceId);
CREATE INDEX idx_schedules_start_end ON schedules (start, end);
