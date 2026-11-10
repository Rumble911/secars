package com.secars.db;

import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * One place that decides what the client sees on failure.
 * Rule messages go out as they are. Everything else goes out as a generic message plus a
 * correlation id, which matches the id written to the server log (FR09).
 */
@RestControllerAdvice
public class ApiErrorHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiErrorHandler.class);

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Map<String, Object>> business(BusinessException e) {
        return ResponseEntity.status(e.getStatus()).body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler({UnexpectedDatabaseException.class, RuntimeException.class})
    public ResponseEntity<Map<String, Object>> unexpected(RuntimeException e) {
        String id = UUID.randomUUID().toString().substring(0, 8);
        log.error("Correlation id {}", id, e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Something went wrong", "correlationId", id));
    }
}
