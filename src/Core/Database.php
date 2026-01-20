<?php

declare(strict_types=1);

namespace App\Core;

use PDO;
use PDOException;

final class Database
{
    private static ?PDO $instance = null;

    private function __construct() {}
    private function __clone() {}
    public function __wakeup() {}

    public static function getInstance(): PDO
    {
        if (self::$instance === null) {
            // Prefer discrete DB_* variables; fallback to DATABASE_URI
            $driver = Config::get('DB_CONNECTION', 'pgsql');
            $host = Config::get('DB_HOST');
            $port = Config::get('DB_PORT');
            $dbname = Config::get('DB_DATABASE');
            $user = Config::get('DB_USERNAME');
            $pass = Config::get('DB_PASSWORD');
            $schema = Config::get('DB_SCHEMA'); // optional search_path

            $dsnFromEnv = Config::get('DATABASE_URI');

            // If any of the discrete vars missing, attempt to parse DATABASE_URI
            if ($driver === 'pgsql' && ($host === null || $dbname === null) && !empty($dsnFromEnv)) {
                $dbopts = parse_url($dsnFromEnv);
                $host = $host ?? ($dbopts['host'] ?? null);
                $port = $port ?? ($dbopts['port'] ?? null);
                $dbname = $dbname ?? ltrim($dbopts['path'] ?? '', '/');
                $user = $user ?? ($dbopts['user'] ?? null);
                $pass = $pass ?? ($dbopts['pass'] ?? null);

                // Parse query for search_path if schema not set
                if (!$schema && isset($dbopts['query'])) {
                    parse_str($dbopts['query'], $query_params);
                    if (!empty($query_params['options'])) {
                        $opt = str_replace('--', '', $query_params['options']);
                        if (preg_match('/search_path=([a-zA-Z0-9_]+)/', $opt, $m)) {
                            $schema = $m[1];
                        }
                    }
                }
            }

            if ($driver !== 'pgsql') {
                throw new PDOException('Unsupported DB_CONNECTION. Only pgsql is supported in this setup.');
            }

            if (empty($host) || empty($dbname)) {
                throw new PDOException('Database configuration is incomplete. Please set DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD (or DATABASE_URI).');
            }

            $pdo_dsn = "pgsql:host={$host};port={$port};dbname={$dbname}";

            try {
                self::$instance = new PDO($pdo_dsn, $user, $pass, [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                ]);

                if ($schema) {
                    self::$instance->exec("SET search_path TO " . self::$instance->quote($schema));
                }
            } catch (PDOException $e) {
                // In a real app, log this error instead of echoing
                throw new PDOException('Database connection failed: ' . $e->getMessage());
            }
        }

        return self::$instance;
    }
}

