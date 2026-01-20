<?php

declare(strict_types=1);

namespace App\Repository;

use App\Core\Database;
use PDO;

final class StatisticsRepository
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * @return array<int, array{platoon_id: int, platoon_name: string, company_id: int, company_name: string, visit_count: int}>
     */
    public function getPlatoonStatistics(): array
    {
        $stmt = $this->db->query(<<<'SQL'
            SELECT 
                p.id as platoon_id,
                p.name as platoon_name,
                c.id as company_id,
                c.name as company_name,
                COUNT(vr.id) as visit_count
            FROM schedule_visits.platoons p
            LEFT JOIN schedule_visits.companies c ON p.company_id = c.id
            LEFT JOIN schedule_visits.visit_requests vr ON p.id = vr.platoon_id
            GROUP BY p.id, p.name, c.id, c.name
            ORDER BY visit_count DESC, p.name ASC
        SQL);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * @return array<int, array{company_id: int, company_name: string, visit_count: int}>
     */
    public function getCompanyStatistics(): array
    {
        $stmt = $this->db->query(<<<'SQL'
            SELECT 
                c.id as company_id,
                c.name as company_name,
                COUNT(vr.id) as visit_count
            FROM schedule_visits.companies c
            LEFT JOIN schedule_visits.visit_requests vr ON c.id = vr.company_id
            GROUP BY c.id, c.name
            ORDER BY visit_count DESC, c.name ASC
        SQL);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * @return array<string, mixed>
     */
    public function getOverview(): array
    {
        // Tổng số lượt thăm theo trung đội
        $platoonStats = $this->getPlatoonStatistics();
        
        // Tổng số lượt thăm theo đại đội
        $companyStats = $this->getCompanyStatistics();

        // Trung đội có nhiều đợt thăm nhất
        $mostVisitedPlatoon = !empty($platoonStats) ? $platoonStats[0] : null;

        // Trung đội có ít đợt thăm nhất
        $leastVisitedPlatoon = !empty($platoonStats) ? end($platoonStats) : null;

        // Tổng số đơn
        $stmt = $this->db->query('SELECT COUNT(*) as total FROM schedule_visits.visit_requests');
        $totalRequests = (int)$stmt->fetch(PDO::FETCH_ASSOC)['total'];

        // Đơn theo trạng thái
        $stmt = $this->db->query('SELECT status, COUNT(*) as count FROM schedule_visits.visit_requests GROUP BY status');
        $statusCounts = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $statusCounts[$row['status']] = (int)$row['count'];
        }

        return [
            'total_requests' => $totalRequests,
            'status_counts' => $statusCounts,
            'platoon_statistics' => $platoonStats,
            'company_statistics' => $companyStats,
            'most_visited_platoon' => $mostVisitedPlatoon,
            'least_visited_platoon' => $leastVisitedPlatoon,
        ];
    }
}

