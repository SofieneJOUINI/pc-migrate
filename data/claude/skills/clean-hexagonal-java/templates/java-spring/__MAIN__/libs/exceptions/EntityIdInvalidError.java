package {{BASE_PACKAGE}}.libs.exceptions;

public class EntityIdInvalidError extends ArgumentInvalidException {

    private static final String ERROR_CODE = "ENTITY_ID.INVALID";

    public EntityIdInvalidError() {
        super(ERROR_CODE);
    }
}
