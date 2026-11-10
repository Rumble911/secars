package com.secars.lecturer;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.secars.db.ProcedureCalls;

/**
 * Lecturer API. SecurityConfig limits /api/lecturer/** to ROLE_LECTURER, and the
 * database package checks that each section belongs to the caller.
 */
@RestController
@RequestMapping("/api/lecturer")
public class LecturerController {

    public record GradeBody(Integer grade) {}

    private final ProcedureCalls db;

    public LecturerController(ProcedureCalls db) {
        this.db = db;
    }

    @GetMapping("/offerings")
    public List<Map<String, Object>> offerings(Authentication auth) {
        return db.query("ARS_LECTURER.MY_OFFERINGS", auth.getName());
    }

    @GetMapping("/offerings/{offeringId}/grades")
    public List<Map<String, Object>> grades(Authentication auth, @PathVariable long offeringId) {
        return db.query("ARS_LECTURER.OFFERING_GRADES", auth.getName(), offeringId);
    }

    @PutMapping("/enrollments/{enrollmentId}/grade")
    public ResponseEntity<Void> setGrade(Authentication auth, @PathVariable long enrollmentId,
                                         @RequestBody GradeBody body) {
        Integer grade = body == null ? null : body.grade();
        db.exec("ARS_LECTURER.SET_GRADE", auth.getName(), enrollmentId, grade);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/offerings/{offeringId}/submit")
    public ResponseEntity<Void> submit(Authentication auth, @PathVariable long offeringId) {
        db.exec("ARS_LECTURER.SUBMIT_OFFERING", auth.getName(), offeringId);
        return ResponseEntity.noContent().build();
    }
}
