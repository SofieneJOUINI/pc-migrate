package {{BASE_PACKAGE}}.libs.exceptions;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    @ExceptionHandler(ArgumentInvalidException.class)
    public ResponseEntity<ErrorResponse> handleArgumentInvalid(ArgumentInvalidException exception) {
        return this.toResponse(HttpStatus.BAD_REQUEST, exception.getCode());
    }

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(NotFoundException exception) {
        return this.toResponse(HttpStatus.NOT_FOUND, exception.getCode());
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ErrorResponse> handleConflict(ConflictException exception) {
        return this.toResponse(HttpStatus.CONFLICT, exception.getCode());
    }

    @ExceptionHandler(UnprocessableEntityException.class)
    public ResponseEntity<ErrorResponse> handleUnprocessableEntity(UnprocessableEntityException exception) {
        return this.toResponse(HttpStatus.UNPROCESSABLE_ENTITY, exception.getCode());
    }

    @ExceptionHandler(ExceptionBase.class)
    public ResponseEntity<ErrorResponse> handleUnmappedDomainError(ExceptionBase exception) {
        this.logger.error("Unmapped domain error [{}]", exception.getCode(), exception);
        return this.toResponse(HttpStatus.INTERNAL_SERVER_ERROR, exception.getCode());
    }

    private ResponseEntity<ErrorResponse> toResponse(HttpStatus status, String code) {
        return ResponseEntity.status(status).body(new ErrorResponse(status.value(), code));
    }
}
