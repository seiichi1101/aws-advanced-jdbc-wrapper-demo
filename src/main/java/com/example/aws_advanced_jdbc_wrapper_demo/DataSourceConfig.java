package com.example.aws_advanced_jdbc_wrapper_demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.mysql.cj.jdbc.MysqlDataSource;
import com.zaxxer.hikari.HikariDataSource;
import software.amazon.jdbc.ds.AwsWrapperDataSource;
import javax.sql.DataSource;
import software.amazon.jdbc.PropertyDefinition;
import java.util.Properties;
import org.springframework.jdbc.core.JdbcTemplate;

@Configuration
public class DataSourceConfig {
    @Value("${custom.datasource.url}")
    private String DATABASE_URL;
    @Value("${custom.datasource.database}")
    private String DATABASE_NAME;
    @Value("${custom.datasource.username}")
    private String USERNAME;
    @Value("${custom.datasource.password}")
    private String PASSWORD;

    private static final int CONNECTION_POOL_MAXIMUM_POOL_SIZE = 2;

    private static final int CONNECTION_POOL_IDLE_TIMEOUT = 2;

    @Bean
    public DataSource dataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setUsername(USERNAME);
        ds.setPassword(PASSWORD);
        ds.setMaximumPoolSize(CONNECTION_POOL_MAXIMUM_POOL_SIZE);
        ds.setIdleTimeout(CONNECTION_POOL_IDLE_TIMEOUT);

        ds.setDataSourceClassName(AwsWrapperDataSource.class.getName());
        ds.addDataSourceProperty("jdbcProtocol", "jdbc:mysql:");
        ds.addDataSourceProperty("serverName", DATABASE_URL);
        ds.addDataSourceProperty("serverPort", "3306");
        ds.addDataSourceProperty("database", DATABASE_NAME);
        ds.addDataSourceProperty("targetDataSourceClassName", "com.mysql.cj.jdbc.MysqlDataSource");

        Properties targetDataSourceProps = new Properties();
        targetDataSourceProps.setProperty(PropertyDefinition.PLUGINS.name, "initialConnection,auroraConnectionTracker,readWriteSplitting,failover,efm2");
        targetDataSourceProps.setProperty("readerHostSelectorStrategy", "random");
        targetDataSourceProps.setProperty("wrapperDialect", "aurora-mysql");
        targetDataSourceProps.setProperty("wrapperLoggerLevel", "ALL");

        ds.addDataSourceProperty("targetDataSourceProperties", targetDataSourceProps);

        return ds;
    }

    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
