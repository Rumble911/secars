package com.secars.auditor;

import java.util.List;
import java.util.Map;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.secars.db.ProcedureCalls;

/** Auditor API, read only (FR07). SecurityConfig limits /api/auditor/** to ROLE_AUDITOR. */
@RestController
@RequestMapping("/api/auditor")
public class AuditorController {

    private final ProcedureCalls db;

    public AuditorController(ProcedureCalls db) {
        this.db = db;
    }

    @GetMapping("/grade-audit")
    public List<Map<String, Object>> gradeAudit(Authentication auth) {
        return db.query("ARS_AUDITOR.GRADE_AUDIT", auth.getName());
    }

    @GetMapping("/security-events")
    public List<Map<String, Object>> securityEvents(Authentication auth) {
        return db.query("ARS_AUDITOR.SECURITY_EVENTS", auth.getName());
    }
}
