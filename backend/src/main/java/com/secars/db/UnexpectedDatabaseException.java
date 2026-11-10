package com.secars.db;

/** A database failure we did not expect. Details stay in the server log only (FR09). */
public class UnexpectedDatabaseException extends RuntimeException {

    public UnexpectedDatabaseException(Throwable cause) {
        super("Unexpected database error", cause);
    }
}
