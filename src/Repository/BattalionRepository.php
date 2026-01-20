<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class BattalionRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @return array<int, array{id: int, code: string, name: string}>
     */
    public function findAll(): array
    {
        $stmt = $this->db->query('SELECT id, code, name FROM schedule_visits.battalions ORDER BY name ASC');
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT id, code, name, created_at, updated_at FROM schedule_visits.battalions WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function create(array $data): array
    {
        $stmt = $this->db->prepare('INSERT INTO schedule_visits.battalions (code, name) VALUES (:code, :name) RETURNING id, code, name');
        $stmt->execute([
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function update(int $id, array $data): bool
    {
        $stmt = $this->db->prepare('UPDATE schedule_visits.battalions SET code = :code, name = :name WHERE id = :id');
        return $stmt->execute([
            'id' => $id,
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
    }

    public function delete(int $id): bool
    {
        $stmt = $this->db->prepare('DELETE FROM schedule_visits.battalions WHERE id = :id');
        return $stmt->execute(['id' => $id]);
    }
}

