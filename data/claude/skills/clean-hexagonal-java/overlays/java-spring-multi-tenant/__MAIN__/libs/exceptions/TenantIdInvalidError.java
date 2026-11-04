package {{BASE_PACKAGE}}.libs.exceptions;

public class TenantIdInvalidError extends ArgumentInvalidException {

    private static final String ERROR_CODE = "TENANT_ID.INVALID";

    public TenantIdInvalidError() {
        super(ERROR_CODE);
    }
}
