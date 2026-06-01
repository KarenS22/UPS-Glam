package ec.edu.ups.glam.config;

import com.fasterxml.jackson.core.StreamReadConstraints;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JacksonConfig {

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer jacksonCustomizer() {
        return builder -> builder.postConfigurer(objectMapper -> {
            // Set Jackson max string length constraint to 150 million characters (approx 150MB payload)
            // to support extremely high-resolution base64 processed image nodes.
            StreamReadConstraints constraints = StreamReadConstraints.builder()
                    .maxStringLength(150_000_000)
                    .build();
            objectMapper.getFactory().setStreamReadConstraints(constraints);
        });
    }
}
