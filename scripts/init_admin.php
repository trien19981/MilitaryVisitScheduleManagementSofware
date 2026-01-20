<?php

declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Repository\AdminRepository;

// Load environment variables
Config::load(dirname(__DIR__) . '/.env');

// Initialize default admin
$repo = new AdminRepository();
$repo->initializeDefaultAdmin();

echo "Default admin account initialized successfully!\n";
echo "Username: admin\n";
echo "Password: admin123\n";

