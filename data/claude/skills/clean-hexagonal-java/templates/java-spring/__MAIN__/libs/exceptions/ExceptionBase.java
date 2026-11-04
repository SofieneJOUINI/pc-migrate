package {{BASE_PACKAGE}}.libs.exceptions;

public abstract class ExceptionBase extends RuntimeException {
    private final String code;

    protected ExceptionBase(String code) {
        super(code);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
