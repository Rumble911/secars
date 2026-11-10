package com.secars.registrar;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.secars.db.ProcedureCalls;

/**
 * Registrar API. SecurityConfig limits /api/registrar/** to ROLE_REGISTRAR.
 * The database package re-checks the role and the four-eyes rule.
 */
@RestController
@RequestMapping("/api/registrar")
public class RegistrarController {

    public record ChangeRequestBody(Long enrollmentId, Integer newGrade, String reason) {}

    public record DecisionBody(boolean approve, String note) {}

    private final ProcedureCalls db;

    public RegistrarController(ProcedureCalls db) {
        this.db = db;
    }

    @GetMapping("/offerings")
    public List<Map<String, Object>> offerings(Authentication auth) {
        return db.query("ARS_REGISTRAR.ALL_OFFERINGS", auth.getName());
    }

    @GetMapping("/offerings/{offeringId}/enrollments")
    public List<Map<String, Object>> enrollments(Authentication auth, @PathVariable long offeringId) {
        return db.query("ARS_REGISTRAR.OFFERING_ENROLLMENTS", auth.getName(), offeringId);
    }

    @PostMapping("/offerings/{offeringId}/publish")
    public ResponseEntity<Void> publish(Authentication auth, @PathVariable long offeringId) {
        db.exec("ARS_REGISTRAR.PUBLISH_OFFERING", auth.getName(), offeringId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/change-requests")
    public ResponseEntity<Void> requestChange(Authentication auth, @RequestBody ChangeRequestBody body) {
        if (body == null) {
            return ResponseEntity.badRequest().build();
        }
        db.exec("ARS_REGISTRAR.REQUEST_CHANGE", auth.getName(),
                body.enrollmentId(), body.newGrade(), body.reason());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/change-requests/pending")
    public List<Map<String, Object>> pending(Authentication auth) {
        return db.query("ARS_REGISTRAR.PENDING_REQUESTS", auth.getName());
    }

    @PostMapping("/change-requests/{requestId}/decision")
    public ResponseEntity<Void> decide(Authentication auth, @PathVariable long requestId,
                                       @RequestBody DecisionBody body) {
        if (body == null) {
            return ResponseEntity.badRequest().build();
        }
        db.exec("ARS_REGISTRAR.DECIDE_REQUEST", auth.getName(), requestId,
                body.approve() ? 1 : 0, body.note());
        return ResponseEntity.noContent().build();
    }
}
