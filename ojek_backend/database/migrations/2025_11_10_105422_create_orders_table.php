<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id');
            $table->float('lat_pickup');
            $table->float('lon_pickup');
            $table->string('pickup_address');
            $table->foreignId('driver_id')->nullable();
            $table->float('lat_dropoff');
            $table->float('lon_dropoff');
            $table->string('dropoff_address');
            $table->double('total_price')->nullable();
            $table->double('distance')->nullable();
            $table->enum('status', ["pending","accepted","rejected","done"])->default('pending');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
