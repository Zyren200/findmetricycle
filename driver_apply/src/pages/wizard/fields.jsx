/** The red line under a field that failed validation. */
export function FieldError({ errors, k }) {
  return errors?.[k] ? <span className="err">{errors[k]}</span> : null;
}
