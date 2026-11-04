package {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects;

import {{BASE_PACKAGE}}.libs.exceptions.TenantIdInvalidError;

import java.util.regex.Pattern;

public record TenantId(String value) {
    private static final Pattern VALID_TENANT_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$");

    public TenantId {
        if (value == null || !VALID_TENANT_ID.matcher(value).matches()) throw new TenantIdInvalidError();
    }

    public String getValue() {
        return value;
    }
}
