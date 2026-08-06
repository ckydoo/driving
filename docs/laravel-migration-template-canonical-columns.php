<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // payments
        if (Schema::hasColumn('payments', 'invoice_id') && !Schema::hasColumn('payments', 'invoiceId')) {
            DB::statement('ALTER TABLE payments CHANGE invoice_id invoiceId BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('payments', 'payment_date') && !Schema::hasColumn('payments', 'paymentDate')) {
            DB::statement('ALTER TABLE payments CHANGE payment_date paymentDate DATETIME NOT NULL');
        }
        if (Schema::hasColumn('payments', 'user_id') && !Schema::hasColumn('payments', 'userId')) {
            DB::statement('ALTER TABLE payments CHANGE user_id userId BIGINT UNSIGNED NULL');
        }
        if (Schema::hasColumn('payments', 'payment_method') && !Schema::hasColumn('payments', 'method')) {
            DB::statement('ALTER TABLE payments CHANGE payment_method method VARCHAR(191) NOT NULL');
        }

        // schedules
        if (Schema::hasColumn('schedules', 'student_id') && !Schema::hasColumn('schedules', 'student')) {
            DB::statement('ALTER TABLE schedules CHANGE student_id student BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('schedules', 'instructor_id') && !Schema::hasColumn('schedules', 'instructor')) {
            DB::statement('ALTER TABLE schedules CHANGE instructor_id instructor BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('schedules', 'course_id') && !Schema::hasColumn('schedules', 'course')) {
            DB::statement('ALTER TABLE schedules CHANGE course_id course BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('schedules', 'vehicle_id') && !Schema::hasColumn('schedules', 'car')) {
            DB::statement('ALTER TABLE schedules CHANGE vehicle_id car BIGINT UNSIGNED NULL');
        }
        if (Schema::hasColumn('schedules', 'lesson_type') && !Schema::hasColumn('schedules', 'class_type')) {
            DB::statement('ALTER TABLE schedules CHANGE lesson_type class_type VARCHAR(191) NOT NULL');
        }
        if (Schema::hasColumn('schedules', 'lessons_completed') && !Schema::hasColumn('schedules', 'lessonsCompleted')) {
            DB::statement('ALTER TABLE schedules CHANGE lessons_completed lessonsCompleted INT NULL');
        }
        if (Schema::hasColumn('schedules', 'lessons_deducted') && !Schema::hasColumn('schedules', 'lessonsDeducted')) {
            DB::statement('ALTER TABLE schedules CHANGE lessons_deducted lessonsDeducted INT NULL');
        }

        // fleet
        if (Schema::hasColumn('fleet', 'car_plate') && !Schema::hasColumn('fleet', 'carplate')) {
            DB::statement('ALTER TABLE fleet CHANGE car_plate carplate VARCHAR(191) NOT NULL');
        }
        if (Schema::hasColumn('fleet', 'model_year') && !Schema::hasColumn('fleet', 'modelyear')) {
            DB::statement('ALTER TABLE fleet CHANGE model_year modelyear VARCHAR(191) NOT NULL');
        }

        // invoices
        if (Schema::hasColumn('invoices', 'student_id') && !Schema::hasColumn('invoices', 'student')) {
            DB::statement('ALTER TABLE invoices CHANGE student_id student BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('invoices', 'course_id') && !Schema::hasColumn('invoices', 'course')) {
            DB::statement('ALTER TABLE invoices CHANGE course_id course BIGINT UNSIGNED NOT NULL');
        }
        if (Schema::hasColumn('invoices', 'amount_paid') && !Schema::hasColumn('invoices', 'amountpaid')) {
            DB::statement('ALTER TABLE invoices CHANGE amount_paid amountpaid DECIMAL(12,2) NOT NULL DEFAULT 0');
        }
    }

    public function down(): void
    {
        // Add reverse renames here only if your rollback policy requires it.
    }
};
