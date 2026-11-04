package {{BASE_PACKAGE}}.libs.ddd.domain.entities;

import java.util.Objects;

public abstract class BaseEntity<I> {
    private final I id;

    protected BaseEntity(I id) {
        this.id = Objects.requireNonNull(id, "An entity must have an id");
    }

    public I getId() {
        return id;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (other == null || this.getClass() != other.getClass()) return false;
        return this.id.equals(((BaseEntity<?>) other).id);
    }

    @Override
    public int hashCode() {
        return this.id.hashCode();
    }
}
