package {{BASE_PACKAGE}}.infrastructure.healthcheck;

import {{BASE_PACKAGE}}.libs.ddd.usecases.BaseQueryHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

@Service
public class GetHealthInformationQueryHandler extends BaseQueryHandler<GetHealthInformationQuery, GetHealthInformationResponse> {
    private static final String STATUS_UP = "UP";

    private final String version;

    public GetHealthInformationQueryHandler(@Value("${info.app.version:unknown}") String version) {
        this.version = version;
    }

    @Override
    protected Mono<GetHealthInformationResponse> execute(GetHealthInformationQuery query) {
        return Mono.just(new GetHealthInformationResponse(STATUS_UP, this.version));
    }
}
