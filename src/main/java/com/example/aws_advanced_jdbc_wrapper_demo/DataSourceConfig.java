package com.example.aws_advanced_jdbc_wrapper_demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.mysql.cj.jdbc.MysqlDataSource;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariConfig;
import software.amazon.jdbc.ds.AwsWrapperDataSource;
import javax.sql.DataSource;
import software.amazon.jdbc.PropertyDefinition;
import java.util.Properties;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SimpleDriverDataSource;
import software.amazon.jdbc.HikariPooledConnectionProvider;
import software.amazon.jdbc.Driver;
import java.util.concurrent.TimeUnit;

@Configuration
public class DataSourceConfig {
    @Value("${custom.datasource.host}")
    private String DATABASE_HOST;
    @Value("${custom.datasource.database}")
    private String DATABASE_NAME;
    @Value("${custom.datasource.username}")
    private String USERNAME;
    @Value("${custom.datasource.password}")
    private String PASSWORD;

    @Bean
    public DataSource customDataSource() {
        Driver.setCustomConnectionProvider(
                new HikariPooledConnectionProvider((host, props) -> {
                    HikariConfig cfg = new HikariConfig();

                    // Maximum time to wait for a connection from the pool before throwing an exception
                    cfg.setConnectionTimeout(2000);
                    // Maximum time to wait for a connection to be validated as alive before throwing an exception
                    cfg.setValidationTimeout(500);

                    return cfg;
                })
        );

        SimpleDriverDataSource ds = new SimpleDriverDataSource();
        ds.setUsername(USERNAME);
        ds.setPassword(PASSWORD);
        ds.setDriverClass(Driver.class);
        ds.setUrl(String.format("jdbc:aws-wrapper:mysql://%s:3306/%s", DATABASE_HOST, DATABASE_NAME));

        Properties props = new Properties();
        props.setProperty(PropertyDefinition.PLUGINS.name, "initialConnection,auroraConnectionTracker,readWriteSplitting,failover2,efm2");
        props.setProperty("wrapperDialect", "aurora-mysql");
        props.setProperty("wrapperLoggerLevel", "ALL");
        // Maximum time to retry a connection before giving up
        props.setProperty("openConnectionRetryTimeoutMs", "2000");

        ds.setConnectionProperties(props);

        return ds;
    }

//    @Bean
//    public DataSource presetDataSource() {
//        // Setup DataSource
//        SimpleDriverDataSource ds = new SimpleDriverDataSource();
//        ds.setUsername(USERNAME);
//        ds.setPassword(PASSWORD);
//        ds.setDriverClass(Driver.class);
//        // User Presets F0: https://github.com/aws/aws-advanced-jdbc-wrapper/blob/main/docs/using-the-jdbc-driver/ConfigurationPresets.md
//        // https://github.com/aws/aws-advanced-jdbc-wrapper/blob/47f50ea9f0ab46a6352c24468080db9b7db0415b/wrapper/src/main/java/software/amazon/jdbc/profile/DriverConfigurationProfiles.java#L298
//        ds.setUrl(String.format("jdbc:aws-wrapper:mysql://%s:3306/%s?wrapperProfileName=F0", DATABASE_HOST, DATABASE_NAME));
//        // Setup DataSource Properties
//        Properties targetDataSourceProps = new Properties();
//        targetDataSourceProps.setProperty("wrapperDialect", "aurora-mysql");
//        targetDataSourceProps.setProperty("wrapperLoggerLevel", "ALL");
//        ds.setConnectionProperties(targetDataSourceProps);
//
//        return ds;
//    }

    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
