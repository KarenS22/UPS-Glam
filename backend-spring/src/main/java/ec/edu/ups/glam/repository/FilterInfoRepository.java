package ec.edu.ups.glam.repository;

import ec.edu.ups.glam.model.FilterInfo;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FilterInfoRepository extends ReactiveCrudRepository<FilterInfo, String> {
}
