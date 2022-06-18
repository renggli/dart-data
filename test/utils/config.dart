/// Returns `true` if assertions are enabled.
bool hasAssertions() {
  var result = false;
  assert((() => result = true)());
  return result;
}
