package com.secars.tools;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * One-time tool, active only with the "hashgen" profile.
 * Reads demo passwords from environment variables and prints SQL that stores their
 * BCrypt hashes. Plain passwords are never written to a file or to Git.
 *
 * Run:  mvn spring-boot:run -Dspring-boot.run.profiles=hashgen
 */
@Component
@Profile("hashgen")
public class HashGenerator implements ApplicationRunner {

    private static final String[][] ACCOUNTS = {
        {"student1", "DEMO_STUDENT_PW"},
        {"lecturer1", "DEMO_LECTURER_PW"},
        {"registrar1", "DEMO_REGISTRAR_PW"},
        {"registrar2", "DEMO_REGISTRAR2_PW"},
        {"auditor1", "DEMO_AUDITOR_PW"}
    };

    private final PasswordEncoder encoder;

    public HashGenerator(PasswordEncoder encoder) {
        this.encoder = encoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        System.out.println("-- Paste the following into SQL*Plus as ARS_OWNER, then COMMIT;");
        for (String[] account : ACCOUNTS) {
            String password = System.getenv(account[1]);
            if (password == null || password.length() < 10) {
                System.out.println("-- SKIPPED " + account[0] + ": set " + account[1] + " (min 10 characters)");
                continue;
            }
            String hash = encoder.encode(password);
            System.out.println("UPDATE app_users SET password_hash = '" + hash
                    + "' WHERE username = '" + account[0] + "';");
        }
        System.out.println("COMMIT;");
        System.exit(0);
    }
}
