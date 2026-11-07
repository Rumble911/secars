package com.secars;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Stage-1 checks only. No business data is exposed here.
 * Errors return a generic message: details go to the server log, never to the client (FR09).
 */
@RestController
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/api/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    @GetMapping("/api/health/db")
    public ResponseEntity<Map<String, String>> database() {
        try {
            // SELECT FROM DUAL needs no table privilege, so APP_USER can run it.
            Integer one = jdbc.queryForObject("SELECT 1 FROM DUAL", Integer.class);
            if (one != null && one == 1) {
                return ResponseEntity.ok(Map.of("database", "UP"));
            }
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(Map.of("database", "DOWN"));
        } catch (Exception ex) {
            // Full cause goes to the server log only.
            org.slf4j.LoggerFactory.getLogger(HealthController.class)
                    .error("Database health check failed", ex);
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(Map.of("database", "DOWN"));
        }
    }
}
