package {{BASE_PACKAGE}}.infrastructure.healthcheck;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;
import {{BASE_PACKAGE}}.libs.ddd.usecases.BaseQuery;

public class GetHealthInformationQuery extends BaseQuery {

    public GetHealthInformationQuery(UseCaseContext context) {
        super(context);
    }
}
