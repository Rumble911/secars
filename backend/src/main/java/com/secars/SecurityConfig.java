package com.secars;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // CSRF stays on for every state-changing call except login and logout, which cannot have a token yet.
            // Both are protected by SameSite=Strict cookies. Revisit when the React client exists.
            .csrf(csrf -> csrf.ignoringRequestMatchers("/api/auth/login", "/api/auth/logout"))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/health", "/api/health/db", "/api/auth/login").permitAll()
                .requestMatchers("/api/student/**").hasRole("STUDENT")
                .anyRequest().authenticated())
            // Unauthenticated calls get 401 with no body or hints (FR09).
            .exceptionHandling(ex -> ex.authenticationEntryPoint(
                (request, response, authException) -> response.sendError(401)))
            .httpBasic(basic -> basic.disable())
            .formLogin(form -> form.disable())
            .logout(logout -> logout.disable())
            // A new session ID is issued at login (also done in AuthController).
            .sessionManagement(session -> session.sessionFixation(fix -> fix.changeSessionId()));
        return http.build();
    }
}
