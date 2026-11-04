package {{BASE_PACKAGE}}.infrastructure.healthcheck;

import {{BASE_PACKAGE}}.libs.ddd.usecases.RestBaseController;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/{{MODULE_KEBAB}}")
public class GetHealthInformationRestController extends RestBaseController {
    private final GetHealthInformationQueryHandler getHealthInformationQueryHandler;

    public GetHealthInformationRestController(GetHealthInformationQueryHandler getHealthInformationQueryHandler) {
        this.getHealthInformationQueryHandler = getHealthInformationQueryHandler;
    }

    @GetMapping("/health")
    Mono<GetHealthInformationResponse> getHealthInformation() {
        return this.getHealthInformationQueryHandler.handleMono(
                new GetHealthInformationQuery(this.generateUseCaseContext()));
    }
}
