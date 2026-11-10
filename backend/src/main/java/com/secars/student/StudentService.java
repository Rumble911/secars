package com.secars.student;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.CallableStatementCreator;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/** Reads student data through the ARS_STUDENT package (APP_USER has no table privileges). */
@Service
public class StudentService {

    /** One enrolment. grade is null until the offering is published. */
    public record EnrollmentRow(String term, String courseCode, String courseTitle, int creditHours,
                                int sectionNo, String lecturerName, String offeringStatus, BigDecimal grade) {}

    private final JdbcTemplate jdbc;

    public StudentService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<EnrollmentRow> listMyEnrollments(String username) {
        CallableStatementCreator creator =
                con -> con.prepareCall("{call ARS_OWNER.ARS_STUDENT.LIST_MY_ENROLLMENTS(?,?)}");
        CallableStatementCallback<List<EnrollmentRow>> callback = cs -> {
            cs.setString(1, username);
            cs.registerOutParameter(2, Types.REF_CURSOR);
            cs.execute();

            List<EnrollmentRow> rows = new ArrayList<>();
            try (ResultSet rs = (ResultSet) cs.getObject(2)) {
                while (rs.next()) {
                    rows.add(new EnrollmentRow(
                            rs.getString("term"),
                            rs.getString("code"),
                            rs.getString("title"),
                            rs.getInt("credit_hours"),
                            rs.getInt("section_no"),
                            rs.getString("full_name"),
                            rs.getString("status"),
                            rs.getBigDecimal("grade")));
                }
            }
            return rows;
        };
        return jdbc.execute(creator, callback);
    }
}
