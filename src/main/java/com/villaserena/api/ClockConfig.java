package com.villaserena.api;

import java.time.Clock;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClockConfig {

  @Bean
  Clock clock(@Value("${hotel.timezone}") String timezone) {
    return Clock.system(ZoneId.of(timezone));
  }
}
