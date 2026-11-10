package com.secars.db;

import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.CallableStatementCreator;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * The only way the API talks to Oracle for business data. Every call goes to a package
 * procedure in ARS_OWNER. APP_USER has no table privileges.
 *
 * Business rules raise ORA-20xxx errors. Those messages are written by us and are safe to
 * show. Any other database error is logged with a correlation id and never sent to the client.
 */
@Component
public class ProcedureCalls {

    private static final Logger log = LoggerFactory.getLogger(ProcedureCalls.class);
    private static final Pattern BUSINESS_ERROR = Pattern.compile("ORA-(20\\d{3}): ([^\\r\\n]+)");

    private final JdbcTemplate jdbc;

    public ProcedureCalls(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Runs a procedure with no cursor output. Args are bound in order. */
    public void exec(String procedure, Object... args) {
        String sql = callText(procedure, args.length);
        CallableStatementCreator creator = con -> con.prepareCall(sql);
        CallableStatementCallback<Void> callback = cs -> {
            bind(cs, args);
            cs.execute();
            return null;
        };
        try {
            jdbc.execute(creator, callback);
        } catch (DataAccessException e) {
            throw translate(e);
        }
    }

    /** Runs a procedure whose LAST parameter is a SYS_REFCURSOR and returns those rows. */
    public List<Map<String, Object>> query(String procedure, Object... args) {
        int cursorIndex = args.length + 1;
        String sql = callText(procedure, cursorIndex);
        CallableStatementCreator creator = con -> con.prepareCall(sql);
        CallableStatementCallback<List<Map<String, Object>>> callback = cs -> {
            bind(cs, args);
            cs.registerOutParameter(cursorIndex, Types.REF_CURSOR);
            cs.execute();
            try (ResultSet rs = (ResultSet) cs.getObject(cursorIndex)) {
                return readRows(rs);
            }
        };
        try {
            return jdbc.execute(creator, callback);
        } catch (DataAccessException e) {
            throw translate(e);
        }
    }

    private static String callText(String procedure, int paramCount) {
        StringBuilder marks = new StringBuilder();
        for (int i = 0; i < paramCount; i++) {
            if (i > 0) marks.append(',');
            marks.append('?');
        }
        return "{call ARS_OWNER." + procedure + "(" + marks + ")}";
    }

    private static void bind(CallableStatement cs, Object[] args) throws SQLException {
        for (int i = 0; i < args.length; i++) {
            Object value = args[i];
            if (value == null) {
                // Oracle accepts NULL for any parameter type, so one type is enough here.
                cs.setNull(i + 1, Types.NUMERIC);
            } else {
                cs.setObject(i + 1, value);
            }
        }
    }

    private static List<Map<String, Object>> readRows(ResultSet rs) throws SQLException {
        ResultSetMetaData meta = rs.getMetaData();
        int columns = meta.getColumnCount();
        List<Map<String, Object>> rows = new ArrayList<>();
        while (rs.next()) {
            Map<String, Object> row = new LinkedHashMap<>();
            for (int i = 1; i <= columns; i++) {
                String name = meta.getColumnLabel(i).toLowerCase(Locale.ROOT);
                row.put(name, readValue(rs, meta.getColumnType(i), i));
            }
            rows.add(row);
        }
        return rows;
    }

    /**
     * Reads one column as a plain Java value. Oracle's own classes returned by getObject
     * cannot be turned into JSON, so each column is read as a standard type.
     */
    private static Object readValue(ResultSet rs, int sqlType, int index) throws SQLException {
        switch (sqlType) {
            case Types.TIMESTAMP:
            case Types.DATE:
                return rs.getTimestamp(index);
            case Types.NUMERIC:
            case Types.DECIMAL:
            case Types.INTEGER:
            case Types.BIGINT:
                return rs.getBigDecimal(index);
            default:
                return rs.getString(index);
        }
    }

    /** Turns an ORA-20xxx message into a client error. Anything else becomes a logged 500. */
    private static RuntimeException translate(DataAccessException e) {
        String text = e.getMessage() == null ? "" : e.getMessage();
        Throwable root = e.getMostSpecificCause();
        if (root != null && root.getMessage() != null) {
            text = text + "\n" + root.getMessage();
        }
        Matcher m = BUSINESS_ERROR.matcher(text);
        if (m.find()) {
            int code = Integer.parseInt(m.group(1));
            if (code == 20403) {
                return new BusinessException(403, "Not allowed");
            }
            return new BusinessException(400, m.group(2).trim());
        }
        log.error("Database error in stored procedure call", e);
        return new UnexpectedDatabaseException(e);
    }
}
