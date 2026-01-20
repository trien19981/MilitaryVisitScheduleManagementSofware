<?php

declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use App\Repository\AdminRepository;
use App\Repository\BattalionRepository;
use App\Repository\CompanyRepository;
use App\Repository\PlatoonRepository;
use App\Repository\VisitRequestRepository;
use App\Repository\StatisticsRepository;

// Load environment variables
Config::load(dirname(__DIR__) . '/.env');

// CORS headers
$origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
// Allow specific origins in development
$allowedOrigins = [
    'http://localhost:5173',
    'http://localhost:3000',
    'http://127.0.0.1:5173',
    'http://127.0.0.1:3000',
    'https://api.thamquannhan.io.vn',
    'http://api.thamquannhan.io.vn',
    'https://thamquannhan.io.vn',
    'http://thamquannhan.io.vn',
];

if (in_array($origin, $allowedOrigins)) {
    header("Access-Control-Allow-Origin: {$origin}");
} else {
    header("Access-Control-Allow-Origin: *");
}

header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Basic routing
$requestUri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$requestMethod = $_SERVER['REQUEST_METHOD'];

header('Content-Type: application/json; charset=utf-8');

try {
    // Health check / Database connection test
    if ($requestMethod === 'GET' && $requestUri === '/api/health') {
        try {
            $db = Database::getInstance();
            
            // Test connection with a simple query
            $stmt = $db->query('SELECT version() as version, current_database() as database, current_schema() as schema');
            $info = $stmt->fetch(\PDO::FETCH_ASSOC);
            
            // Check if schema exists
            $stmt = $db->query("SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'schedule_visits'");
            $schemaExists = $stmt->fetch() !== false;
            
            // Count tables in schedule_visits schema
            $tableCount = 0;
            if ($schemaExists) {
                $stmt = $db->query("SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'schedule_visits'");
                $result = $stmt->fetch(\PDO::FETCH_ASSOC);
                $tableCount = (int)($result['count'] ?? 0);
            }
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Database connection successful',
                'database' => [
                    'version' => $info['version'] ?? 'unknown',
                    'name' => $info['database'] ?? 'unknown',
                    'current_schema' => $info['schema'] ?? 'unknown',
                ],
                'schedule_visits' => [
                    'exists' => $schemaExists,
                    'table_count' => $tableCount,
                ],
            ], JSON_PRETTY_PRINT);
        } catch (\Throwable $e) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error',
                'message' => 'Database connection failed',
                'error' => $e->getMessage(),
            ], JSON_PRETTY_PRINT);
        }
        return;
    }

    if ($requestMethod === 'GET' && $requestUri === '/api/battalions') {
        $repo = new BattalionRepository();
        echo json_encode($repo->findAll());
        return;
    }

    if ($requestMethod === 'GET' && $requestUri === '/api/companies') {
        if (empty($_GET['battalion_id'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing battalion_id parameter']);
            return;
        }
        $battalionId = (int)$_GET['battalion_id'];
        $repo = new CompanyRepository();
        echo json_encode($repo->findByBattalion($battalionId));
        return;
    }

    if ($requestMethod === 'GET' && $requestUri === '/api/platoons') {
        if (empty($_GET['company_id'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing company_id parameter']);
            return;
        }
        $companyId = (int)$_GET['company_id'];
        $repo = new PlatoonRepository();
        echo json_encode($repo->findByCompany($companyId));
        return;
    }

    if ($requestMethod === 'POST' && $requestUri === '/api/visit-requests') {
        $input = json_decode(file_get_contents('php://input'), true);

        // Basic validation
        $requiredFields = ['battalion_id', 'company_id', 'platoon_id', 'soldier_name', 'visitor_name', 'visitor_phone'];
        $errors = [];
        foreach ($requiredFields as $field) {
            if (empty($input[$field])) {
                $errors[] = "Field '{$field}' is required.";
            }
        }

        if (!empty($errors)) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid input', 'details' => $errors]);
            return;
        }

        $repo = new VisitRequestRepository();
        $newRequest = $repo->create($input);

        if ($newRequest) {
            http_response_code(201);
            echo json_encode($newRequest);
        } else {
            http_response_code(500);
            echo json_encode(['error' => 'Failed to create visit request']);
        }
        return;
    }

    // Public API: Tra cứu đơn bằng code (dành cho người thăm quân nhân)
    if ($requestMethod === 'GET' && preg_match('#^/api/visit-requests/([A-Z0-9]+)$#', $requestUri, $matches)) {
        $code = $matches[1];
        $repo = new VisitRequestRepository();
        $request = $repo->findByCode($code);
        if ($request) {
            echo json_encode($request);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Không tìm thấy đơn với mã này']);
        }
        return;
    }

    // ========== ADMIN APIs ==========
    
    // Helper function to verify admin token
    $verifyAdminToken = function(): ?array {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (empty($authHeader) || !str_starts_with($authHeader, 'Bearer ')) {
            return null;
        }
        
        $token = substr($authHeader, 7); // Remove "Bearer " prefix
        $decoded = base64_decode($token, true);
        if ($decoded === false) {
            return null;
        }
        
        $data = json_decode($decoded, true);
        if (!$data || empty($data['id']) || empty($data['username'])) {
            return null;
        }
        
        // Verify admin exists and is active
        $repo = new AdminRepository();
        $admin = $repo->findByUsername($data['username']);
        if (!$admin || $admin['id'] !== $data['id']) {
            return null;
        }
        
        return $admin;
    };
    
    // Admin: Login (no auth required)
    if ($requestMethod === 'POST' && $requestUri === '/api/admin/login') {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (empty($input['username']) || empty($input['password'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Username và password là bắt buộc']);
            return;
        }

        $repo = new AdminRepository();
        $admin = $repo->findByUsername($input['username']);
        
        if (!$admin) {
            http_response_code(401);
            echo json_encode(['error' => 'Tên đăng nhập hoặc mật khẩu không đúng']);
            return;
        }

        if (!$repo->verifyPassword($input['password'], $admin['password_hash'])) {
            http_response_code(401);
            echo json_encode(['error' => 'Tên đăng nhập hoặc mật khẩu không đúng']);
            return;
        }

        // Return admin info (without password)
        unset($admin['password_hash']);
        echo json_encode([
            'success' => true,
            'admin' => $admin,
            'token' => base64_encode(json_encode(['id' => $admin['id'], 'username' => $admin['username']])), // Simple token for demo
        ]);
        return;
    }

    // Verify authentication for all other admin routes
    $admin = $verifyAdminToken();
    if (!$admin) {
        http_response_code(401);
        echo json_encode(['error' => 'Unauthorized. Please login first.']);
        return;
    }

    // Admin: Quản lý Tiểu đoàn - CRUD
    if ($requestMethod === 'GET' && $requestUri === '/api/admin/battalions') {
        $repo = new BattalionRepository();
        echo json_encode($repo->findAll());
        return;
    }

    if ($requestMethod === 'GET' && preg_match('#^/api/admin/battalions/(\d+)$#', $requestUri, $matches)) {
        $repo = new BattalionRepository();
        $battalion = $repo->findById((int)$matches[1]);
        if ($battalion) {
            echo json_encode($battalion);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Battalion not found']);
        }
        return;
    }

    if ($requestMethod === 'POST' && $requestUri === '/api/admin/battalions') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: code, name']);
            return;
        }
        $repo = new BattalionRepository();
        $newBattalion = $repo->create($input);
        http_response_code(201);
        echo json_encode($newBattalion);
        return;
    }

    if ($requestMethod === 'PUT' && preg_match('#^/api/admin/battalions/(\d+)$#', $requestUri, $matches)) {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: code, name']);
            return;
        }
        $repo = new BattalionRepository();
        if ($repo->update((int)$matches[1], $input)) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Battalion not found']);
        }
        return;
    }

    if ($requestMethod === 'DELETE' && preg_match('#^/api/admin/battalions/(\d+)$#', $requestUri, $matches)) {
        $repo = new BattalionRepository();
        if ($repo->delete((int)$matches[1])) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Battalion not found']);
        }
        return;
    }

    // Admin: Quản lý Đại đội - CRUD
    if ($requestMethod === 'GET' && $requestUri === '/api/admin/companies') {
        $repo = new CompanyRepository();
        echo json_encode($repo->findAll());
        return;
    }

    if ($requestMethod === 'GET' && preg_match('#^/api/admin/companies/(\d+)$#', $requestUri, $matches)) {
        $repo = new CompanyRepository();
        $company = $repo->findById((int)$matches[1]);
        if ($company) {
            echo json_encode($company);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Company not found']);
        }
        return;
    }

    if ($requestMethod === 'POST' && $requestUri === '/api/admin/companies') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['battalion_id']) || empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: battalion_id, code, name']);
            return;
        }
        $repo = new CompanyRepository();
        $newCompany = $repo->create($input);
        http_response_code(201);
        echo json_encode($newCompany);
        return;
    }

    if ($requestMethod === 'PUT' && preg_match('#^/api/admin/companies/(\d+)$#', $requestUri, $matches)) {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['battalion_id']) || empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: battalion_id, code, name']);
            return;
        }
        $repo = new CompanyRepository();
        if ($repo->update((int)$matches[1], $input)) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Company not found']);
        }
        return;
    }

    if ($requestMethod === 'DELETE' && preg_match('#^/api/admin/companies/(\d+)$#', $requestUri, $matches)) {
        $repo = new CompanyRepository();
        if ($repo->delete((int)$matches[1])) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Company not found']);
        }
        return;
    }

    // Admin: Quản lý Trung đội - CRUD
    if ($requestMethod === 'GET' && $requestUri === '/api/admin/platoons') {
        $repo = new PlatoonRepository();
        echo json_encode($repo->findAll());
        return;
    }

    if ($requestMethod === 'GET' && preg_match('#^/api/admin/platoons/(\d+)$#', $requestUri, $matches)) {
        $repo = new PlatoonRepository();
        $platoon = $repo->findById((int)$matches[1]);
        if ($platoon) {
            echo json_encode($platoon);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Platoon not found']);
        }
        return;
    }

    if ($requestMethod === 'POST' && $requestUri === '/api/admin/platoons') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['company_id']) || empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: company_id, code, name']);
            return;
        }
        $repo = new PlatoonRepository();
        $newPlatoon = $repo->create($input);
        http_response_code(201);
        echo json_encode($newPlatoon);
        return;
    }

    if ($requestMethod === 'PUT' && preg_match('#^/api/admin/platoons/(\d+)$#', $requestUri, $matches)) {
        $input = json_decode(file_get_contents('php://input'), true);
        if (empty($input['company_id']) || empty($input['code']) || empty($input['name'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing required fields: company_id, code, name']);
            return;
        }
        $repo = new PlatoonRepository();
        if ($repo->update((int)$matches[1], $input)) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Platoon not found']);
        }
        return;
    }

    if ($requestMethod === 'DELETE' && preg_match('#^/api/admin/platoons/(\d+)$#', $requestUri, $matches)) {
        $repo = new PlatoonRepository();
        if ($repo->delete((int)$matches[1])) {
            echo json_encode(['success' => true]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Platoon not found']);
        }
        return;
    }

    // Admin: Quản lý Đơn xin gặp
    if ($requestMethod === 'GET' && $requestUri === '/api/admin/visit-requests') {
        $filters = [];
        if (!empty($_GET['status'])) {
            $filters['status'] = $_GET['status'];
        }
        if (!empty($_GET['platoon_id'])) {
            $filters['platoon_id'] = (int)$_GET['platoon_id'];
        }
        if (!empty($_GET['company_id'])) {
            $filters['company_id'] = (int)$_GET['company_id'];
        }
        $repo = new VisitRequestRepository();
        echo json_encode($repo->findAll($filters));
        return;
    }

    if ($requestMethod === 'GET' && preg_match('#^/api/admin/visit-requests/([^/]+)$#', $requestUri, $matches)) {
        $repo = new VisitRequestRepository();
        // Try UUID first, then code
        $request = $repo->findById($matches[1]) ?? $repo->findByCode($matches[1]);
        if ($request) {
            echo json_encode($request);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Visit request not found']);
        }
        return;
    }

    if ($requestMethod === 'PUT' && preg_match('#^/api/admin/visit-requests/([^/]+)/approve$#', $requestUri, $matches)) {
        $repo = new VisitRequestRepository();
        if ($repo->approve($matches[1])) {
            echo json_encode(['success' => true, 'message' => 'Visit request approved']);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Visit request not found']);
        }
        return;
    }

    if ($requestMethod === 'PUT' && preg_match('#^/api/admin/visit-requests/([^/]+)/reject$#', $requestUri, $matches)) {
        $repo = new VisitRequestRepository();
        if ($repo->reject($matches[1])) {
            echo json_encode(['success' => true, 'message' => 'Visit request rejected']);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Visit request not found']);
        }
        return;
    }

    // Admin: Tổng quan / Thống kê
    if ($requestMethod === 'GET' && $requestUri === '/api/admin/overview') {
        $repo = new StatisticsRepository();
        echo json_encode($repo->getOverview(), JSON_PRETTY_PRINT);
        return;
    }

    if ($requestMethod === 'GET' && $requestUri === '/api/admin/statistics/platoons') {
        $repo = new StatisticsRepository();
        echo json_encode($repo->getPlatoonStatistics());
        return;
    }

    if ($requestMethod === 'GET' && $requestUri === '/api/admin/statistics/companies') {
        $repo = new StatisticsRepository();
        echo json_encode($repo->getCompanyStatistics());
        return;
    }

    // Default 404
    http_response_code(404);
    echo json_encode(['error' => 'Not Found']);
} catch (\Throwable $e) {
    // In a real app, log this error instead of echoing
    http_response_code(500);
    echo json_encode(['error' => 'An internal server error occurred', 'message' => $e->getMessage()]);
}
