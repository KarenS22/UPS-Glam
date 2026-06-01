package ec.edu.ups.glam;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.data.r2dbc.repository.config.EnableR2dbcRepositories;
import org.springframework.r2dbc.core.DatabaseClient;

@SpringBootApplication
@EnableR2dbcRepositories
public class GlamBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(GlamBackendApplication.class, args);
    }

    @Bean
    CommandLineRunner initFilters(DatabaseClient databaseClient) {
        return args -> {
            String cleanGpuMetrics = "DELETE FROM gpu_metrics WHERE processing_id IN (SELECT id FROM processing_history WHERE filter_id NOT IN ('blur', 'sharpen', 'sobel', 'cartooning', 'tricolor', 'tricolor_inverted', 'recuerdo_historico'))";
            String cleanProcessingHistory = "DELETE FROM processing_history WHERE filter_id NOT IN ('blur', 'sharpen', 'sobel', 'cartooning', 'tricolor', 'tricolor_inverted', 'recuerdo_historico')";
            String cleanObsoleteFilters = "DELETE FROM filters WHERE id NOT IN ('blur', 'sharpen', 'sobel', 'cartooning', 'tricolor', 'tricolor_inverted', 'recuerdo_historico')";

            String seedFilters = "INSERT INTO filters (id, name, description) VALUES " +
                    "('blur', 'Filtro de Blur', 'Filtro de promedio (Mean Blur) con convolución paralela.')," +
                    "('sharpen', 'Filtro Sharpen', 'Realza los bordes y detalles de la imagen.')," +
                    "('sobel', 'Filtro Sobel', 'Detector de bordes horizontales y verticales.')," +
                    "('cartooning', 'Filtro de Cartooning', 'Aplica un efecto de caricatura combinando sobel y suavizado.'),"
                    +
                    "('tricolor', 'Filtro Tricolor', 'Reemplaza los colores con amarillo #F5BE1A, azul #123672 y blanco #FFFFFF.'),"
                    +
                    "('tricolor_inverted', 'Filtro Tricolor Invertido', 'Invierte los colores y luego los reemplaza con amarillo #F5BE1A, azul #123672 y blanco #FFFFFF.'),"
                    +
                    "('recuerdo_historico', 'Recuerdo Histórico', 'Desenfoque fuerte y tinte duotono nostálgico con colores institucionales.') "
                    +
                    "ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description";

            databaseClient.sql(cleanGpuMetrics).then()
                    .then(databaseClient.sql(cleanProcessingHistory).then())
                    .then(databaseClient.sql(cleanObsoleteFilters).then())
                    .then(databaseClient.sql(seedFilters).then())
                    .subscribe(
                            v -> {
                            },
                            err -> System.err.println("Error seeding database filters: " + err.getMessage()),
                            () -> System.out.println("Database filters catalog successfully synchronized!"));
        };
    }
}
