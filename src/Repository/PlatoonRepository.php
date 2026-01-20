<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class PlatoonRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @param int $companyId
     * @return array<int, array{id: int, code: string, name: string}>
     */
    public function findByCompany(int $companyId): array
    {
        $stmt = $this->db->prepare('SELECT id, code, name FROM schedule_visits.platoons WHERE company_id = :companyId ORDER BY name ASC');
        $stmt->execute(['companyId' => $companyId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findAll(): array
    {
        $stmt = $this->db->query('SELECT p.id, p.code, p.name, p.company_id, c.name as company_name, b.name as battalion_name FROM schedule_visits.platoons p JOIN schedule_visits.companies c ON p.company_id = c.id JOIN schedule_visits.battalions b ON c.battalion_id = b.id ORDER BY b.name, c.name, p.name ASC');
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare('SELECT p.id, p.code, p.name, p.company_id, c.name as company_name, b.name as battalion_name, p.created_at, p.updated_at FROM schedule_visits.platoons p JOIN schedule_visits.companies c ON p.company_id = c.id JOIN schedule_visits.battalions b ON c.battalion_id = b.id WHERE p.id = :id');
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function create(array $data): array
    {
        $stmt = $this->db->prepare('INSERT INTO schedule_visits.platoons (company_id, code, name) VALUES (:company_id, :code, :name) RETURNING id, code, name, company_id');
        $stmt->execute([
            'company_id' => $data['company_id'],
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }

    public function update(int $id, array $data): bool
    {
        $stmt = $this->db->prepare('UPDATE schedule_visits.platoons SET company_id = :company_id, code = :code, name = :name WHERE id = :id');
        return $stmt->execute([
            'id' => $id,
            'company_id' => $data['company_id'],
            'code' => $data['code'],
            'name' => $data['name'],
        ]);
    }

    public function delete(int $id): bool
    {
        $stmt = $this->db->prepare('DELETE FROM schedule_visits.platoons WHERE id = :id');
        return $stmt->execute(['id' => $id]);
    }
}

