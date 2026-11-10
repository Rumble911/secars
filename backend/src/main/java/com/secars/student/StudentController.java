package com.secars.student;

import java.util.List;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Student-only API. SecurityConfig limits /api/student/** to ROLE_STUDENT.
 * The student is always the signed-in user; no student id is accepted from the client.
 */
@RestController
@RequestMapping("/api/student")
public class StudentController {

    private final StudentService service;

    public StudentController(StudentService service) {
        this.service = service;
    }

    @GetMapping("/enrollments")
    public List<StudentService.EnrollmentRow> enrollments(Authentication authentication) {
        return service.listMyEnrollments(authentication.getName());
    }
}
