package com.secars.auth;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.CallableStatementCreator;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

/**
 * Authentication logic. Every database call goes through the ARS_AUTH package,
 * because APP_USER has no table privileges (see db/04_auth_package.sql).
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** Login data as returned by ARS_AUTH.GET_LOGIN_STATE. userId is null for an unknown user. */
    public record LoginState(Long userId, String hash, String role, boolean active,
                             Timestamp lockedUntil, Long studentId, Long lecturerId) {}

    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    /** Used to spend the same BCrypt time on unknown users, so response time does not reveal usernames. */
    private final String dummyHash;

    public AuthService(JdbcTemplate jdbc, PasswordEncoder encoder) {
        this.jdbc = jdbc;
        this.encoder = encoder;
        this.dummyHash = encoder.encode("timing-equaliser-not-a-real-password");
    }

    /**
     * Checks the credentials. Returns the login state when they are valid, otherwise empty.
     * The caller must never reveal which part was wrong.
     */
    public Optional<LoginState> authenticate(String username, String password, String ip) {
        LoginState st = lookup(username);

        if (st.userId() == null) {
            encoder.matches(password, dummyHash);
            recordFailure(username, ip);
            return Optional.empty();
        }

        boolean locked = st.lockedUntil() != null && st.lockedUntil().toInstant().isAfter(Instant.now());
        if (!st.active() || locked) {
            // Do not count more failures against a locked account; just refuse.
            encoder.matches(password, dummyHash);
            return Optional.empty();
        }

        if (!encoder.matches(password, st.hash())) {
            recordFailure(username, ip);
            return Optional.empty();
        }

        recordSuccess(username, ip);
        return Optional.of(st);
    }

    LoginState lookup(String username) {
        CallableStatementCreator creator =
                con -> con.prepareCall("{call ARS_OWNER.ARS_AUTH.GET_LOGIN_STATE(?,?,?,?,?,?,?,?)}");
        CallableStatementCallback<LoginState> callback = cs -> {
            cs.setString(1, username);
            cs.registerOutParameter(2, Types.NUMERIC);   // p_user_id
            cs.registerOutParameter(3, Types.VARCHAR);   // p_hash
            cs.registerOutParameter(4, Types.VARCHAR);   // p_role
            cs.registerOutParameter(5, Types.NUMERIC);   // p_active
            cs.registerOutParameter(6, Types.TIMESTAMP); // p_locked_until
            cs.registerOutParameter(7, Types.NUMERIC);   // p_student_id
            cs.registerOutParameter(8, Types.NUMERIC);   // p_lecturer_id
            cs.execute();
            return new LoginState(
                    nullableLong(cs, 2),
                    cs.getString(3),
                    cs.getString(4),
                    nullableLong(cs, 5) != null && nullableLong(cs, 5) == 1L,
                    cs.getTimestamp(6),
                    nullableLong(cs, 7),
                    nullableLong(cs, 8));
        };
        return jdbc.execute(creator, callback);
    }

    private void recordFailure(String username, String ip) {
        callProcedure("{call ARS_OWNER.ARS_AUTH.RECORD_FAILURE(?,?)}", username, ip);
    }

    private void recordSuccess(String username, String ip) {
        callProcedure("{call ARS_OWNER.ARS_AUTH.RECORD_SUCCESS(?,?)}", username, ip);
    }

    private void callProcedure(String sql, String username, String ip) {
        CallableStatementCreator creator = con -> con.prepareCall(sql);
        CallableStatementCallback<Void> callback = cs -> {
            cs.setString(1, username);
            cs.setString(2, ip);
            cs.execute();
            return null;
        };
        jdbc.execute(creator, callback);
    }

    private static Long nullableLong(CallableStatement cs, int index) throws SQLException {
        long value = cs.getLong(index);
        return cs.wasNull() ? null : value;
    }
}
