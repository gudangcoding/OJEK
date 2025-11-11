<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // User::factory(10)->create();

        // User::factory()->create([
        //     'name' => 'Test User',
        //     'email' => 'test@example.com',
        // ]);

        // Create customer user
        User::factory()->create([
            'name' => 'Customer 1',
            'email' => 'a@a.com',
            'password'=> bcrypt('123456'),
            'role' => 'customer',
        ]);
        
        User::factory()->create([
            'name' => 'Customer 2',
            'email' => 'b@b.com',
            'password'=> bcrypt('123456'),
            'role' => 'customer',
        ]);

        // Create driver user
        User::factory()->create([
            'name' => 'Driver 1',
            'email' => 'c@c.com',
            'password'=> bcrypt('123456'),
            'role' => 'driver',
        ]);
        User::factory()->create([
            'name' => 'Driver 2',
            'email' => 'd@d.com',
            'password'=> bcrypt('123456'),
            'role' => 'driver',
        ]);
    }
}
