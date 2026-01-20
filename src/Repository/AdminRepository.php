<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class AdminRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * Find admin by username
     * @return array<string, mixed>|null
     */
    public function findByUsername(string $username): ?array
    {
        $stmt = $this->db->prepare(<<<'SQL'
            SELECT id, username, password_hash, full_name, is_active, created_at, updated_at
            FROM schedule_visits.admins
            WHERE username = :username AND is_active = true
        SQL);
        $stmt->execute(['username' => $username]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    /**
     * Verify password
     */
    public function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }

    /**
     * Create new admin
     * @param array<string, mixed> $data
     * @return array<string, mixed>|null
     */
    public function create(array $data): ?array
    {
        $passwordHash = password_hash($data['password'], PASSWORD_DEFAULT);

        $sql = <<<'SQL'
            INSERT INTO schedule_visits.admins (username, password_hash, full_name, is_active)
            VALUES (:username, :password_hash, :full_name, :is_active)
            RETURNING id, username, full_name, is_active, created_at;
        SQL;

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':username' => $data['username'],
            ':password_hash' => $passwordHash,
            ':full_name' => $data['full_name'] ?? null,
            ':is_active' => $data['is_active'] ?? true,
        ]);

        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($result) {
            unset($result['password_hash']);
        }
        return $result ?: null;
    }

    /**
     * Update admin password
     */
    public function updatePassword(string $id, string $newPassword): bool
    {
        $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
        $stmt = $this->db->prepare(<<<'SQL'
            UPDATE schedule_visits.admins
            SET password_hash = :password_hash, updated_at = CURRENT_TIMESTAMP
            WHERE id = :id
        SQL);
        return $stmt->execute([
            ':id' => $id,
            ':password_hash' => $passwordHash,
        ]);
    }

    /**
     * Initialize default admin account if not exists
     */
    public function initializeDefaultAdmin(): void
    {
        // Check if admin exists
        $existing = $this->findByUsername('admin');
        if ($existing) {
            return;
        }

        // Create default admin
        $this->create([
            'username' => 'admin',
            'password' => 'admin123',
            'full_name' => 'Administrator',
            'is_active' => true,
        ]);
    }
}

