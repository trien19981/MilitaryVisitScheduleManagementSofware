<?php

declare(strict_types=1);

namespace App\Core;

final class Config
{
    private static array $vars = [];

    public static function load(string $path): void
    {
        if (!file_exists($path)) {
            throw new \RuntimeException(".env file not found at {$path}");
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (str_starts_with(trim($line), '#')) {
                continue;
            }

            if (strpos($line, '=') === false) {
                continue;
            }

            list($name, $value) = explode('=', $line, 2);
            $name = trim($name);
            $value = trim($value);

            // Remove surrounding quotes
            if (preg_match('/^"(.*)"$/', $value, $matches)) {
                $value = $matches[1];
            }

            self::$vars[$name] = $value;
        }
    }

    public static function get(string $key, $default = null): ?string
    {
        return self::$vars[$key] ?? $default;
    }
}

