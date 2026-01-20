<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class CompanyRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @param int $battalionId
     * @return array<int, array{id: int, code: string, name: string}>
     */
    public function findByBattalion(int $battalionId): array
    {
        $stmt = $this->db->prepare('SELECT id, code, name FROM schedule_visits.companies WHERE battalion_id = :battalionId ORDER BY name ASC');
        $stmt->execute(['battalionId' => $battalionId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findAll(): array
    {
        $stmt = $this->db->query('SELECT c.id, c.code, c.name, c.battalion_id, b.name as battalion_name FROM schedule_visits.companies c JOIN schedule_visits.battalions b ON c.battalion_id = b.id ORDER BY b.name, c.name ASC');
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT c.id, c.code, c.name, c.battalion_id, b.name as battalion_name, c.created_at, c.updated_at FROM schedule_visits.companies c JOIN schedule_visits.battalions b ON c.battalion_id = b.id WHERE c.id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function create(array $data): array
    {
        $stmt = $this->db->prepare('INSERT INTO schedule_visits.companies (battalion_id, code, name) VALUES (:battalion_id, :code, :name) RETURNING id, code, name, battalion_id');
        $stmt->execute([
            'battalion_id' => $data['battalion_id'],
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function update(int $id, array $data): bool
    {
        $stmt = $this->db->prepare('UPDATE schedule_visits.companies SET battalion_id = :battalion_id, code = :code, name = :name WHERE id = :id');
        return $stmt->execute([
            'id' => $id,
            'battalion_id' => $data['battalion_id'],
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
    }

    public function delete(int $id): bool
    {
        $stmt = $this->db->prepare('DELETE FROM schedule_visits.companies WHERE id = :id');
        return $stmt->execute(['id' => $id]);
    }
}

