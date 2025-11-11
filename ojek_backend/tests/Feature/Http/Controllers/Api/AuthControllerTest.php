<?php

namespace Tests\Feature\Http\Controllers\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * @see \App\Http\Controllers\Api\AuthController
 */
final class AuthControllerTest extends TestCase
{
    #[Test]
    public function register_responds_with(): void
    {
        $response = $this->get(route('auths.register'));

        $response->assertOk();
        $response->assertJson($User);
    }


    #[Test]
    public function login_responds_with(): void
    {
        $response = $this->get(route('auths.login'));

        $response->assertOk();
        $response->assertJson($token, role);
    }


    #[Test]
    public function logout_responds_with(): void
    {
        $response = $this->get(route('auths.logout'));

        $response->assertOk();
        $response->assertJson($message);
    }
}
