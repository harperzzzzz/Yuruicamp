package com.yuruicamp.backend.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(YuruicampProperties.class)
public class AppConfig {
}
