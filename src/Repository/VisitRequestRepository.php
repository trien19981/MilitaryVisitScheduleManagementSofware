<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class VisitRequestRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @param array<string, mixed> $data
     * @return array{id: string, code: string}|null
     */
    public function create(array $data): ?array
    {
        // Generate a shorter, more user-friendly code
        $code = 'DV' . substr(str_shuffle('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'), 0, 6);

        $sql = <<<'SQL'
            INSERT INTO schedule_visits.visit_requests
                (code, battalion_id, company_id, platoon_id, soldier_name, visitor_name, visitor_phone, reason)
            VALUES
                (:code, :battalion_id, :company_id, :platoon_id, :soldier_name, :visitor_name, :visitor_phone, :reason)
            RETURNING id, code;
        SQL;

        $stmt = $this->db->prepare($sql);

        $stmt->execute([
            ':code' => $code,
            ':battalion_id' => $data['battalion_id'],
            ':company_id' => $data['company_id'],
            ':platoon_id' => $data['platoon_id'],
            ':soldier_name' => $data['soldier_name'],
            ':visitor_name' => $data['visitor_name'],
            ':visitor_phone' => $data['visitor_phone'],
            ':reason' => $data['reason'] ?? null,
        ]);

        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    /**
     * @param array<string, mixed> $filters
     * @return array<int, array<string, mixed>>
     */
    public function findAll(array $filters = []): array
    {
        $sql = <<<'SQL'
            SELECT 
                vr.id, vr.code, vr.soldier_name, vr.visitor_name, vr.visitor_phone,
                vr.reason, vr.status, vr.reviewed_at, vr.created_at, vr.updated_at,
                b.id as battalion_id, b.name as battalion_name,
                c.id as company_id, c.name as company_name,
                p.id as platoon_id, p.name as platoon_name
            FROM schedule_visits.visit_requests vr
            JOIN schedule_visits.battalions b ON vr.battalion_id = b.id
            JOIN schedule_visits.companies c ON vr.company_id = c.id
            JOIN schedule_visits.platoons p ON vr.platoon_id = p.id
            WHERE 1=1
        SQL;

        $params = [];

        if (!empty($filters['status'])) {
            $sql .= ' AND vr.status = :status';
            $params['status'] = $filters['status'];
        }

        if (!empty($filters['platoon_id'])) {
            $sql .= ' AND vr.platoon_id = :platoon_id';
            $params['platoon_id'] = $filters['platoon_id'];
        }

        if (!empty($filters['company_id'])) {
            $sql .= ' AND vr.company_id = :company_id';
            $params['company_id'] = $filters['company_id'];
        }

        $sql .= ' ORDER BY vr.created_at DESC';

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findById(string $id): ?array
    {
        $stmt = $this->db->prepare(<<<'SQL'
            SELECT 
                vr.*,
                b.name as battalion_name,
                c.name as company_name,
                p.name as platoon_name
            FROM schedule_visits.visit_requests vr
            JOIN schedule_visits.battalions b ON vr.battalion_id = b.id
            JOIN schedule_visits.companies c ON vr.company_id = c.id
            JOIN schedule_visits.platoons p ON vr.platoon_id = p.id
            WHERE vr.id = :id
        SQL);
        $stmt->execute(['id' => $id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function findByCode(string $code): ?array
    {
        $stmt = $this->db->prepare(<<<'SQL'
            SELECT 
                vr.*,
                b.name as battalion_name,
                c.name as company_name,
                p.name as platoon_name
            FROM schedule_visits.visit_requests vr
            JOIN schedule_visits.battalions b ON vr.battalion_id = b.id
            JOIN schedule_visits.companies c ON vr.company_id = c.id
            JOIN schedule_visits.platoons p ON vr.platoon_id = p.id
            WHERE vr.code = :code
        SQL);
        $stmt->execute(['code' => $code]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }

    public function approve(string $idOrCode): bool
    {
        // Find request by UUID or code first
        $request = $this->findById($idOrCode) ?? $this->findByCode($idOrCode);
        if (!$request) {
            return false;
        }
        
        // Update using UUID
        $stmt = $this->db->prepare('UPDATE schedule_visits.visit_requests SET status = \'approved\'::schedule_visits.visit_status, reviewed_at = NOW() WHERE id = :id');
        return $stmt->execute(['id' => $request['id']]);
    }

    public function reject(string $idOrCode): bool
    {
        // Find request by UUID or code first
        $request = $this->findById($idOrCode) ?? $this->findByCode($idOrCode);
        if (!$request) {
            return false;
        }
        
        // Update using UUID
        $stmt = $this->db->prepare('UPDATE schedule_visits.visit_requests SET status = \'rejected\'::schedule_visits.visit_status, reviewed_at = NOW() WHERE id = :id');
        return $stmt->execute(['id' => $request['id']]);
    }
}

