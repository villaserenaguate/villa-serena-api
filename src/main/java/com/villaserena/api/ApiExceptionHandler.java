package com.villaserena.api;

import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class ApiExceptionHandler {

  public record FieldIssue(String field, String message) {}

  @ExceptionHandler(ApiException.class)
  ProblemDetail handleApi(ApiException e) {
    return problem(e.status(), e.code(), e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ProblemDetail handleBody(MethodArgumentNotValidException e) {
    ProblemDetail pd = problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Hay campos inválidos.");
    List<FieldIssue> errors = e.getBindingResult().getFieldErrors().stream()
        .map(f -> new FieldIssue(f.getField(), f.getDefaultMessage()))
        .toList();
    pd.setProperty("errors", errors);
    return pd;
  }

  @ExceptionHandler(MissingServletRequestParameterException.class)
  ProblemDetail handleMissing(MissingServletRequestParameterException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "Falta el parámetro '" + e.getParameterName() + "'.");
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  ProblemDetail handleType(MethodArgumentTypeMismatchException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "El parámetro '" + e.getName() + "' tiene un formato inválido.");
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  ProblemDetail handleUnreadable(HttpMessageNotReadableException e) {
    return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
        "Cuerpo inválido. Las fechas deben tener formato yyyy-MM-dd.");
  }

  private ProblemDetail problem(HttpStatus status, String code, String detail) {
    ProblemDetail pd = ProblemDetail.forStatusAndDetail(status, detail);
    pd.setProperty("code", code);
    return pd;
  }
}
