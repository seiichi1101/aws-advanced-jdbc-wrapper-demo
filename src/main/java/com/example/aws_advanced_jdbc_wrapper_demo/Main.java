package com.example.aws_advanced_jdbc_wrapper_demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import java.util.List;
import java.util.Map;
import org.springframework.transaction.annotation.Transactional;

@SpringBootApplication
@RestController
public class Main {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }

    @GetMapping("/health")
    public String healthCheck() {
        return "Server is running!\n";
    }

    @GetMapping("/hostname-reader")
    @Transactional(readOnly = true)
    public String HostnameReader() {
        try {
            List<Map<String, Object>> result = jdbcTemplate.queryForList("SELECT @@hostname");
            return "Succeed: " + result.toString() + "\n";
        } catch (Exception e) {
            return "Failed: " + e.getMessage() + "\n";
        }
    }

    @GetMapping("/hostname-writer")
    @Transactional
    public String HostnameWriter() {
        try {
            List<Map<String, Object>> result = jdbcTemplate.queryForList("SELECT @@hostname");
            return "Succeed: " + result.toString() + "\n";
        } catch (Exception e) {
            return "Failed: " + e.getMessage() + "\n";
        }
    }

    @GetMapping("/sql-reader")
    @Transactional(readOnly = true)
    public String sqlReader() {
        try {
            List<Map<String, Object>> result = jdbcTemplate.queryForList("SELECT * FROM user_accounts WHERE username = 'seiichi'");
            return "Succeed: row " + result.size() + "\n";
        } catch (Exception e) {
            return "Failed: " + e.getMessage() + "\n";
        }
    }

    @GetMapping("/sql-writer")
    @Transactional
    public String sqlWriter() {
        try {
            int rowsAffected = jdbcTemplate.update("UPDATE user_accounts SET nickname = 'seiichi' WHERE username = 'seiichi'");
            return "Succeed: row " + rowsAffected + "\n";
        } catch (Exception e) {
            return "Failed: " + e.getMessage() + "\n";
        }
    }
}
